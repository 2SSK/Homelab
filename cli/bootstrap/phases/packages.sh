#!/usr/bin/env bash

set -euo pipefail

# Phase 1: System Update & Base Packages
install_base_packages() {
    log_info "Phase 1: Installing base packages..."
    
    # Update package lists
    if ! sudo apt update -y; then
        log_error "Failed to update package lists"
        return 1
    fi

    # Upgrade system
    if ! sudo apt upgrade -y; then
        log_error "Failed to upgrade system packages"
        return 1
    fi

    # Install base packages
    local packages=(curl wget git vim ufw fail2ban btop net-tools build-essential fzf fd ripgrep tree xclip stow)

    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            log_info "Installing $package..."
            if ! sudo apt install -y "$package"; then
                log_error "Failed to install $package"
                return 1
            fi
        else
            log_info "$package already installed"
        fi
    done

    log_success "Base packages installed successfully"
}
