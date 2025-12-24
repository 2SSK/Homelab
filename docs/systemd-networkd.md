---
created: 2025-12-22
tags: [homelab, systemd, networking, linux]
aliases: ["systemd-networkd", "networkd configuration", "homelab networking"]
---

# Homelab - systemd-networkd Configuration

## Overview

Guide to configuring systemd-networkd for network management in Homelab environments.

Bring **USB tethering internet** up on **Ubuntu minimal** using:

- `systemd-networkd`
- `systemd-resolved`
- **no editor**
- **no NetworkManager**
- **no ping**

## Steps

### 1. Enable USB tethering on your phone

(Android -> USB tethering ON)

Plug the USB cable.

### 2. Find the USB network interface (no tools needed)

```bash
ls /sys/class/net/
```

You'll see something like:

```text
lo usb0
```

or:

```text
lo enx...
```

> **Remember the interface name** (we'll call it `USB_IFACE`)

### 3. Create network config WITHOUT an editor

_Considering you have installed Alpine, Ubuntu minimal or any other minimal server image_

Replace `USB_IFACE` with your actual interface name.

```bash
sudo mkdir -p /etc/systemd/network
```

```bash
sudo sh -c 'cat> /etc/systemd/network/10-usb.network <<EOF
[Match]
Name=USB_IFACE

[Network]
DHCP=yes
EOF'
```

### 4. Enable required services (already installed by default)

```bash
sudo systemctl enable --now systemd-networkd
sudo systemctl enable --now systemd-resolved
```

Link DNS resolver:

```bash
sudo ln -sf /run/systemd/resolve/stud-resolv.conf /etc/resolv.conf
```

### 5. Bring the interface up

```bash
sudo networkctl reload
sudo networkctl up USB_IFACE
```

Check status:

```bash
networkctl status USB_IFACE
```

### 6. Verify internet **WITHOUT** ping

Try reaching Ubuntu archive:

```bash
getnet hosts archive.ubuntu.com
```
