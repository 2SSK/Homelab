#!/usr/bin/env bash
#
# Observability Stack Installation
# Production-grade deployment of Prometheus, Grafana, Loki, and alerting
#
# Directory Layout:
#   <repo>/stacks/observability/      - Source configs (git repo, auto-detected)
#   /srv/docker/observability/        - Runtime (compose.yaml + .env)
#   /srv/data/observability/          - Persistent data volumes
#

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../libs/utils.sh"

# Configuration - Dynamic path detection
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly SOURCE_DIR="${REPO_ROOT}/stacks/observability"
readonly RUNTIME_DIR="/srv/docker/observability"
readonly DATA_DIR="/srv/data/observability"
readonly SYSTEMD_UNIT="/etc/systemd/system/observability.service"

# =============================================================================
# VALIDATION
# =============================================================================

check_docker() {
    if ! command_exists docker; then
        log_error "Docker is not installed. Run: homelab install docker"
        return 1
    fi
    
    if ! docker compose version &>/dev/null; then
        log_error "Docker Compose plugin is not installed"
        return 1
    fi
    
    log_info "Docker and Compose are available"
}

check_env_file() {
    local env_file="${RUNTIME_DIR}/.env"
    
    if [[ ! -f "${env_file}" ]]; then
        log_error ".env file not found at ${env_file}"
        log_info "Create it with: cp ${SOURCE_DIR}/.env.example ${env_file}"
        log_info "Then edit ${env_file} with your configuration"
        return 1
    fi
    
    # Validate required variables
    # shellcheck source=/dev/null
    source "${env_file}"
    
    if [[ -z "${GRAFANA_ADMIN_PASSWORD:-}" ]]; then
        log_error "GRAFANA_ADMIN_PASSWORD is required in .env"
        return 1
    fi
    
    log_info "Environment file validated"
}

validate_prometheus_config() {
    log_info "Validating Prometheus configuration..."
    
    # Check if config files exist
    if [[ ! -f "${SOURCE_DIR}/prometheus/prometheus.yml" ]]; then
        log_error "Prometheus config not found: ${SOURCE_DIR}/prometheus/prometheus.yml"
        return 1
    fi
    
    # Validate using promtool in container
    log_info "Validating alert rules syntax..."
    if ! docker run --rm \
        -v "${SOURCE_DIR}/prometheus:/prometheus:ro" \
        --entrypoint /bin/promtool \
        prom/prometheus:v2.48.1 \
        check rules /prometheus/alerts.yml \
                    /prometheus/systemd-alerts.yml \
                    /prometheus/ssh-alerts.yml \
                    /prometheus/fail2ban-alerts.yml 2>&1 | grep -q "SUCCESS"; then
        log_error "Prometheus alert rules validation failed"
        log_info "Run promtool manually to see detailed errors:"
        log_info "  docker run --rm -v ${SOURCE_DIR}/prometheus:/prometheus:ro \\"
        log_info "    --entrypoint /bin/promtool prom/prometheus:v2.48.1 \\"
        log_info "    check rules /prometheus/*.yml"
        return 1
    fi
    
    log_success "Prometheus configuration is valid"
}

# =============================================================================
# DIRECTORY SETUP
# =============================================================================

create_directories() {
    log_info "Creating production directory structure..."
    
    # Create parent directories first with proper ownership
    sudo mkdir -p /srv/docker
    sudo chown "${USER}:${USER}" /srv/docker
    
    sudo mkdir -p /srv/data
    sudo chown "${USER}:${USER}" /srv/data
    
    # Runtime directory (owned by user for compose operations)
    sudo mkdir -p "${RUNTIME_DIR}"
    sudo chown "${USER}:${USER}" "${RUNTIME_DIR}"
    
    # Data directories with proper ownership
    local data_dirs=(
        "${DATA_DIR}/prometheus"
        "${DATA_DIR}/grafana"
        "${DATA_DIR}/loki"
        "${DATA_DIR}/alertmanager"
        "${DATA_DIR}/promtail"
    )
    
    for dir in "${data_dirs[@]}"; do
        sudo mkdir -p "${dir}"
    done
    
    # Set ownership for containers
    # Prometheus runs as nobody (65534)
    sudo chown -R 65534:65534 "${DATA_DIR}/prometheus"
    
    # Grafana runs as grafana (472)
    sudo chown -R 472:472 "${DATA_DIR}/grafana"
    
    # Loki runs as loki (10001)
    sudo chown -R 10001:10001 "${DATA_DIR}/loki"
    
    # Alertmanager runs as nobody (65534)
    sudo chown -R 65534:65534 "${DATA_DIR}/alertmanager"
    
    # Promtail runs as root (needs to read logs)
    sudo chown -R root:root "${DATA_DIR}/promtail"
    
    log_success "Directory structure created"
}

