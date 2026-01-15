#!/usr/bin/env bash

# Homelab Bootstrap Script
# Bootstraps a fresh Ubuntu server for homelab use with essential services and security hardening

set -euo pipefail

# Logging setup
LOG_FILE="${LOG_FILE:-bootstrap.log}"
exec > >(tee -a "$LOG_FILE") 2>&1

# Error trap
trap 'echo "Error occurred at line $LINENO. Check $LOG_FILE for details." >&2' ERR

# Source utility functions
source "$(dirname "${BASH_SOURCE[0]}")/../libs/utils.sh"

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
    local packages=(curl wget git vim ufw fail2ban btop net-tools build-essential)

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

# Phase 2: systemd-networkd Setup
setup_networkd() {
    log_info "Phase 2: Setting up systemd-networkd..."

    # Detect USB interface
    local usb_interface=""
    for iface in /sys/class/net/*; do
        iface_name=$(basename "$iface")
        if [[ "$iface_name" == usb* ]] || [[ "$iface_name" == enx* ]]; then
            usb_interface="$iface_name"
            break
        fi
    done

    if [[ -z "$usb_interface" ]]; then
        log_warning "No USB interface (usb0 or enx*) detected. Skipping networkd setup."
        return 0
    fi

    log_info "Detected USB interface: $usb_interface"

    # Create network config if it doesn't exist
    local network_file="/etc/systemd/network/10-usb.network"
    if [[ ! -f "$network_file" ]]; then
        log_info "Creating $network_file..."
        sudo tee "$network_file" > /dev/null << EOF
[Match]
Name=$usb_interface

[Network]
DHCP=yes
EOF
        log_success "Network configuration created"
    else
        log_info "Network configuration already exists"
    fi

    # Enable systemd-networkd if not already enabled
    if ! service_status systemd-networkd; then
        log_info "Enabling systemd-networkd..."
        sudo systemctl enable systemd-networkd
        sudo systemctl start systemd-networkd
        log_success "systemd-networkd enabled and started"
    else
        log_info "systemd-networkd already enabled and running"
    fi

    # Enable systemd-resolved if not already enabled
    if ! service_status systemd-resolved; then
        log_info "Enabling systemd-resolved..."
        sudo systemctl enable systemd-resolved
        sudo systemctl start systemd-resolved
        log_success "systemd-resolved enabled and started"
    else
        log_info "systemd-resolved already enabled and running"
    fi

    # Link resolv.conf if not already linked
    if [[ ! -L /etc/resolv.conf ]] || [[ "$(readlink /etc/resolv.conf)" != "/run/systemd/resolve/stub-resolv.conf" ]]; then
        log_info "Linking resolv.conf to systemd-resolved..."
        sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        log_success "resolv.conf linked"
    else
        log_info "resolv.conf already linked correctly"
    fi

    # Bring interface up
    log_info "Bringing $usb_interface up..."
    sudo ip link set "$usb_interface" up
    log_success "Network interface brought up"
}

# Phase 3: SSH Hardening
harden_ssh() {
    log_info "Phase 3: Hardening SSH (Port: 2222)..."

    local ssh_config="/etc/ssh/sshd_config"
    local ssh_config_backup="/etc/ssh/sshd_config.backup"

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

# Phase 4: Tailscale Setup
setup_tailscale() {
    log_info "Phase 4: Setting up Tailscale..."

    # Check if tailscale is already installed and running
    if command_exists tailscale && service_status tailscaled; then
        log_info "Tailscale already installed and running"
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

    # Get auth key from environment or prompt
    local auth_key="${TAILSCALE_AUTH_KEY:-}"
    if [[ -z "$auth_key" ]]; then
        read -r -p "Enter Tailscale auth key: " auth_key
    fi

    if [[ -z "$auth_key" ]]; then
        log_error "No Tailscale auth key provided"
        return 1
    fi

    # Start Tailscale with auth key
    log_info "Starting Tailscale..."
    sudo tailscale up --auth-key="$auth_key" --accept-routes
    log_success "Tailscale started and authenticated"

    # Enable Tailscale service
    if ! service_status tailscaled; then
        sudo systemctl enable tailscaled
        sudo systemctl start tailscaled
        log_success "Tailscale service enabled"
    else
        log_info "Tailscale service already enabled"
    fi
}

# Phase 5: Dotfiles Setup
setup_dotfiles() {
    log_info "Phase 5: Setting up dotfiles..."

    local homelab_dir="$HOME/Homelab"
    local dotfiles_dir="$HOME/dotfiles"

    # Copy dotfiles if not exists
    if [[ ! -d "$dotfiles_dir" ]]; then
        if [[ -d "$homelab_dir/dotfiles" ]]; then
            log_info "Copying dotfiles..."
            cp -r "$homelab_dir/dotfiles" "$dotfiles_dir"
            log_success "Dotfiles copied"
        else
            log_warning "Homelab dotfiles directory not found at $homelab_dir/dotfiles"
            return 0
        fi
    else
        log_info "Dotfiles directory already exists"
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

# Phase 6: Docker Setup
setup_docker() {
    log_info "Phase 6: Setting up Docker..."

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

# Phase 7: Verification
verify_setup() {
    log_info "Phase 7: Verifying setup..."

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
            log_warning "Tailscale not connected (may need manual auth)"
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
        log_warning "systemd-networkd not running (may not be needed)"
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

# Main function
main() {
    log_info "Starting Homelab Bootstrap..."
    log_info "Log file: $LOG_FILE"

    check_root

    install_base_packages
    setup_networkd
    harden_ssh
    setup_tailscale
    setup_dotfiles
    setup_docker
    verify_setup

    log_success "Homelab bootstrap completed!"
    log_info "Please reboot the system to ensure all changes take effect."
    log_info "After reboot, verify SSH access on port 2222 and Tailscale connectivity."
}

# Run main function
main "$@"