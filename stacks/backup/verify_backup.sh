#!/usr/bin/env bash
# Verification script for restic backup repository
# Run restic check to verify backup integrity
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load restic configuration - check script dir first, then /etc/homelab for systemd
if [ -f "$SCRIPT_DIR/restic.env" ]; then
    . "$SCRIPT_DIR/restic.env"
elif [ -f "/etc/homelab/restic.env" ]; then
    . "/etc/homelab/restic.env"
fi

REPO="${RESTIC_REPOSITORY:-/mnt/backup/restic}"

echo "Verifying restic repository: $REPO"
restic -r "$REPO" check --light
echo "Verification complete."
