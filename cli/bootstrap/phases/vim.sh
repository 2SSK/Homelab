#!/usr/bin/env bash

set -euo pipefail

# Phase 6: Vim Setup for Root
setup_vim_root() {
    log_info "Phase 6: Setting up Vim for root user..."
    
    local force_vim="${FORCE_VIM:-false}"
    
    # Determine vimrc source - prefer dotfiles repo directly
    local vimrc_source=""
    if [[ -d "/opt/Homelab/dotfiles/vim" ]]; then
        vimrc_source="/opt/Homelab/dotfiles/vim/.vimrc"
    elif [[ -f "$HOME/.vimrc" ]]; then
        # Follow symlink to get actual file
        vimrc_source="$(readlink -f "$HOME/.vimrc")"
    fi
    
    # Check if vim setup already completed
    if [[ -f "/root/.vimrc" ]] && [[ -d "/root/.vim/undo" ]] && \
       [[ "$force_vim" == "false" ]]; then
        log_info "Vim setup for root already completed. Skipping..."
        return 0
    fi
    
    # Create user vim undo directory
    local user_vim_undo="$HOME/.vim/undo"
    if [[ ! -d "$user_vim_undo" ]]; then
        log_info "Creating user vim undo directory: $user_vim_undo"
        mkdir -p "$user_vim_undo"
        log_success "User vim undo directory created"
    fi
    
    # Copy .vimrc to root home directory
    local root_vimrc="/root/.vimrc"
    
    if [[ -z "$vimrc_source" ]] || [[ ! -f "$vimrc_source" ]]; then
        log_warning "No .vimrc source found"
        log_info "Skipping vimrc copy to root"
    else
        if [[ ! -f "$root_vimrc" ]] || [[ "$force_vim" == "true" ]]; then
            log_info "Copying .vimrc to /root/.vimrc from ${vimrc_source}..."
            sudo cp "$vimrc_source" "$root_vimrc"
            sudo chown root:root "$root_vimrc"
            log_success "Vimrc copied to root"
        else
            log_info "Root .vimrc already exists. Use --force to overwrite"
        fi
    fi
    
    # Create root vim undo directory
    local root_vim_undo="/root/.vim/undo"
    if [[ ! -d "$root_vim_undo" ]]; then
        log_info "Creating root vim undo directory: $root_vim_undo"
        sudo mkdir -p "$root_vim_undo"
        log_success "Root vim undo directory created"
    fi
}
