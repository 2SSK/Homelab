#!/usr/bin/env bash
#
# Observability Stack Health Check
# Usage: ./health-check.sh
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0
CHECKS=0

check_pass() {
    CHECKS=$((CHECKS + 1))
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    CHECKS=$((CHECKS + 1))
    ERRORS=$((ERRORS + 1))
    echo -e "${RED}✗${NC} $1"
}

check_warn() {
    CHECKS=$((CHECKS + 1))
    WARNINGS=$((WARNINGS + 1))
    echo -e "${YELLOW}⚠${NC} $1"
}

section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Observability Stack Health Check     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

# Check 1: Docker daemon
section "Docker Environment"
if command -v docker &> /dev/null; then
    check_pass "Docker command available"
    if docker ps &> /dev/null; then
        check_pass "Docker daemon running"
    else
        check_fail "Docker daemon not accessible"
    fi
else
    check_fail "Docker not installed"
fi

# Check 2: Container status
section "Container Status"
CONTAINERS=("observability-prometheus-1" "observability-grafana-1" "observability-loki-1" "observability-alertmanager-1")
for container in "${CONTAINERS[@]}"; do
    if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        STATUS=$(docker inspect --format='{{.State.Status}}' "${container}")
        if [[ "${STATUS}" == "running" ]]; then
            UPTIME=$(docker inspect --format='{{.State.StartedAt}}' "${container}" | xargs -I {} date -d {} +%s)
            NOW=$(date +%s)
            RUNNING_SECONDS=$((NOW - UPTIME))
            if [[ ${RUNNING_SECONDS} -gt 60 ]]; then
                check_pass "${container} running ($(( RUNNING_SECONDS / 60 ))m uptime)"
            else
                check_warn "${container} running but just started (${RUNNING_SECONDS}s uptime)"
            fi
        else
            check_fail "${container} exists but not running (status: ${STATUS})"
        fi
    else
        check_fail "${container} not found"
    fi
done

# Check 3: Service endpoints
section "Service Health Endpoints"

# Prometheus
if curl -sf http://localhost:9090/-/healthy &> /dev/null; then
    check_pass "Prometheus health endpoint responding"
else
    check_fail "Prometheus health endpoint not responding (http://localhost:9090/-/healthy)"
fi

# Grafana
if curl -sf http://localhost:3000/api/health &> /dev/null; then
    DB_STATUS=$(curl -s http://localhost:3000/api/health | jq -r '.database' 2>/dev/null || echo "unknown")
    if [[ "${DB_STATUS}" == "ok" ]]; then
        check_pass "Grafana health endpoint responding (DB: ${DB_STATUS})"
    else
        check_warn "Grafana responding but database status: ${DB_STATUS}"
    fi
else
    check_fail "Grafana health endpoint not responding (http://localhost:3000/api/health)"
fi

# Loki
if curl -sf http://localhost:3100/ready &> /dev/null; then
    check_pass "Loki ready endpoint responding"
else
    check_fail "Loki ready endpoint not responding (http://localhost:3100/ready)"
fi

# Alertmanager
if curl -sf http://localhost:9093/-/healthy &> /dev/null; then
    check_pass "Alertmanager health endpoint responding"
else
    check_fail "Alertmanager health endpoint not responding (http://localhost:9093/-/healthy)"
fi

# Check 4: Prometheus targets
section "Prometheus Scrape Targets"
if curl -sf http://localhost:9090/-/healthy &> /dev/null; then
    TARGETS=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | jq -r '.data.activeTargets[]? | "\(.labels.job):\(.health)"' 2>/dev/null)
    if [[ -n "${TARGETS}" ]]; then
        while IFS= read -r target; do
            JOB=$(echo "${target}" | cut -d: -f1)
            HEALTH=$(echo "${target}" | cut -d: -f2)
            if [[ "${HEALTH}" == "up" ]]; then
                check_pass "Target '${JOB}' is up"
            else
                check_fail "Target '${JOB}' is ${HEALTH}"
            fi
        done <<< "${TARGETS}"
    else
        check_warn "No scrape targets found (metrics collection may not be working)"
    fi
else
    check_warn "Skipping (Prometheus not accessible)"
fi

