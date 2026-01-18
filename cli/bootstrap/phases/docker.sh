#!/usr/bin/env bash

set -euo pipefail

# Phase 8: Docker Setup
setup_docker() {
    log_info "Phase 7: Setting up Docker..."
    
    local force_docker="${FORCE_DOCKER:-false}"
    
    if command_exists docker && service_status docker; then
        if [[ "$force_docker" == "true" ]]; then
            log_info "Force flag set. Will re-install Docker..."
        else
            log_info "Docker already installed and running. Skipping..."
            return 0
        fi
    fi

    local install_script="/opt/Homelab/cli/install/docker.sh"
    if [[ -f "$install_script" ]]; then
        log_info "Installing Docker using homelab script..."
        bash "$install_script"
        log_success "Docker setup completed"
    else
        log_error "Docker install script not found at $install_script"
        return 1
    fi
}
