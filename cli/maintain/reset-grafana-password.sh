#!/usr/bin/env bash
#
# Reset Grafana Admin Password
# Useful when you need to change the admin password after first installation
#

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../libs/utils.sh"

# Configuration
readonly DATA_DIR="/srv/data/observability"
readonly RUNTIME_DIR="/srv/docker/observability"

usage() {
    cat << EOF
Usage: $0 [NEW_PASSWORD]

Reset Grafana admin password.

Options:
  NEW_PASSWORD    The new password (optional, will prompt if not provided)

Examples:
  $0 my-new-secure-password
  $0  # Will prompt for password

Note: This requires Grafana to be stopped temporarily.
EOF
}

reset_password() {
    local new_password="${1:-}"
    
    if [[ -z "${new_password}" ]]; then
        read -rsp "Enter new admin password: " new_password
        echo
        read -rsp "Confirm password: " confirm_password
        echo
        
        if [[ "${new_password}" != "${confirm_password}" ]]; then
            log_error "Passwords do not match"
            return 1
        fi
    fi
    
    if [[ ${#new_password} -lt 8 ]]; then
        log_error "Password must be at least 8 characters"
        return 1
    fi
    
    # Get the current Grafana version from the running container
    local grafana_version
    grafana_version=$(docker inspect grafana --format='{{.Config.Image}}' 2>/dev/null || echo "grafana/grafana-oss:10.2.3")
    
    log_info "Stopping Grafana..."
    if ! docker stop grafana 2>/dev/null; then
        log_error "Failed to stop Grafana container. Is it running?"
        log_info "Check container status with: docker ps -a | grep grafana"
        return 1
    fi
    
    log_info "Resetting admin password using ${grafana_version}..."
    if ! docker run --rm \
        -v "${DATA_DIR}/grafana:/var/lib/grafana" \
        "${grafana_version}" \
        grafana-cli admin reset-admin-password "${new_password}"; then
        log_error "Failed to reset password. Starting Grafana anyway..."
        docker start grafana 2>/dev/null || true
        return 1
    fi
    
    log_info "Starting Grafana..."
    if ! docker start grafana; then
        log_error "Failed to start Grafana. You may need to start it manually with: docker start grafana"
        return 1
    fi
    
    log_success "Grafana admin password has been reset!"
    log_info "You can now login with: admin / <your-password>"
    
    # Update .env file only after successful password reset
    if [[ -f "${RUNTIME_DIR}/.env" ]]; then
        log_info "Updating .env file..."
        if sed -i "s|^GRAFANA_ADMIN_PASSWORD=.*|GRAFANA_ADMIN_PASSWORD=${new_password}|g" "${RUNTIME_DIR}/.env"; then
            log_success ".env file updated"
        else
            log_warning ".env file update failed, but password was changed successfully"
        fi
    fi
}

main() {
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi
    
    reset_password "$@"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
