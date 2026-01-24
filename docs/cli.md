---
created: 2026-01-18
tags: [homelab, cli, makefile, commands]
aliases: ["homelab cli", "command reference", "makefile targets"]
---

# Homelab - CLI Reference

## Overview

Command-line interface for managing the Homelab server.

Two interfaces available:

- **`homelab`** command (after installation)
- **`make`** targets (from repository)

## CLI Commands

### Usage

```bash
homelab <command> [subcommand] [options]
```

### Bootstrap

Run full server setup:

```bash
homelab bootstrap
```

> **Note:** Runs all 9 phases. Safe to re-run (idempotent).

### Dotfiles

Manage dotfiles via GNU Stow:

```bash
homelab dotfiles stow       # Install symlinks
homelab dotfiles unstow     # Remove symlinks  
homelab dotfiles restow     # Reinstall after changes
homelab dotfiles verify     # Verify all symlinks
homelab dotfiles status     # Show package status
```

### Install

Install specific components:

```bash
homelab install docker      # Install Docker + Compose
```

### Observability

Manage the monitoring stack:

```bash
homelab observability install          # Deploy full stack
homelab observability status           # Show status and access URLs
homelab observability stop             # Stop all services
homelab observability restart          # Restart services
homelab observability logs [service]   # Follow logs (optional: specific service)
homelab observability regenerate-config # Regenerate alertmanager config
homelab observability reset-password   # Reset Grafana admin password
homelab observability destroy          # Remove stack and data (requires confirmation)
```

**Examples:**
```bash
# Initial installation
homelab install observability

# Check if services are healthy
homelab observability status

# View logs for specific service
homelab observability logs promtail

# Update configuration after editing .env
homelab observability regenerate-config
homelab observability restart
```

### Maintain

Maintenance tasks:

```bash
homelab maintain tethering  # Update USB tethering config
```

### Self-Update

Update CLI to match current repository:

```bash
homelab self-update         # Update if needed
homelab self-update --force # Force update
```

### Help

Show available commands:

```bash
homelab help
```

## Makefile Targets

Run from `/opt/Homelab`:

```bash
cd /opt/Homelab
make <target>
```

### Installation

| Target | Description |
|--------|-------------|
| `make install` | Full install (CLI + dotfiles) |
| `make uninstall` | Full uninstall |
| `make install-cli` | Install homelab command only |
| `make uninstall-cli` | Remove homelab command |

### Dotfiles

| Target | Description |
|--------|-------------|
| `make dotfiles` | Install dotfiles via Stow |
| `make dotfiles-unstow` | Remove dotfiles symlinks |
| `make dotfiles-restow` | Restow after changes |
| `make dotfiles-verify` | Verify symlinks |
| `make dotfiles-status` | Show status |

### Help

```bash
make help
```

## CLI Installation

### Automatic (via bootstrap)

```bash
./cli/homelab.sh bootstrap
```

### Manual

```bash
sudo ln -sf /opt/Homelab/cli/homelab.sh /usr/local/bin/homelab
```

Or via Make:

```bash
make install-cli
```

### Verify

```bash
which homelab
homelab help
```

## Examples

### Fresh Server Setup

```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/Homelab.git /opt/Homelab
cd /opt/Homelab

# Run bootstrap
./cli/homelab.sh bootstrap

# Verify
homelab help
exec bash
```

### Update Dotfiles After Edit

```bash
cd /opt/Homelab
git pull
homelab dotfiles restow
exec bash
```

### Add Docker Later

```bash
homelab install docker
```

### Troubleshooting Stow

```bash
# Remove old symlinks
rm -f ~/.bashrc
rm -rf ~/.config/bash

# Restow
homelab dotfiles restow
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FORCE_PACKAGES` | `false` | Force package reinstall |
| `FORCE_NETWORKD` | `false` | Force network reconfiguration |
| `FORCE_TAILSCALE` | `false` | Force Tailscale reinstall |
| `FORCE_DOCKER` | `false` | Force Docker reinstall |

Example:

```bash
FORCE_DOCKER=true ./cli/homelab.sh bootstrap
```
