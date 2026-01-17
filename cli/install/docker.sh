#!/usr/bin/env bash

# Docker Installation Script
# Idempotent installation of Docker Engine on Ubuntu

set -euo pipefail

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../libs/utils.sh"

# Check if Docker is already installed and running
check_docker_installed() {
    if command_exists docker && docker --version >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Check if user is in docker group
check_docker_group() {
    if groups "$USER" | grep -q docker; then
        return 0
    fi
    return 1
}

# Main installation function
install_docker() {
    log_info "Starting Docker installation..."

    # Check if Docker is already installed
    if check_docker_installed && service_status docker; then
        log_info "Docker is already installed and running"
        docker --version
        docker compose version
        
        if ! check_docker_group; then
            log_warning "User '$USER' is not in docker group"
            log_info "Adding user to docker group..."
            sudo usermod -aG docker "$USER"
            log_warning "Please log out and back in for group changes to take effect"
        fi
        return 0
    fi

    # Remove old Docker packages (ignore errors if not installed)
    log_info "Removing old Docker packages (if any)..."
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Update system & install prerequisites
    log_info "Installing prerequisites..."
    sudo apt update -y
    sudo apt install -y ca-certificates curl gnupg lsb-release

    # Add Docker's official GPG key (idempotent)
    local keyring_path="/etc/apt/keyrings/docker.gpg"
    if [[ ! -f "$keyring_path" ]]; then
        log_info "Adding Docker GPG key..."
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
            | sudo gpg --dearmor -o "$keyring_path"
        log_success "Docker GPG key added"
    else
        log_info "Docker GPG key already exists"
    fi

    # Add Docker APT repository (idempotent)
    local docker_list="/etc/apt/sources.list.d/docker.list"
    if [[ ! -f "$docker_list" ]]; then
        log_info "Adding Docker APT repository..."
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=$keyring_path] \
            https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" \
            | sudo tee "$docker_list" > /dev/null
        sudo apt update
        log_success "Docker repository added"
    else
        log_info "Docker APT repository already configured"
    fi

    # Install Docker Engine
    log_info "Installing Docker Engine..."
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add user to docker group (idempotent)
    if ! check_docker_group; then
        log_info "Adding user '$USER' to docker group..."
        sudo usermod -aG docker "$USER"
        log_warning "Please log out and back in for group changes to take effect"
    else
        log_info "User '$USER' already in docker group"
    fi

    # Enable and start Docker service
    log_info "Enabling Docker service..."
    sudo systemctl enable docker
    sudo systemctl start docker

    # Verify installation
    log_success "Docker installed successfully!"
    docker --version
    docker compose version

    log_info "Note: You may need to log out and back in to use Docker without sudo"
}

# Run installation
install_docker "$@"
