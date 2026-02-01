#!/usr/bin/env bash

# Homelab CLI - A command-line tool for managing homelab installations and maintenance
# Usage: homelab <command> <subcommand>

set -euo pipefail

# Determine CLI directory based on script location
if [[ -L "${BASH_SOURCE[0]}" ]]; then
    CLI_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" 
else
    CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Source utility functions for consistent logging
if [[ -f "$CLI_DIR/libs/utils.sh" ]]; then
    source "$CLI_DIR/libs/utils.sh"
fi

# Function to display help
show_help() {
    cat << EOF
Homelab CLI - Manage your homelab installations and maintenance

USAGE:
    homelab <COMMAND> [SUBCOMMAND]

 COMMANDS:
     bootstrap     Bootstrap a fresh Ubuntu server for homelab use
     install       Install software and scripts
     maintain      Perform maintenance tasks
     observability Manage observability stack (Prometheus, Grafana, Loki)
     dotfiles      Manage dotfiles (stow, unstow, restow, verify, status)
     remove        Remove installed software (not implemented)
     self-update   Update CLI symlink to point to current repository
     help          Show this help message
 
 INSTALL SUBCOMMANDS:
     docker        Install Docker and Docker Compose
     observability Install observability stack
 
 OBSERVABILITY SUBCOMMANDS:
     install           Deploy the observability stack
     status            Show stack status and access URLs
     stop              Stop all services
     restart           Restart all services
     logs [svc]        Follow logs (optionally specify service)
     destroy           Remove stack and all data
     regenerate-config Regenerate alertmanager configuration from .env
     reset-password    Reset Grafana admin password
 
 MAINTAIN SUBCOMMANDS:
     tethering     Update USB tethering network configuration
 
 SELF-UPDATE OPTIONS:
     --force     Force update even if symlink already points correctly
 
 EXAMPLES:
     homelab bootstrap
     homelab install docker
     homelab maintain tethering
     homelab self-update
     homelab self-update --force
     homelab help

EOF
}

# Main command parsing
command=${1:-}
subcommand=${2:-}

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
            observability)
                bash "$CLI_DIR/install/observability.sh" install
                ;;
            "")
                echo "Error: install command requires a subcommand."
                echo "Available subcommands: docker, observability"
                exit 1
                ;;
            *)
                echo "Error: unknown install subcommand '$subcommand'"
                echo "Available subcommands: docker, observability"
                exit 1
                ;;
        esac
        ;;
    observability)
        # Validate that observability script exists
        if [[ ! -f "$CLI_DIR/install/observability.sh" ]]; then
            echo "Error: observability script not found at $CLI_DIR/install/observability.sh"
            exit 1
        fi
        
        # Pass all remaining args to observability script
        shift
        if ! bash "$CLI_DIR/install/observability.sh" "$@"; then
            echo "Error: observability command failed"
            exit 1
        fi
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
    dotfiles)
        # Pass subcommand to dotfiles script
        bash "$CLI_DIR/bootstrap/phases/dotfiles.sh" "${subcommand:-status}"
        ;;
    remove)
        echo "Remove functionality not implemented yet."
        ;;
    self-update)
        # Handle self-update command
        force=false

        # Parse flags for self-update
        shift  # Remove 'self-update' from arguments
        for arg in "$@"; do
            case $arg in
                --force)
                    force=true
                    ;;
            esac
        done

        # Get the path to this script
        script_path=""
        if [[ -L "${BASH_SOURCE[0]}" ]]; then
            # If this is a symlink, get the real path
            script_path="$(readlink -f "${BASH_SOURCE[0]}")"
        else
            script_path="$(realpath "${BASH_SOURCE[0]}")"
        fi

        symlink_path="/usr/local/bin/homelab"

        echo "Updating CLI symlink..."
        echo "Script location: $script_path"
        echo "Symlink target: $symlink_path"

        # Check if sudo is available
        if ! sudo -n true 2>/dev/null; then
            echo "Error: sudo access required"
            echo "Please run: sudo visudo and add appropriate privileges"
            exit 1
        fi

        # Check current state
        if [[ -L "$symlink_path" ]]; then
            current_target="$(readlink -f "$symlink_path")"

            if [[ "$current_target" == "$script_path" ]]; then
                if [[ "$force" == "true" ]]; then
                    echo "Symlink already points correctly, but --force specified. Re-creating..."
                else
                    echo "Symlink already points to correct location: $current_target"
                    echo "Nothing to do."
                    exit 0
                fi
            else
                echo "Current symlink points to: $current_target"
                echo "Updating to point to: $script_path"
            fi
        fi

        # Remove existing symlink or file
        sudo rm -f "$symlink_path"

        # Create new symlink
        if sudo ln -s "$script_path" "$symlink_path"; then
            echo "Success: CLI symlink updated to point to $script_path"
            echo "You can now run: homelab help"
            exit 0
        else
            echo "Error: Failed to create symlink"
            exit 1
        fi
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