setup_runtime_dir() {
    log_info "Setting up runtime directory..."
    
    # Symlink compose.yaml
    ln -sf "${SOURCE_DIR}/compose.yaml" "${RUNTIME_DIR}/compose.yaml"
    
    # Symlink config directories
    ln -sf "${SOURCE_DIR}/prometheus" "${RUNTIME_DIR}/prometheus"
    ln -sf "${SOURCE_DIR}/loki" "${RUNTIME_DIR}/loki"
    ln -sf "${SOURCE_DIR}/promtail" "${RUNTIME_DIR}/promtail"
    ln -sf "${SOURCE_DIR}/grafana" "${RUNTIME_DIR}/grafana"
    
    # Create alertmanager dir (config will be generated)
    mkdir -p "${RUNTIME_DIR}/alertmanager"
    
    # Copy .env.example if .env doesn't exist
    if [[ ! -f "${RUNTIME_DIR}/.env" ]]; then
        cp "${SOURCE_DIR}/.env.example" "${RUNTIME_DIR}/.env"
        chmod 600 "${RUNTIME_DIR}/.env"
        log_warning "Created ${RUNTIME_DIR}/.env from template"
        log_warning "Please edit it with your configuration before continuing"
    fi
    
    log_success "Runtime directory configured"
}

# =============================================================================
# ALERTMANAGER CONFIG GENERATION
# =============================================================================

generate_alertmanager_config() {
    log_info "Generating Alertmanager configuration..."
    
    local template="${SOURCE_DIR}/alertmanager/alertmanager.yml.template"
    local output="${RUNTIME_DIR}/alertmanager/alertmanager.yml"
    local env_file="${RUNTIME_DIR}/.env"
    
    if [[ ! -f "${template}" ]]; then
        log_error "Alertmanager template not found: ${template}"
        return 1
    fi
    
    # Source environment variables
    # shellcheck source=/dev/null
    source "${env_file}"
    
    # Replace placeholders with actual values
    sed -e "s|__SMTP_HOST__|${SMTP_HOST:-smtp.gmail.com:587}|g" \
        -e "s|__SMTP_FROM__|${SMTP_FROM:-homelab@localhost}|g" \
        -e "s|__SMTP_USER__|${SMTP_USER:-}|g" \
        -e "s|__SMTP_PASSWORD__|${SMTP_PASSWORD:-}|g" \
        -e "s|__ALERT_EMAIL__|${ALERT_EMAIL:-admin@localhost}|g" \
        "${template}" > "${output}"
    
    # Must be readable by alertmanager container (runs as nobody - UID 65534)
    # Using 640 for security (contains SMTP credentials), relying on same-group access
    # If alertmanager fails to read, fall back to 644
    chmod 640 "${output}"
    
    log_success "Alertmanager configuration generated"
}

# =============================================================================
# SYSTEMD SETUP
# =============================================================================

install_systemd_unit() {
    log_info "Installing systemd unit..."
    
    sudo cp "${SOURCE_DIR}/systemd/observability.service" "${SYSTEMD_UNIT}"
    sudo systemctl daemon-reload
    sudo systemctl enable observability.service
    
    log_success "Systemd unit installed and enabled"
}

# =============================================================================
# LOGROTATE SETUP
# =============================================================================

install_logrotate() {
    log_info "Installing logrotate configuration..."
    
    sudo tee /etc/logrotate.d/observability > /dev/null << 'EOF'
# Docker container logs
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    maxsize 50M
}

