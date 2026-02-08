#!/usr/bin/env bash
#
# Validate Prometheus Alert Rules
# Usage: ./validate-alerts.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMETHEUS_DIR="$(cd "${SCRIPT_DIR}/../prometheus" && pwd)"
PROM_VERSION="v2.48.1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Prometheus Alert Rules Validator${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not found. Please install Docker first.${NC}"
    exit 1
fi

# Find all alert rule files
cd "${PROMETHEUS_DIR}"
ALERT_FILES=(alerts.yml *-alerts.yml)
TOTAL_FILES=0
VALID_FILES=0
INVALID_FILES=0
TOTAL_RULES=0

echo -e "${BLUE}Validating alert rule files in:${NC}"
echo -e "  ${PROMETHEUS_DIR}"
echo ""

# Create temporary file for validation output
TEMP_OUTPUT=$(mktemp)
trap "rm -f ${TEMP_OUTPUT}" EXIT

# Validate each file
for file in "${ALERT_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        continue
    fi
    
    TOTAL_FILES=$((TOTAL_FILES + 1))
    
    echo -n "Validating ${file}... "
    
    # Run promtool validation
    if docker run --rm \
        -v "$(pwd)/${file}:/tmp/rules.yml:ro" \
        --entrypoint /bin/promtool \
        "prom/prometheus:${PROM_VERSION}" \
        check rules /tmp/rules.yml > "${TEMP_OUTPUT}" 2>&1; then
        
        # Count rules in this file
        RULE_COUNT=$(grep "SUCCESS:" "${TEMP_OUTPUT}" | grep -oP '\d+(?= rules found)' 2>/dev/null || echo "0")
        if [[ -n "${RULE_COUNT}" && "${RULE_COUNT}" =~ ^[0-9]+$ ]]; then
            TOTAL_RULES=$((TOTAL_RULES + RULE_COUNT))
        fi
        VALID_FILES=$((VALID_FILES + 1))
        
        echo -e "${GREEN}✓ Valid${NC} (${RULE_COUNT} rules)"
    else
        INVALID_FILES=$((INVALID_FILES + 1))
        echo -e "${RED}✗ Invalid${NC}"
        echo ""
        echo -e "${RED}Error details:${NC}"
        cat "${TEMP_OUTPUT}" | sed 's/^/  /'
        echo ""
    fi
done

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo -e "Total files validated: ${TOTAL_FILES}"
echo -e "Valid files:           ${GREEN}${VALID_FILES}${NC}"
echo -e "Invalid files:         ${RED}${INVALID_FILES}${NC}"
echo -e "Total alert rules:     ${GREEN}${TOTAL_RULES}${NC}"
echo ""

# Verify expected rule count
EXPECTED_RULES=97
if [[ ${TOTAL_RULES} -eq ${EXPECTED_RULES} ]]; then
    echo -e "${GREEN}✓ Rule count matches expected: ${EXPECTED_RULES}${NC}"
elif [[ ${TOTAL_RULES} -gt ${EXPECTED_RULES} ]]; then
    echo -e "${YELLOW}⚠ Rule count (${TOTAL_RULES}) exceeds expected (${EXPECTED_RULES})${NC}"
    echo -e "${YELLOW}  This may indicate new rules were added without updating documentation.${NC}"
else
    echo -e "${YELLOW}⚠ Rule count (${TOTAL_RULES}) is less than expected (${EXPECTED_RULES})${NC}"
    echo -e "${YELLOW}  Some rules may be missing or commented out.${NC}"
fi

echo ""

# Check if Prometheus is running and can load the rules
if command -v curl &> /dev/null && curl -sf http://localhost:9090/-/healthy &> /dev/null; then
    echo -e "${BLUE}Checking running Prometheus instance...${NC}"
    
    # Get loaded rules count
    LOADED_RULES=$(curl -s http://localhost:9090/api/v1/rules | jq '[.data.groups[].rules[]] | length' 2>/dev/null || echo "0")
    
    if [[ ${LOADED_RULES} -gt 0 ]]; then
        echo -e "Rules loaded in Prometheus: ${GREEN}${LOADED_RULES}${NC}"
        
        if [[ ${LOADED_RULES} -eq ${TOTAL_RULES} ]]; then
            echo -e "${GREEN}✓ All validated rules are loaded in Prometheus${NC}"
        else
            echo -e "${YELLOW}⚠ Mismatch between validated (${TOTAL_RULES}) and loaded (${LOADED_RULES}) rules${NC}"
            echo -e "${YELLOW}  You may need to reload Prometheus: curl -X POST http://localhost:9090/-/reload${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Could not determine loaded rules count${NC}"
    fi
    echo ""
else
    echo -e "${YELLOW}⚠ Prometheus is not running or not accessible at http://localhost:9090${NC}"
    echo -e "${YELLOW}  Start it to verify rules load correctly in production.${NC}"
    echo ""
fi

# Final result
if [[ ${INVALID_FILES} -gt 0 ]]; then
    echo -e "${RED}✗ Validation FAILED${NC}"
    echo -e "${RED}  Fix the errors above before deploying.${NC}"
    exit 1
else
    echo -e "${GREEN}✓ All alert rules are valid!${NC}"
    echo -e "${GREEN}  Safe to deploy to production.${NC}"
    exit 0
fi
