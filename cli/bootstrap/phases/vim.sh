#!/usr/bin/env bash

set -euo pipefail

# Phase 6: Vim Setup for Root
setup_vim_root() {
    log_info "Phase 6: Setting up Vim for root user..."
    
    local force_vim="${FORCE_VIM:-false}"
    
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
    else
        log_info "User vim undo directory already exists: $user_vim_undo"
    fi
    
    # Copy .vimrc to root home directory
    local user_vimrc="$HOME/.vimrc"
    local root_vimrc="/root/.vimrc"
    
    if [[ ! -f "$user_vimrc" ]]; then
        log_warning "User .vimrc not found at $user_vimrc"
        log_info "Skipping vimrc copy to root"
    else
        if [[ ! -f "$root_vimrc" ]]; then
            log_info "Copying .vimrc to /root/.vimrc..."
            sudo cp "$user_vimrc" "$root_vimrc"
            log_success "Vimrc copied to root"
        else
            if [[ "$force_vim" == "true" ]]; then
                log_info "Force flag set. Re-copying .vimrc..."
                sudo cp "$user_vimrc" "$root_vimrc"
                log_success "Vimrc copied to root"
            else
                log_info "Root .vimrc already exists. Skipping copy."
                log_info "Use --force flag to overwrite"
            fi
        fi
    fi
    
    # Create root vim undo directory
    local root_vim_undo="/root/.vim/undo"
    if [[ ! -d "$root_vim_undo" ]]; then
        log_info "Creating root vim undo directory: $root_vim_undo"
        sudo mkdir -p "$root_vim_undo"
        log_success "Root vim undo directory created"
    else
        log_info "Root vim undo directory already exists: $root_vim_undo"
    fi
}
