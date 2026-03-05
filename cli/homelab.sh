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

# Source backup helpers if available
if [[ -f "$CLI_DIR/libs/backup.sh" ]]; then
    # shellcheck source=/dev/null
    source "$CLI_DIR/libs/backup.sh"
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
    backup        Manage backup and restore (restic) operations
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

  BACKUP SUBCOMMANDS:
      run                Run backup (requires backup/restic.env)
      verify             Verify latest backup
      stage              Stage latest snapshot for restore (prints staged path)
      restore <snap|latest> <volume>
                         Restore a snapshot to a volume (interactive confirmation preserved)
      install-systemd    Install systemd unit/timer templates for backup (requires sudo)
      enable-timers      Enable and start homelab-backup.timer and homelab-prune.timer
      disable-timers     Disable and stop homelab-backup.timer and homelab-prune.timer
 
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
    backup)
        # Backup subcommands operate on files under repo/backup
        BACKUP_CMD=${subcommand:-}
        case $BACKUP_CMD in
            run)
                # Ensure restic.env exists
                if ! backup_check_restic_env "$CLI_DIR/.."; then
                    log_error "Missing backup/restic.env. Copy backup/restic.env.example and fill secrets before running."
                    exit 1
                fi

                # Run backup script; allow it to escalate via sudo if required
                # prefer stacks/backup/ copies of scripts
                BACKUP_SCRIPT="$CLI_DIR/../stacks/backup/backup.sh"
                if [[ ! -f "$BACKUP_SCRIPT" ]]; then
                    BACKUP_SCRIPT="$CLI_DIR/../backup/backup.sh"
                fi
                if [[ ! -x "$BACKUP_SCRIPT" ]]; then
                    if [[ -f "$BACKUP_SCRIPT" ]]; then
                        chmod +x "$BACKUP_SCRIPT" || true
                    else
                        log_error "Backup script not found at $BACKUP_SCRIPT"
                        exit 1
                    fi
                fi

                log_info "Starting backup..."
                # Use sudo to run backup script to ensure it can access volumes if needed
                if sudo -n true 2>/dev/null; then
                    sudo bash "$BACKUP_SCRIPT"
                else
                    bash "$BACKUP_SCRIPT"
                fi
                ;;
            verify)
                VERIFY_SCRIPT="$CLI_DIR/../stacks/backup/verify_backup.sh"
                if [[ ! -f "$VERIFY_SCRIPT" ]]; then
                    VERIFY_SCRIPT="$CLI_DIR/../backup/verify_backup.sh"
                fi
                if [[ ! -f "$VERIFY_SCRIPT" ]]; then
                    log_error "Verify script not found at $VERIFY_SCRIPT"
                    exit 1
                fi
                bash "$VERIFY_SCRIPT"
                ;;
            stage)
                STAGE_SCRIPT="$CLI_DIR/../stacks/backup/restore.sh"
                if [[ ! -f "$STAGE_SCRIPT" ]]; then
                    STAGE_SCRIPT="$CLI_DIR/../backup/restore.sh"
                fi
                if [[ ! -f "$STAGE_SCRIPT" ]]; then
                    log_error "Restore script not found at $STAGE_SCRIPT"
                    exit 1
                fi
                # 'stage latest' prints the staged path
                bash "$STAGE_SCRIPT" stage latest
                ;;
            restore)
                # restore <snapshot|latest> <volume>
                snap=${3:-}
                volume=${4:-}
                if [[ -z "$snap" || -z "$volume" ]]; then
                    log_error "Usage: homelab.sh backup restore <snapshot|latest> <volume>"
                    exit 1
                fi
                RESTORE_SCRIPT="$CLI_DIR/../stacks/backup/restore.sh"
                if [[ ! -f "$RESTORE_SCRIPT" ]]; then
                    RESTORE_SCRIPT="$CLI_DIR/../backup/restore.sh"
                fi
                if [[ ! -f "$RESTORE_SCRIPT" ]]; then
                    log_error "Restore script not found at $RESTORE_SCRIPT"
                    exit 1
                fi
                # Preserve interactive prompts from restore script
                bash "$RESTORE_SCRIPT" restore "$snap" "$volume"
                ;;
            install-systemd)
                # Install systemd unit/timer templates into /etc/systemd/system
                if ! sudo -n true 2>/dev/null; then
                    log_info "Installing systemd units requires sudo. You will be prompted for your password."
                fi
                if ! backup_install_systemd_units "$CLI_DIR/.."; then
                    log_error "Failed to install systemd units"
                    exit 1
                fi
                log_info "Reloading systemd daemon"
                sudo systemctl daemon-reload
                log_success "Systemd units installed. Run 'homelab.sh backup enable-timers' to enable timers."
                ;;
            enable-timers)
                log_info "Enabling homelab timers..."
                sudo systemctl enable --now homelab-backup.timer homelab-prune.timer
                log_success "Timers enabled and started."
                ;;
            disable-timers)
                log_info "Disabling homelab timers..."
                sudo systemctl disable --now homelab-backup.timer homelab-prune.timer
                log_success "Timers disabled and stopped."
                ;;
            "")
                echo "Error: backup command requires a subcommand."
                echo "Available subcommands: run, verify, stage, restore, install-systemd, enable-timers, disable-timers"
                exit 1
                ;;
            *)
                echo "Error: unknown backup subcommand '$BACKUP_CMD'"
                echo "Available subcommands: run, verify, stage, restore, install-systemd, enable-timers, disable-timers"
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
