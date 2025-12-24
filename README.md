# Homelab Configuration Repository

A personal homelab setup repository containing dotfiles, scripts, and configurations for managing a Ubuntu minimal server environment.

## Overview

This repository serves as the central storage for my homelab infrastructure, featuring:

- Custom bash configuration with modular setup
- systemd-networkd with USB tethering for internet connectivity
- Tailscale for secure private SSH networking
- Organized dotfiles and utility scripts

## Technologies Used

- **OS**: Ubuntu Minimal Image
- **Networking**: systemd-networkd with USB tethering
- **VPN**: Tailscale for private network access
- **Shell**: Custom bash configuration with modular functions
- **Infrastructure**: Git-based configuration management

## Quick Start

### Prerequisites

- Ubuntu Server (minimal installation)
- USB cable for tethering
- Android/iOS device with internet connection

### Initial Setup

1. **Install Ubuntu Minimal**

   ```bash
   # Download and install Ubuntu minimal image
   # Configure basic system settings
   ```

2. **Clone Repository**

   ```bash
   git clone https://github.com/yourusername/homelab.git
   cd homelab
   ```

3. **Setup Networking**

   ```bash
   # Configure systemd-networkd for USB tethering
   # See docs/systemd-networkd.md for detailed setup
   ```

4. **Install Tailscale**

   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   ```

5. **Deploy Dotfiles**
   ```bash
   # Copy dotfiles to appropriate locations
   cp -r dots/* ~/
   source ~/.bashrc
   ```

## Repository Structure

```
homelab/
├── dots/                    # Dotfiles and configurations
│   ├── .bashrc             # Main bash configuration
│   └── .config/
│       └── bash/           # Modular bash config
├── docs/                    # Documentation
│   └── systemd-networkd.md # Network setup guide
├── scripts/                 # Utility scripts
└── AGENTS.md               # Agent guidelines for development
```

## Networking Setup

### USB Tethering with systemd-networkd

- Uses systemd-networkd for network management
- Automatic USB device detection
- Persistent configuration across reboots

### Tailscale VPN

- Private networking for secure SSH access
- Mesh networking between devices
- Zero-config VPN setup

## Bash Configuration

Custom modular bash setup featuring:

- Organized aliases by category
- Utility functions for system management
- Keybindings and prompt customization
- Conditional sourcing for portability

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

