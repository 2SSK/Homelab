#!/usr/bin/env bash
# This script updates the tethering configuration on a Linux system.

set -euo pipefail

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../libs/utils.sh"

# Detect the USB tethering network interface
USB_IFACE=""
for iface in /sys/class/net/enx* /sys/class/net/usb*; do
    if [[ -e "$iface" ]]; then
        USB_IFACE=$(basename "$iface")
        break
    fi
done

if [[ -z "$USB_IFACE" ]]; then
    log_error "No USB tethering interface (enx* or usb*) detected"
    exit 1
fi

log_info "Detected usb-tethering network interface: $USB_IFACE"

# Check if network config exists
if [[ ! -f /etc/systemd/network/10-usb.network ]]; then
    log_error "Network configuration file not found: /etc/systemd/network/10-usb.network"
    log_info "Run 'homelab bootstrap' first to create the configuration"
    exit 1
fi

# Update systemd network configuration
log_info "Updating systemd network configuration..."
sudo sed -i "s/^Name=.*/Name=$USB_IFACE/" /etc/systemd/network/10-usb.network
log_success "Network configuration updated"

# Restart systemd-networkd to apply changes
log_info "Reloading network configuration..."
sudo networkctl reload
sudo networkctl up "$USB_IFACE"

# Check the status of the network interface
log_info "Checking network interface status..."
networkctl status "$USB_IFACE"

# Verify internet connectivity
log_info "Verifying internet connectivity..."
if ping -c 3 google.com >/dev/null 2>&1; then
    log_success "Internet connectivity verified"
else
    log_error "Internet connectivity check failed"
    exit 1
fi

log_success "Tethering configuration updated successfully"