# Observability stack logs (if any host logs)
/var/log/observability/*.log {
    rotate 7
    weekly
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}
EOF
    
    log_success "Logrotate configuration installed"
}

# =============================================================================
# DEPLOYMENT
# =============================================================================

deploy_stack() {
    log_info "Deploying observability stack..."
    
    cd "${RUNTIME_DIR}"
    
    # Pull images first
    log_info "Pulling container images (this may take a while)..."
    docker compose pull
    
    # Start stack via systemd
    log_info "Starting services via systemd..."
    sudo systemctl start observability.service
    
    # Wait for services to be healthy
    log_info "Waiting for services to become healthy..."
    local max_attempts=30
    local attempt=0
    
    while [[ ${attempt} -lt ${max_attempts} ]]; do
        if docker compose ps --format json | grep -q '"Health":"healthy"'; then
            break
        fi
        ((attempt++))
        sleep 2
    done
    
    # Check status
    docker compose ps
}

show_status() {
    cd "${RUNTIME_DIR}" 2>/dev/null || cd "${SOURCE_DIR}"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "            OBSERVABILITY STACK STATUS"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Show systemd status
    if systemctl is-active --quiet observability.service 2>/dev/null; then
        echo "Systemd Service: ✓ active"
    else
        echo "Systemd Service: ✗ inactive"
    fi
    echo ""
    
    docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Health}}"
    
    echo ""
    echo "Directory Layout:"
    echo "  Source:  ${SOURCE_DIR}"
    echo "  Runtime: ${RUNTIME_DIR}"
    echo "  Data:    ${DATA_DIR}"
    echo ""
    echo "Access (via Tailscale SSH tunnel):"
    echo "  ssh -L 3000:localhost:3000 homelab"
    echo "  Then open: http://localhost:3000"
    echo ""
    echo "Default Grafana credentials:"
    echo "  Username: admin"
    echo "  Password: (from .env file)"
    echo ""
    echo "Useful commands:"
    echo "  systemctl status observability"
    echo "  systemctl restart observability"
    echo "  journalctl -u observability -f"
    echo ""
    echo "═══════════════════════════════════════════════════════════"
}

stop_stack() {
    log_info "Stopping observability stack..."
    
    # Check if service exists
    if ! systemctl list-unit-files observability.service &>/dev/null; then
        log_warning "Observability service not installed"
        return 1
    fi
    
    sudo systemctl stop observability.service
    log_success "Stack stopped"
}

restart_stack() {
    log_info "Restarting observability stack..."
    
    # Check if service exists
    if ! systemctl list-unit-files observability.service &>/dev/null; then
        log_error "Observability service not installed. Run: homelab observability install"
        return 1
    fi
    
    # Check if runtime directory exists
    if [[ ! -d "${RUNTIME_DIR}" ]]; then
        log_error "Runtime directory not found: ${RUNTIME_DIR}"
        log_info "Run: homelab observability install"
        return 1
    fi
    
    # Validate configuration before restart
    log_info "Validating configuration before restart..."
    if ! validate_prometheus_config; then
        log_error "Configuration validation failed. Fix errors before restarting."
        return 1
    fi
    
    sudo systemctl restart observability.service
    
    # Wait a moment for services to start
    sleep 3
    
    # Check if restart was successful
    if systemctl is-active --quiet observability.service; then
        log_success "Stack restarted successfully"
        show_status
    else
        log_error "Stack failed to start. Check logs with: journalctl -u observability.service -n 50"
        return 1
    fi
}

show_logs() {
    local service="${1:-}"
    cd "${RUNTIME_DIR}"
    
    if [[ -n "${service}" ]]; then
        docker compose logs -f "${service}"
    else
        docker compose logs -f
    fi
}

destroy_stack() {
    log_warning "This will remove all containers and data!"
    log_warning "Data in ${DATA_DIR} will be PERMANENTLY DELETED"
    read -rp "Are you sure? Type 'yes' to confirm: " confirm
    
    if [[ "${confirm}" == "yes" ]]; then
        log_info "Stopping and removing stack..."
        sudo systemctl stop observability.service 2>/dev/null || true
        sudo systemctl disable observability.service 2>/dev/null || true
        sudo rm -f "${SYSTEMD_UNIT}"
        sudo systemctl daemon-reload
        
        cd "${RUNTIME_DIR}" 2>/dev/null && docker compose down -v 2>/dev/null || true
        
        sudo rm -rf "${DATA_DIR}"
        rm -rf "${RUNTIME_DIR}"
        
        log_success "Stack destroyed"
    else
        log_info "Cancelled"
    fi
}

# =============================================================================
# MAIN
# =============================================================================

install_observability() {
    log_info "Installing Production Observability Stack..."
    echo ""
    
    check_docker || return 1
    create_directories
    setup_runtime_dir
    
    # Check if .env is configured
    if ! check_env_file; then
        echo ""
        log_warning "Configuration required!"
        log_info "Edit ${RUNTIME_DIR}/.env with your settings, then run:"
        log_info "  homelab observability install"
        return 1
    fi
    
    # Validate Prometheus configuration before deployment
    validate_prometheus_config || return 1
    
    generate_alertmanager_config
    install_systemd_unit
    install_logrotate
    deploy_stack
    show_status
    
    log_success "Observability stack installed!"
}

# Allow direct execution
main() {
    local action="${1:-install}"
    
    case "${action}" in
        install|up)
            install_observability
            ;;
        status)
            show_status
            ;;
        stop|down)
            stop_stack
            ;;
        restart)
            restart_stack
            ;;
        logs)
            shift
            show_logs "$@"
            ;;
        destroy)
            destroy_stack
            ;;
        regenerate-config)
            generate_alertmanager_config
            log_info "Restart the stack to apply: homelab observability restart"
            ;;
        reset-password)
            shift
            "${SCRIPT_DIR}/../maintain/reset-grafana-password.sh" "$@"
            ;;
        *)
            echo "Usage: $0 {install|status|stop|restart|logs|destroy|regenerate-config|reset-password}"
            echo ""
            echo "Commands:"
            echo "  install           Deploy the observability stack"
            echo "  status            Show stack status and access URLs"
            echo "  stop              Stop all services"
            echo "  restart           Restart all services"
            echo "  logs [service]    Follow logs (optionally specify service)"
            echo "  destroy           Remove stack and all data"
            echo "  regenerate-config Regenerate alertmanager.yml from template"
            echo "  reset-password    Reset Grafana admin password"
            echo ""
            echo "Directory Layout:"
            echo "  ${SOURCE_DIR}  - Source (git)"
            echo "  ${RUNTIME_DIR}         - Runtime (compose + .env)"
            echo "  ${DATA_DIR}            - Persistent data"
            return 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
