#!/usr/bin/env bash

# Phase 8: Verification
verify_setup() {
    log_info "Phase 8: Verifying setup..."

    local all_good=true

    # Check SSH
    if service_status ssh; then
        log_success "SSH service is running"
        if sudo netstat -tlnp | grep -q ":2222 "; then
            log_success "SSH listening on port 2222"
        else
            log_error "SSH not listening on port 2222"
            all_good=false
        fi
    else
        log_error "SSH service not running"
        all_good=false
    fi

    # Check Tailscale
    if service_status tailscaled; then
        log_success "Tailscale service is running"
        if tailscale status >/dev/null 2>&1; then
            log_success "Tailscale is connected"
        else
            log_warning "Tailscale not connected \(may need manual auth\)"
        fi
    else
        log_error "Tailscale service not running"
        all_good=false
    fi

    # Check Docker
    if service_status docker; then
        log_success "Docker service is running"
    else
        log_error "Docker service not running"
        all_good=false
    fi

    # Check systemd-networkd
    if service_status systemd-networkd; then
        log_success "systemd-networkd is running"
    else
        log_warning "systemd-networkd not running \(may not be needed\)"
    fi

    # Check CLI symlink
    if [[ -L "/usr/local/bin/homelab" ]]; then
        local cli_target
        cli_target="$(readlink -f "/usr/local/bin/homelab")"
        if [[ -n "$cli_target" && -f "$cli_target" ]]; then
            log_success "CLI symlink is valid and points to: $cli_target"
        else
            log_warning "CLI symlink exists but is broken"
            all_good=false
        fi
    else
        log_warning "CLI symlink not found at /usr/local/bin/homelab"
    fi

    # Check Vim setup for root
    if [[ -d "/root/.vim/undo" ]]; then
        log_success "Root vim undo directory exists: /root/.vim/undo"
    else
        log_warning "Root vim undo directory not found"
        all_good=false
    fi
    
    if [[ -f "/root/.vimrc" ]]; then
        log_success "Root .vimrc exists: /root/.vimrc"
    else
        log_warning "Root .vimrc not found"
        all_good=false
    fi
    
    if [[ -d "$HOME/.vim/undo" ]]; then
        log_success "User vim undo directory exists: $HOME/.vim/undo"
    else
        log_info "User vim undo directory not found \(optional\)"
    fi

    # Test connectivity
    log_info "Testing connectivity..."
    if getent hosts google.com >/dev/null 2>&1; then
        log_success "DNS resolution working"
    else
        log_warning "DNS resolution may have issues"
    fi

    if ping -c 1 -W 2 google.com >/dev/null 2>&1; then
        log_success "Internet connectivity working"
    else
        log_error "No internet connectivity"
        all_good=false
    fi

    if $all_good; then
        log_success "All verifications passed!"
        return 0
    else
        log_warning "Some verifications failed. Check the log for details."
        return 1
    fi
}
