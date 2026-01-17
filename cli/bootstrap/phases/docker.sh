#!/usr/bin/env bash

# Phase 7: Docker Setup
setup_docker() {
    log_info "Phase 7: Setting up Docker..."
    
    local force_docker="${FORCE_DOCKER:-false}"
    
    if [[ "$force_docker" == "true" ]]; then
        log_info "Force flag set. Will re-install Docker..."
    else
        if command_exists docker && service_status docker; then
            log_info "Docker already installed and running. Skipping..."
            return 0
        fi
    fi

    if command_exists docker && service_status docker; then
        log_info "Docker already installed and running"
        return 0
    fi

    local install_script="$HOME/Homelab/cli/install/docker.sh"
    if [[ -f "$install_script" ]]; then
        log_info "Installing Docker using homelab script..."
        bash "$install_script"
        log_success "Docker setup completed"
    else
        log_error "Docker install script not found at $install_script"
        return 1
    fi
}
