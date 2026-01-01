#!/usr/bin/env bash
# This script updates the tethering configuration on a Linux system.

set -e

# Detect the USB tethering network interface
USB_IFACE=$(ls /sys/class/net | grep enx)
echo "detected usb-tethering network interface: $USB_IFACE"

# Update systemd network configuration
echo -e "\nupdating systemd network configuration..."
sudo sed -i "s/^Name=.*/Name=$USB_IFACE/" /etc/systemd/network/10-usb.network

# Restart systemd-networkd to apply changes
echo -e "\nreloading network configuration..."
sudo networkctl reload
sudo networkctl up "$USB_IFACE"

# Check the status of the network interface
echo -e "\nchecking network interface status..."
networkctl status "$USB_IFACE"

# Verify internet connectivity
echo -e "\nverifying internet connectivity..."
ping -c 3 google.com
