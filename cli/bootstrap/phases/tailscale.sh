#!/usr/bin/env bash

# Phase 4: Tailscale Setup
setup_tailscale() {
    log_info "Phase 4: Setting up Tailscale..."

    # Check if tailscale is already connected
    if command_exists tailscale && tailscale status >/dev/null 2>&1; then
        log_info "Tailscale already connected"
        return 0
    fi

    # Add Tailscale repository
    if [[ ! -f /etc/apt/sources.list.d/tailscale.list ]]; then
        log_info "Adding Tailscale repository..."
        curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
        curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
        sudo apt update
        log_success "Tailscale repository added"
    else
        log_info "Tailscale repository already added"
    fi

    # Install Tailscale
    if ! command_exists tailscale; then
        log_info "Installing Tailscale..."
        sudo apt install -y tailscale
        log_success "Tailscale installed"
    else
        log_info "Tailscale already installed"
    fi

    # Enable Tailscale service if not already
    if ! service_status tailscaled; then
        sudo systemctl enable tailscaled
        sudo systemctl start tailscaled
        log_success "Tailscale service enabled"
    else
        log_info "Tailscale service already enabled"
    fi

    # Determine authentication method
    local auth_key="${TAILSCALE_AUTH_KEY:-}"
    local use_auth_key=false
    if [[ -n "$auth_key" ]]; then
        use_auth_key=true
        log_info "Using auth key from environment variable"
    else
        read -r -p "Enter Tailscale auth key \(leave empty for browser authentication\): " auth_key
        if [[ -n "$auth_key" ]]; then
            use_auth_key=true
            log_info "Using provided auth key"
        else
            log_info "No auth key provided, proceeding with browser authentication"
        fi
    fi

    # Build tailscale up command
    local cmd="sudo tailscale up --accept-routes"

    if [[ "$use_auth_key" == true ]]; then
        cmd="$cmd --auth-key=\"$auth_key\""
    fi

    # Check for advertise exit node
    local advertise_exit="${TAILSCALE_ADVERTISE_EXIT_NODE:-}"
    if [[ -z "$advertise_exit" ]]; then
        read -r -p "Advertise as exit node? \(y/N\): " advertise_exit
    fi

    if [[ "$advertise_exit" =~ ^[Yy]$ ]] || [[ "$advertise_exit" == "yes" ]] || [[ "$advertise_exit" == "true" ]] || [[ "$advertise_exit" == "1" ]]; then
        cmd="$cmd --advertise-exit-node"
        log_info "Advertising as exit node"
    fi

    # Execute tailscale up
    log_info "Starting Tailscale..."
    eval "$cmd"

    if [[ "$use_auth_key" == true ]]; then
        log_success "Tailscale started and authenticated using auth key"
    else
        log_success "Tailscale started - browser authentication initiated. Complete authentication at the provided URL."
    fi
}
