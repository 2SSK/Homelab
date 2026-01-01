# Homelab

A learning-focused homelab repository for Ubuntu server management, featuring custom dotfiles and a CLI tool for installations and maintenance.

## Features

- **CLI Tool**: `homelab` command for managing Docker installs and USB tethering updates
- **Dotfiles**: Modular bash configuration with functions, aliases, and keybindings
- **Networking**: systemd-networkd setup for USB tethering
- **Documentation**: Guides for network configuration

## Quick Start

1. **Clone the repo**:

   ```bash
   git clone https://github.com/yourusername/homelab.git
   cd homelab
   ```

2. **Install the CLI**:

   ```bash
   make install
   ```

3. **Use the CLI**:

   ```bash
   homelab help
   homelab install docker
   homelab maintain tethering
   ```

4. **Deploy dotfiles**:
   ```bash
   cp -r dotfiles ~/
   cd ~/dotfiles
   stow .
   ```

## Learning Focus

This repo demonstrates:

- Bash scripting and CLI design
- Systemd network configuration
- Dotfile management
- Git-based infrastructure
- Ubuntu server administration

## License

MIT License</content>
<parameter name="filePath">/home/ssk/Code/Projects/building/Homelab/README.md

