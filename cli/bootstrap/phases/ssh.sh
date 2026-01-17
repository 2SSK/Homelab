#!/usr/bin/env bash

# Phase 3: SSH Hardening
harden_ssh() {
    log_info "Phase 3: Hardening SSH \(Port: 2222\)"
    
    local ssh_config="/etc/ssh/sshd_config"
    local ssh_config_backup="/etc/ssh/sshd_config.backup"
    local force_ssh="${FORCE_SSH:-false}"
    
    # Check if SSH already hardened
    if [[ "$force_ssh" == "true" ]]; then
        log_info "Force flag set. Will re-apply SSH hardening."
    elif grep -q "^Port 2222" "$ssh_config" 2>/dev/null && \
       grep -q "^PasswordAuthentication no" "$ssh_config" 2>/dev/null && \
       grep -q "^PubkeyAuthentication yes" "$ssh_config" 2>/dev/null && \
       grep -q "^PermitEmptyPasswords no" "$ssh_config" 2>/dev/null; then
        log_info "SSH already hardened on port 2222. Skipping..."
        return 0
    fi
    
    # Backup config if not already backed up
    if [[ ! -f "$ssh_config_backup" ]]; then
        log_info "Backing up SSH config..."
        sudo cp "$ssh_config" "$ssh_config_backup"
        log_success "SSH config backed up"
    else
        log_info "SSH config backup already exists"
    fi
    
    # Update SSH settings
    log_info "Updating SSH configuration..."

    # Disable password authentication
    sudo sed -i 's/^#*PasswordAuthentication yes/PasswordAuthentication no/' "$ssh_config"
    sudo sed -i 's/^#*PasswordAuthentication no/PasswordAuthentication no/' "$ssh_config"

    # Enable public key authentication
    sudo sed -i 's/^#*PubkeyAuthentication yes/PubkeyAuthentication yes/' "$ssh_config"
    sudo sed -i 's/^#*PubkeyAuthentication no/PubkeyAuthentication yes/' "$ssh_config"

    # Disable empty passwords
    sudo sed -i 's/^#*PermitEmptyPasswords yes/PermitEmptyPasswords no/' "$ssh_config"
    sudo sed -i 's/^#*PermitEmptyPasswords no/PermitEmptyPasswords no/' "$ssh_config"

    # Enable PAM
    sudo sed -i 's/^#*UsePAM yes/UsePAM yes/' "$ssh_config"
    sudo sed -i 's/^#*UsePAM no/UsePAM yes/' "$ssh_config"

    # Disable X11 forwarding
    sudo sed -i 's/^#*X11Forwarding yes/X11Forwarding no/' "$ssh_config"

    # Change port to 2222
    if ! grep -q "^Port 2222" "$ssh_config"; then
        sudo sed -i 's/^#*Port .*/Port 2222/' "$ssh_config"
        if ! grep -q "^Port" "$ssh_config"; then
            echo "Port 2222" | sudo tee -a "$ssh_config" > /dev/null
        fi
        log_success "SSH port changed to 2222"
    else
        log_info "SSH port already set to 2222"
    fi

    # Update UFW to allow 2222
    log_info "Updating UFW rules..."
    if ! sudo ufw status | grep -q "2222"; then
        sudo ufw allow 2222/tcp
        log_success "UFW rule added for port 2222"
    else
        log_info "UFW rule for port 2222 already exists"
    fi

    # Reload SSH
    log_info "Reloading SSH service..."
    sudo systemctl reload ssh
    log_success "SSH service reloaded"
}
