#!/usr/bin/env bash

# Homelab CLI - A command-line tool for managing homelab installations and maintenance
# Usage: homelab <command> <subcommand>

set -e

CLI_DIR="$HOME/Homelab/cli"

# Function to display help
show_help() {
    cat << EOF
Homelab CLI - Manage your homelab installations and maintenance

USAGE:
    homelab <COMMAND> [SUBCOMMAND]

 COMMANDS:
     bootstrap   Bootstrap a fresh Ubuntu server for homelab use
     install     Install software and scripts
     maintain    Perform maintenance tasks
     remove      Remove installed software (not implemented)
     help        Show this help message

INSTALL SUBCOMMANDS:
    docker      Install Docker and Docker Compose

MAINTAIN SUBCOMMANDS:
    tethering   Update USB tethering network configuration

EXAMPLES:
    homelab bootstrap
    homelab install docker
    homelab maintain tethering
    homelab help

EOF
}

# Main command parsing
command=$1
subcommand=$2

case $command in
    bootstrap)
        echo "Bootstrapping homelab server..."
        bash "$CLI_DIR/bootstrap/bootstrap.sh"
        echo "Bootstrap completed successfully."
        ;;
    install)
        case $subcommand in
            docker)
                echo "Installing Docker..."
                bash "$CLI_DIR/install/docker.sh"
                echo "Docker installation completed."
                ;;
            "")
                echo "Error: install command requires a subcommand."
                echo "Available subcommands: docker"
                exit 1
                ;;
            *)
                echo "Error: unknown install subcommand '$subcommand'"
                echo "Available subcommands: docker"
                exit 1
                ;;
        esac
        ;;
    maintain)
        case $subcommand in
            tethering)
                echo "Updating tethering configuration..."
                bash "$CLI_DIR/maintain/update-tethering.sh"
                echo "Tethering update completed."
                ;;
            "")
                echo "Error: maintain command requires a subcommand."
                echo "Available subcommands: tethering"
                exit 1
                ;;
            *)
                echo "Error: unknown maintain subcommand '$subcommand'"
                echo "Available subcommands: tethering"
                exit 1
                ;;
        esac
        ;;
    remove)
        echo "Remove functionality not implemented yet."
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        echo "Error: no command specified."
        show_help
        exit 1
        ;;
    *)
        echo "Error: unknown command '$command'"
        show_help
        exit 1
        ;;
esac