# Check 5: Alert rules
section "Prometheus Alert Rules"
if curl -sf http://localhost:9090/-/healthy &> /dev/null; then
    RULES_COUNT=$(curl -s http://localhost:9090/api/v1/rules 2>/dev/null | jq '[.data.groups[]?.rules[]?] | length' 2>/dev/null || echo "0")
    EXPECTED_RULES=97
    
    if [[ ${RULES_COUNT} -eq ${EXPECTED_RULES} ]]; then
        check_pass "Alert rules loaded: ${RULES_COUNT} (matches expected: ${EXPECTED_RULES})"
    elif [[ ${RULES_COUNT} -gt 0 ]]; then
        check_warn "Alert rules loaded: ${RULES_COUNT} (expected: ${EXPECTED_RULES})"
    else
        check_fail "No alert rules loaded (expected: ${EXPECTED_RULES})"
    fi
    
    # Check for firing alerts
    FIRING_ALERTS=$(curl -s http://localhost:9090/api/v1/alerts 2>/dev/null | jq -r '.data.alerts[]? | select(.state=="firing") | .labels.alertname' 2>/dev/null)
    if [[ -n "${FIRING_ALERTS}" ]]; then
        ALERT_COUNT=$(echo "${FIRING_ALERTS}" | wc -l)
        echo ""
        echo -e "  ${YELLOW}Currently firing alerts (${ALERT_COUNT}):${NC}"
        while IFS= read -r alert; do
            if [[ "${alert}" == "DeadMansSwitch" ]]; then
                echo -e "    ${GREEN}• ${alert}${NC} (expected - proves alerting works)"
            else
                echo -e "    ${YELLOW}• ${alert}${NC}"
            fi
        done <<< "${FIRING_ALERTS}"
    fi
else
    check_warn "Skipping (Prometheus not accessible)"
fi

# Check 6: Grafana dashboards
section "Grafana Dashboards"
if curl -sf http://localhost:3000/api/health &> /dev/null; then
    # Try to get dashboard count (may require auth)
    DASHBOARD_COUNT=$(curl -s http://localhost:3000/api/search?type=dash-db 2>/dev/null | jq 'length' 2>/dev/null || echo "unknown")
    EXPECTED_DASHBOARDS=6
    
    if [[ "${DASHBOARD_COUNT}" == "${EXPECTED_DASHBOARDS}" ]]; then
        check_pass "Dashboards loaded: ${DASHBOARD_COUNT} (matches expected: ${EXPECTED_DASHBOARDS})"
    elif [[ "${DASHBOARD_COUNT}" == "unknown" ]]; then
        check_warn "Could not determine dashboard count (may require authentication)"
    else
        check_warn "Dashboards loaded: ${DASHBOARD_COUNT} (expected: ${EXPECTED_DASHBOARDS})"
    fi
else
    check_warn "Skipping (Grafana not accessible)"
fi

# Check 7: Data persistence
section "Data Persistence"
DATA_DIR="/srv/data/observability"
if [[ -d "${DATA_DIR}" ]]; then
    check_pass "Data directory exists: ${DATA_DIR}"
    
    # Check subdirectories
    for subdir in prometheus grafana loki alertmanager; do
        if [[ -d "${DATA_DIR}/${subdir}" ]]; then
            SIZE=$(du -sh "${DATA_DIR}/${subdir}" 2>/dev/null | cut -f1)
            check_pass "Data directory ${subdir}: ${SIZE}"
        else
            check_warn "Data directory ${subdir} not found"
        fi
    done
    
    # Check disk space
    AVAILABLE=$(df -h "${DATA_DIR}" | awk 'NR==2 {print $4}')
    USED_PERCENT=$(df -h "${DATA_DIR}" | awk 'NR==2 {print $5}' | tr -d '%')
    
    if [[ ${USED_PERCENT} -lt 80 ]]; then
        check_pass "Disk space available: ${AVAILABLE} (${USED_PERCENT}% used)"
    elif [[ ${USED_PERCENT} -lt 90 ]]; then
        check_warn "Disk space running low: ${AVAILABLE} available (${USED_PERCENT}% used)"
    else
        check_fail "Disk space critical: ${AVAILABLE} available (${USED_PERCENT}% used)"
    fi
else
    check_fail "Data directory not found: ${DATA_DIR}"
fi

# Check 8: Configuration files
section "Configuration Files"
CONFIG_FILES=(
    "stacks/observability/compose.yaml"
    "stacks/observability/prometheus/prometheus.yml"
    "stacks/observability/prometheus/alerts.yml"
    "stacks/observability/alertmanager/alertmanager.yml"
    "stacks/observability/loki/loki.yaml"
    "stacks/observability/grafana/grafana.ini"
)

for config in "${CONFIG_FILES[@]}"; do
    if [[ -f "${config}" ]]; then
        check_pass "Configuration file exists: ${config}"
    else
        check_fail "Configuration file missing: ${config}"
    fi
done

# Check 9: Resource usage
section "Resource Usage"
if command -v docker &> /dev/null && docker ps &> /dev/null; then
    echo -e "\n  ${BLUE}Container Resource Usage:${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
        $(docker ps --filter "name=observability" --format "{{.Names}}") | grep -E "NAME|observability" || true
fi

# Summary
section "Health Check Summary"
echo ""
echo -e "Total checks:    ${CHECKS}"
echo -e "Passed:          ${GREEN}$((CHECKS - ERRORS - WARNINGS))${NC}"
echo -e "Warnings:        ${YELLOW}${WARNINGS}${NC}"
echo -e "Failures:        ${RED}${ERRORS}${NC}"
echo ""

if [[ ${ERRORS} -gt 0 ]]; then
    echo -e "${RED}✗ Health check FAILED${NC}"
    echo -e "${RED}  Review the errors above and check container logs:${NC}"
    echo -e "${RED}  docker logs observability-prometheus-1${NC}"
    echo -e "${RED}  docker logs observability-grafana-1${NC}"
    exit 1
elif [[ ${WARNINGS} -gt 0 ]]; then
    echo -e "${YELLOW}⚠ Health check passed with WARNINGS${NC}"
    echo -e "${YELLOW}  Review the warnings above for potential issues.${NC}"
    exit 0
else
    echo -e "${GREEN}✓ All health checks PASSED${NC}"
    echo -e "${GREEN}  Observability stack is healthy!${NC}"
    echo ""
    echo -e "Access your monitoring:"
    echo -e "  • Grafana:       http://localhost:3000"
    echo -e "  • Prometheus:    http://localhost:9090"
    echo -e "  • Alertmanager:  http://localhost:9093"
    exit 0
fi
