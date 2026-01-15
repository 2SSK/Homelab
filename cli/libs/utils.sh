#!/usr/bin/env bash

# =============================================================================
# Homelab CLI Utilities Library
# =============================================================================
#
# This library provides common utility functions for Homelab CLI scripts.
# It includes color definitions, logging functions, and basic utility functions
# that can be reused across multiple scripts.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/../libs/utils.sh"
#
# =============================================================================

# Color definitions for output formatting
# Usage: echo -e "${RED}Error message${NC}"
RED='\033[0;31m'      # Red for errors
GREEN='\033[0;32m'    # Green for success
YELLOW='\033[1;33m'   # Yellow for warnings
BLUE='\033[0;34m'     # Blue for info
NC='\033[0m'          # No Color (reset)

# =============================================================================
# Logging Functions
# =============================================================================

# Log an informational message
# Usage: log_info "This is an info message"
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Log a success message
# Usage: log_success "Operation completed successfully"
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Log a warning message
# Usage: log_warning "This is a warning"
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Log an error message to stderr
# Usage: log_error "This is an error"
log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# =============================================================================
# Utility Functions
# =============================================================================

# Check if the script is running as root and exit if it is
# This function ensures scripts are run as regular users with sudo access
# Usage: check_root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. Please run as a regular user with sudo access."
        exit 1
    fi
}

# Check if a command exists in PATH
# Returns 0 if command exists, 1 otherwise
# Usage: if command_exists "docker"; then echo "Docker is installed"; fi
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if a systemd service is enabled and active
# Returns 0 if service is enabled and active, 1 otherwise
# Usage: if service_status "docker"; then echo "Docker service is running"; fi
service_status() {
    local service="$1"
    if systemctl is-enabled "$service" >/dev/null 2>&1 && systemctl is-active "$service" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}