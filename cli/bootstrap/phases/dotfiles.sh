#!/usr/bin/env bash

# Phase 5: Dotfiles Setup
setup_dotfiles() {
    log_info "Phase 5: Setting up dotfiles..."
    
    local force_dotfiles="${FORCE_DOTFILES:-false}"

    local homelab_dir="$HOME/Homelab"
    local dotfiles_dir="$HOME/dotfiles"

    # Copy dotfiles if not exists
    if [[ "$force_dotfiles" == "true" ]]; then
        log_info "Force flag set. Will re-setup dotfiles..."
    elif [[ -d "$dotfiles_dir" ]]; then
        log_info "Dotfiles directory already exists. Skipping..."
        return 0
    fi
    
    if [[ ! -d "$dotfiles_dir" ]]; then
        if [[ -d "$homelab_dir/dotfiles" ]]; then
            log_info "Copying dotfiles..."
            cp -r "$homelab_dir/dotfiles" "$dotfiles_dir"
            log_success "Dotfiles copied"
        else
            log_warning "Homelab dotfiles directory not found at $homelab_dir/dotfiles"
            return 0
        fi
    fi
    
    # Setup with stow if available
    if command_exists stow; then
        cd "$dotfiles_dir"
        log_info "Setting up dotfiles with stow..."
        stow . 2>/dev/null || log_warning "Some dotfiles may have conflicts, manual setup may be needed"
        log_success "Dotfiles setup completed"
    else
        log_warning "GNU stow not found. Please install it to automatically link dotfiles."
    fi
}
