#!/usr/bin/env bash

# Homelab Bootstrap Script
# Bootstraps a fresh Ubuntu server for homelab use with essential services and security hardening

set -euo pipefail

# Logging setup
LOG_FILE="${LOG_FILE:-bootstrap.log}"
exec > >(tee -a "$LOG_FILE") 2>&1

# Error trap
trap 'echo "Error occurred at line $LINENO. Check $LOG_FILE for details." >&2' ERR

# Source utility functions
source "$(dirname "${BASH_SOURCE[0]}")/../libs/utils.sh"

# Load phase modules
source "$(dirname "${BASH_SOURCE[0]}")/phases/packages.sh"
source "$(dirname "${BASH_SOURCE[0]}")/phases/networkd.sh"
source "$(dirname "${BASH_SOURCE[0]}")/phases/ssh.sh"
source "$(dirname "${BASH_SOURCE[0]}")/phases/tailscale.sh"
source "$(dirname "${BASH_SOURCE[0]}")/phases/dotfiles.sh"
source "$(dirname "${BASH_SOURCE[0]}")/phases/vim.sh"
source "$(dirname "${BASH_SOURCE[0]}")/phases/cli.sh"
source "$(dirname "${BASH_SOURCE[0]}")/phases/docker.sh"
source "$(dirname "${BASH_SOURCE[0]}")/phases/verify.sh"

# Main function
main() {
    # Parse command-line arguments
    local force_install=false
    for arg in "$@"; do
        case $arg in
            --force)
                force_install=true
                export FORCE_CLI_INSTALL="true"
                export FORCE_NETWORKD="true"
                export FORCE_SSH="true"
                export FORCE_TAILSCALE="true"
                export FORCE_DOTFILES="true"
                export FORCE_VIM="true"
                export FORCE_DOCKER="true"
                shift
                ;;
        esac
    done

    log_info "Starting Homelab Bootstrap..."
    log_info "Log file: $LOG_FILE"

    if [[ "$force_install" == "true" ]]; then
        log_info "Running with --force flag - will overwrite existing configurations"
    fi

    check_root

    install_base_packages
    setup_networkd
    harden_ssh
    setup_tailscale
    setup_dotfiles
    setup_vim_root
    install_cli
    setup_docker
    verify_setup

    log_success "Homelab bootstrap completed!"
    log_info "Please reboot the system to ensure all changes take effect."
    log_info "After reboot, verify SSH access on port 2222 and Tailscale connectivity."
    log_info "Run homelab help to see available CLI commands."
}

# Run main function
main "$@"
