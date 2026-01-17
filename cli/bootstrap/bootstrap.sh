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
    local packages=(curl wget git vim ufw fail2ban btop net-tools build-essential fzf tree xclip stow)

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
    
    local force_networkd="${FORCE_NETWORKD:-false}"
    
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
    
    # Check if systemd-networkd already configured
    if [[ "$force_networkd" == "true" ]]; then
        log_info "Force flag set. Will reconfigure systemd-networkd."
    elif systemctl is-enabled systemd-networkd >/dev/null 2>&1 && \
       systemctl is-active systemd-networkd >/dev/null 2>&1 && \
       [[ -f "/etc/systemd/network/10-usb.network" ]]; then
        log_info "systemd-networkd already configured and running. Skipping..."
        return 0
    fi
    
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
        read -r -p "Enter Tailscale auth key (leave empty for browser authentication): " auth_key
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
        read -r -p "Advertise as exit node? (y/N): " advertise_exit
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

# Phase 6: CLI Installation
install_cli() {
    log_info "Phase 6: Installing Homelab CLI symlink..."
    
    local force_cli_install="${FORCE_CLI_INSTALL:-false}"
    local symlink_path="/usr/local/bin/homelab"
    
    # Detect repository directory and script path
    # Use parameter expansion to get absolute path of this script
    local bootstrap_dir
    local bootstrap_script
    
    if [[ -n "${BASH_SOURCE[0]}" ]]; then
        bootstrap_dir="$(cd "${BASH_SOURCE[0]%/*" && pwd)"
        bootstrap_script="${BASH_SOURCE[0]}"
    else
        # Fallback to default location
        bootstrap_dir="$HOME/Homelab"
        bootstrap_script="$bootstrap_dir/cli/bootstrap/bootstrap.sh"
    fi
    
    # CLI script is in same directory as bootstrap.sh
    local target_script="${bootstrap_dir}/cli/homelab.sh"
    
    # Check if target script exists
    if [[ ! -f "$target_script" ]]; then
        log_error "CLI script not found at: $target_script"
        log_info "Please ensure that Homelab repository is properly located at $bootstrap_dir"
        return 1
    fi

    local target_script="${script_dir}/cli/homelab.sh"

    # Check if the target script exists
    if [[ ! -f "$target_script" ]]; then
        log_error "CLI script not found at: $target_script"
        log_info "Please ensure the Homelab repository is properly located at $script_dir"
        return 1
    fi

    log_info "Repository directory: $script_dir"
    log_info "Target CLI script: $target_script"

    # Check if user has sudo access
    if ! sudo -n true 2>/dev/null; then
        log_error "Sudo access required to create CLI symlink"
        log_info "Please run: sudo visudo and add appropriate privileges, or run this script with sudo"
        return 1
    fi

    # Check current state of the symlink
    if [[ -L "$symlink_path" ]]; then
        # Symlink exists - check if it's valid and points to the right location
        local current_target
        current_target="$(readlink -f "$symlink_path")"

        if [[ -z "$current_target" ]]; then
            # Broken symlink
            log_warning "Found broken symlink at $symlink_path"
            log_info "Removing broken symlink..."
            sudo rm -f "$symlink_path"
            create_symlink "$target_script" "$symlink_path" "$force_cli_install"
        else
            # Symlink is valid - check if it points to the right location
            # Convert to absolute paths for comparison
            local absolute_target
            absolute_target="$(cd "$(dirname "$target_script")" && pwd)/$(basename "$target_script")"
            local absolute_current
            absolute_current="$(cd "$(dirname "$current_target")" && pwd)/$(basename "$current_target")"

            if [[ "$absolute_current" == "$absolute_target" ]]; then
                # Symlink points to the correct location
                log_success "CLI symlink already correctly installed at $symlink_path"

                if [[ "$force_cli_install" == "true" ]]; then
                    log_info "--force flag detected, updating symlink..."
                    sudo rm -f "$symlink_path"
                    create_symlink "$target_script" "$symlink_path" "$force_cli_install"
                fi
            else
                # Symlink points to wrong location
                log_warning "Symlink exists but points to different location"
                log_info "  Current: $current_target"
                log_info "  Expected: $target_script"

                if [[ "$force_cli_install" == "true" ]]; then
                    log_info "--force flag detected, updating symlink..."
                    sudo rm -f "$symlink_path"
                    create_symlink "$target_script" "$symlink_path" "$force_cli_install"
                else
                    log_info "Use --force flag to update the symlink"
                    return 1
                fi
            fi
        fi
    elif [[ -e "$symlink_path" ]]; then
        # A regular file or directory exists at the symlink location
        log_error "A file or directory already exists at $symlink_path"
        log_info "Please remove it manually or use --force flag to overwrite"

        if [[ "$force_cli_install" == "true" ]]; then
            log_warning "--force flag detected, removing existing file/directory..."
            sudo rm -rf "$symlink_path"
            create_symlink "$target_script" "$symlink_path" "$force_cli_install"
        else
            return 1
        fi
    else
        # No symlink exists - create it
        create_symlink "$target_script" "$symlink_path" "$force_cli_install"
    fi

    # Verify the symlink was created correctly
    if [[ -L "$symlink_path" ]]; then
        if [[ -x "$symlink_path" ]]; then
            log_success "CLI symlink installed and executable: $symlink_path"
            log_info "You can now run: homelab help"
            return 0
        else
            log_warning "CLI symlink created but may not be executable"
            log_info "Run: sudo chmod +x $target_script"
            return 1
        fi
    else
        log_error "Failed to create CLI symlink"
        return 1
    fi
}

# Helper function to create the symlink
create_symlink() {
    local target="$1"
    local symlink="$2"
    local force="$3"

    log_info "Creating symlink at $symlink..."

    if ! sudo ln -sf "$target" "$symlink"; then
        log_error "Failed to create symlink"
        return 1
    fi

    # Make sure the target script is executable
    if [[ ! -x "$target" ]]; then
        log_info "Making target script executable..."
        sudo chmod +x "$target"
    fi

    log_success "CLI symlink created successfully"
    return 0
}

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
        log_info "User vim undo directory not found (optional)"
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
    # Parse command-line arguments
    local force_install=false
    for arg in "$@"; do
        case $arg in
            --force)
                force_install=true
                export FORCE_CLI_INSTALL="true"
                export FORCE_NETWORKD="true"
                export FORCE_SSH="true"
                export FORCE_TAILSCALE="true"
                export FORCE_DOTFILES="true"
                export FORCE_VIM="true"
                export FORCE_DOCKER="true"
                shift
                ;;
        esac
    done

    log_info "Starting Homelab Bootstrap..."
    log_info "Log file: $LOG_FILE"

    if [[ "$force_install" == "true" ]]; then
        log_info "Running with --force flag - will overwrite existing configurations"
    fi

    check_root

    install_base_packages
    setup_networkd
    harden_ssh
    setup_tailscale
    setup_dotfiles
    setup_vim_root
    install_cli
    setup_docker
    verify_setup

    log_success "Homelab bootstrap completed!"
    log_info "Please reboot the system to ensure all changes take effect."
    log_info "After reboot, verify SSH access on port 2222 and Tailscale connectivity."
    log_info "Run 'homelab help' to see available CLI commands."
}

# Run main function
main "$@"
