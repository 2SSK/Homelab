#!/usr/bin/env bash

set -euo pipefail

# Phase 7: CLI Installation
install_cli() {
    log_info "Phase 6: Installing Homelab CLI symlink..."
    
    local force_cli_install="${FORCE_CLI_INSTALL:-false}"
    local symlink_path="/usr/local/bin/homelab"
    
    # Detect repository directory and script path
    # Use parameter expansion to get absolute path of this script
    local bootstrap_dir
    
    if [[ -n "${BASH_SOURCE[0]}" ]]; then
        # Go up from phases/ -> bootstrap/ -> cli/
        bootstrap_dir="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)"
    else
        # Fallback to default location
        bootstrap_dir="/opt/Homelab/cli"
    fi
    
    # CLI script is in the cli directory
    local target_script="${bootstrap_dir}/homelab.sh"
    
    # Check if target script exists
    if [[ ! -f "$target_script" ]]; then
        log_error "CLI script not found at: $target_script"
        log_info "Please ensure that Homelab repository is properly located at $bootstrap_dir"
        return 1
    fi

    log_info "Repository directory: $bootstrap_dir"
    log_info "Target CLI script: $target_script"

    # Check if user has sudo access
    if ! sudo -n true 2>/dev/null; then
        log_error "Sudo access required to create CLI symlink"
        log_info "Please run: sudo visudo and add appropriate privileges, or run this script with sudo"
        return 1
    fi

    # Check current state of the symlink
    if [[ -L "$symlink_path" ]]; then
        # Symlink exists - check if it is valid and points to the right location
        local current_target
        current_target="$(readlink -f "$symlink_path")"

        if [[ -z "$current_target" ]]; then
            # Broken symlink
            log_warning "Found broken symlink at $symlink_path"
            log_info "Removing broken symlink..."
            sudo rm -f "$symlink_path"
            create_symlink "$target_script" "$symlink_path" "$force_cli_install"
        else
            # Symlink is valid - check if it points to the right location
            # Convert to absolute paths for comparison
            local absolute_target
            absolute_target="$(cd "$(dirname "$target_script")" && pwd)/$(basename "$target_script")"
            local absolute_current
            absolute_current="$(cd "$(dirname "$current_target")" && pwd)/$(basename "$current_target")"

            if [[ "$absolute_current" == "$absolute_target" ]]; then
                # Symlink points to the correct location
                log_success "CLI symlink already correctly installed at $symlink_path"

                if [[ "$force_cli_install" == "true" ]]; then
                    log_info "--force flag detected, updating symlink..."
                    sudo rm -f "$symlink_path"
                    create_symlink "$target_script" "$symlink_path" "$force_cli_install"
                fi
            else
                # Symlink points to wrong location
                log_warning "Symlink exists but points to different location"
                log_info "  Current: $current_target"
                log_info "  Expected: $target_script"

                if [[ "$force_cli_install" == "true" ]]; then
                    log_info "--force flag detected, updating symlink..."
                    sudo rm -f "$symlink_path"
                    create_symlink "$target_script" "$symlink_path" "$force_cli_install"
                else
                    log_info "Use --force flag to update the symlink"
                    return 1
                fi
            fi
        fi
    elif [[ -e "$symlink_path" ]]; then
        # A regular file or directory exists at the symlink location
        log_error "A file or directory already exists at $symlink_path"
        log_info "Please remove it manually or use --force flag to overwrite"

        if [[ "$force_cli_install" == "true" ]]; then
            log_warning "--force flag detected, removing existing file/directory..."
            sudo rm -rf "$symlink_path"
            create_symlink "$target_script" "$symlink_path" "$force_cli_install"
        else
            return 1
        fi
    else
        # No symlink exists - create it
        create_symlink "$target_script" "$symlink_path" "$force_cli_install"
    fi

    # Verify the symlink was created correctly
    if [[ -L "$symlink_path" ]]; then
        if [[ -x "$symlink_path" ]]; then
            log_success "CLI symlink installed and executable: $symlink_path"
            log_info "You can now run: homelab help"
            return 0
        else
            log_warning "CLI symlink created but may not be executable"
            log_info "Run: sudo chmod +x $target_script"
            return 1
        fi
    else
        log_error "Failed to create CLI symlink"
        return 1
    fi
}

# Helper function to create the symlink
create_symlink() {
    local target="$1"
    local symlink="$2"
    # shellcheck disable=SC2034  # force reserved for future use
    local force="${3:-false}"

    log_info "Creating symlink at $symlink..."

    if ! sudo ln -sf "$target" "$symlink"; then
        log_error "Failed to create symlink"
        return 1
    fi

    # Make sure the target script is executable
    if [[ ! -x "$target" ]]; then
        log_info "Making target script executable..."
        sudo chmod +x "$target"
    fi

    log_success "CLI symlink created successfully"
    return 0
}
