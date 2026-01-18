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
homelab maintain tethering      # Update USB tethering config
```

## Documentation

| Guide                                        | Description                               |
| -------------------------------------------- | ----------------------------------------- |
| [Installation](docs/installation.md)         | Full bootstrap process and file locations |
| [Dotfiles](docs/dotfiles.md)                 | Bash/vim configuration and customization  |
| [CLI Reference](docs/cli.md)                 | All commands and Makefile targets         |
| [systemd-networkd](docs/systemd-networkd.md) | USB tethering network setup               |

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
├── docs/                       # Documentation
└── Makefile                    # Make targets
```

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
