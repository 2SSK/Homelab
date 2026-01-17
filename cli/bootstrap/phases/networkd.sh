#!/usr/bin/env bash

set -euo pipefail

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
        log_warning "No USB interface \(usb0 or enx*\) detected. Skipping networkd setup."
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
    
    # Create network config if it does not exist
    local network_file="/etc/systemd/network/10-usb.network"
    if [[ ! -f "$network_file" ]]; then
        log_info "Creating $network_file..."
        sudo tee "$network_file" > /dev/null << NET_EOF
[Match]
Name=$usb_interface

[Network]
DHCP=yes
NET_EOF
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
