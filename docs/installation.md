---
created: 2026-01-18
tags: [homelab, bootstrap, installation, ubuntu]
aliases: ["homelab installation", "bootstrap guide", "server setup"]
---

# Homelab - Installation Guide

## Overview

Guide to installing and bootstrapping a fresh Ubuntu server with the Homelab configuration.

Sets up:

- **systemd-networkd** for networking
- **Tailscale** for secure remote access
- **Docker** and Docker Compose
- **Dotfiles** via GNU Stow
- **SSH hardening**

## Prerequisites

### System Requirements

- Ubuntu Server 22.04+ (minimal install recommended)
- Internet connection (USB tethering supported)
- SSH access or physical console

### Required Packages

```bash
sudo apt update && sudo apt install -y git curl
```

## Steps

### 1. Clone to /opt/Homelab

> **Important:** The production location must be `/opt/Homelab`

```bash
sudo mkdir -p /opt
sudo chown $USER:$USER /opt
git clone https://github.com/YOUR_USERNAME/Homelab.git /opt/Homelab
cd /opt/Homelab
```

### 2. Run Full Bootstrap

Bootstrap runs all phases automatically:

```bash
./cli/homelab.sh bootstrap
```

This executes:

| Phase | Description |
|-------|-------------|
| 1. Packages | Install base system packages |
| 2. Network | Configure systemd-networkd |
| 3. SSH | Harden SSH configuration |
| 4. Tailscale | Install and configure Tailscale VPN |
| 5. Dotfiles | Stow bash and vim configurations |
| 6. Vim | Copy vim config to root user |
| 7. CLI | Install `homelab` command globally |
| 8. Docker | Install Docker and Docker Compose |
| 9. Verify | Run verification checks |

### 3. Verify Installation

```bash
homelab help
```

Check dotfiles:

```bash
ls -la ~/.bashrc ~/.config/bash/
```

### 4. Start New Shell

```bash
exec bash
```

## Post-Installation (Optional)

### Install Observability Stack

After bootstrap completes, optionally install monitoring:

```bash
homelab install observability
```

Follow the prompts to configure Grafana password and email alerts.

See [Observability Documentation](observability.md) for full setup guide.

## Logs

Bootstrap logs are stored at:

```text
~/.local/state/homelab/bootstrap.log
```

View logs:

```bash
cat ~/.local/state/homelab/bootstrap.log
```

## File Locations

| Path | Purpose |
|------|---------|
| `/opt/Homelab` | Main repository (production) |
| `~/.config/bash/` | Bash configuration (symlinked) |
| `~/.local/state/homelab/` | Runtime logs |
| `~/.dotfiles_backup/` | Backup of replaced files |

## Troubleshooting

### Stow Conflicts

If stow reports conflicts:

```bash
rm -f ~/.bashrc
rm -rf ~/.config/bash
./cli/homelab.sh dotfiles restow
```

### Re-run Bootstrap

Bootstrap is idempotent. Re-run safely with:

```bash
./cli/homelab.sh bootstrap
```
