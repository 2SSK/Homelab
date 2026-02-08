# Homelab

Production-ready Ubuntu server configuration with automated bootstrapping, dotfiles management, and a CLI for ongoing maintenance.

## Features

| Feature        | Description                                         |
| -------------- | --------------------------------------------------- |
| **Bootstrap**  | One-command server setup with 9 automated phases    |
| **Dotfiles**   | XDG-compliant bash/vim configs via GNU Stow         |
| **CLI Tool**   | `homelab` command for installations and maintenance |
| **Networking** | systemd-networkd with USB tethering support         |
| **Security**   | SSH hardening + Tailscale VPN integration           |
| **Containers** | Docker and Docker Compose setup                     |

## Quick Start

### Prerequisites

- Ubuntu Server 22.04+
- Git and curl installed
- Internet connection

### Installation

```bash
# Clone to /opt/Homelab (required location)
sudo mkdir -p /opt && sudo chown $USER:$USER /opt
git clone https://github.com/yourusername/Homelab.git /opt/Homelab
cd /opt/Homelab

# Full bootstrap (runs all phases)
./cli/homelab.sh bootstrap

# Start new shell
exec bash
```

### Basic Usage

```bash
homelab help                    # Show available commands
homelab dotfiles restow         # Update dotfiles after changes
homelab install docker          # Install Docker
homelab install observability   # Deploy monitoring stack
homelab observability status    # Check monitoring status
homelab maintain tethering      # Update USB tethering config
```

## Documentation

| Guide                                                     | Description                               |
| --------------------------------------------------------- | ----------------------------------------- |
| [Installation](docs/installation.md)                      | Full bootstrap process and file locations |
| [Dotfiles](docs/dotfiles.md)                              | Bash/vim configuration and customization  |
| [CLI Reference](docs/cli.md)                              | All commands and Makefile targets         |
| [Observability Stack](stacks/observability/docs/README.md)| Complete monitoring stack documentation   |
| [systemd-networkd](docs/systemd-networkd.md)              | USB tethering network setup               |

**Observability Documentation** (8 detailed guides):
- [Installation Guide](stacks/observability/docs/INSTALLATION.md) - Step-by-step setup
- [Configuration Reference](stacks/observability/docs/CONFIGURATION.md) - All settings explained
- [Alert Rules Guide](stacks/observability/docs/ALERTS.md) - 97 curated security/system alerts
- [Dashboard Guide](stacks/observability/docs/DASHBOARDS.md) - 6 pre-built dashboards
- [Operations Manual](stacks/observability/docs/OPERATIONS.md) - Daily procedures
- [Monitoring Guide](stacks/observability/docs/MONITORING.md) - What to watch
- [Contributing](stacks/observability/docs/CONTRIBUTING.md) - How to improve

## Project Structure

```
/opt/Homelab/
├── cli/
│   ├── homelab.sh              # Main CLI entrypoint
│   ├── bootstrap/              # Bootstrap phases
│   ├── install/                # Installation scripts
│   ├── maintain/               # Maintenance scripts
│   └── libs/                   # Shared utilities
├── dotfiles/
│   ├── bash/                   # Bash configuration (stow package)
│   └── vim/                    # Vim configuration (stow package)
├── stacks/
│   └── observability/          # Prometheus, Grafana, Loki stack
├── docs/                       # Documentation
└── Makefile                    # Make targets
```

## Observability Stack

Full monitoring with resource constraints for low-power servers:

| Component | Purpose | Memory | Health Monitoring |
|-----------|---------|--------|-------------------|
| Prometheus | Metrics | 512 MB | ✓ |
| Grafana | Dashboards | 256 MB | ✓ |
| Loki | Logs | 256 MB | ✓ |
| Alertmanager | Email alerts | 64 MB | ✓ |

**Recent Improvements (Feb 2026):**
- ✅ **Alert Optimization**: Reduced from 122 to 97 rules (20.5% reduction) to prevent alert fatigue
- ✅ **Production Documentation**: 8 comprehensive guides (~39,000 words)
- ✅ **Dashboard Cleanup**: Removed redundant dashboards (7 → 6)
- ✅ **Self-Monitoring**: Added Dead Man's Switch and capacity alerts

> All services include Docker healthchecks for automatic restart on failure.
> Grafana datasources use stable UIDs for dashboard portability.
> Complete documentation available at `stacks/observability/docs/`

## Dotfiles Highlights

- **Vi-mode** with `jk` escape mapping
- **Git-aware prompt** with branch and status indicators
- **FZF integration** for fuzzy file/directory navigation
- **Battery status** in prompt (for laptop servers)
- **XDG compliance** (`~/.config/bash/`)

## GitHub Actions

Automated deployment via Tailscale SSH on push to main branch.

## License

[MIT License](LICENSE) © 2025 Saurav Singh Karmwar</content>
