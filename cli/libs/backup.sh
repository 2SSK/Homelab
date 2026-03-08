#!/usr/bin/env bash
# Backup helper functions for Homelab CLI
# Provides small helpers for installing systemd units and checking restic env

set -euo pipefail

# Check for restic.env in repository backup/ directory
# Accepts repo root or parent directory of CLI_DIR
backup_check_restic_env() {
    repo_root=${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}
    # Prefer stacks/backup location; fallback to legacy backup/ for compatibility
    env_file1="$repo_root/stacks/backup/restic.env"
    env_file2="$repo_root/backup/restic.env"
    if [[ -f "$env_file1" ]]; then
        return 0
    elif [[ -f "$env_file2" ]]; then
        return 0
    else
        return 1
    fi
}

# Install systemd unit and timer files for backup from stacks/observability/systemd or homelab/systemd
# Copies files into /etc/systemd/system
backup_install_systemd_units() {
    repo_root=${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}

    # Look in stacks/backup/systemd for backup units
    src_dir="$repo_root/stacks/backup/systemd"
    if [[ ! -d "$src_dir" ]]; then
        src_dir="$repo_root/homelab/systemd"
    fi

    if [[ ! -d "$src_dir" ]]; then
        echo "Source systemd directory not found in stacks/backup/systemd or homelab/systemd"
        return 1
    fi

    files=(homelab-backup.service homelab-backup.timer homelab-prune.service homelab-prune.timer)

    for f in "${files[@]}"; do
        src="$src_dir/$f"
        dst="/etc/systemd/system/$f"
        if [[ ! -f "$src" ]]; then
            echo "Warning: $src not found; skipping"
            continue
        fi
        echo "Installing $f to /etc/systemd/system/"
        sudo cp "$src" "$dst"
        sudo chown root:root "$dst"
        sudo chmod 644 "$dst"
    done

    return 0
}
