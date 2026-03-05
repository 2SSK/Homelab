#!/bin/sh
set -eu

# Wrapper to call verify script in stacks/backup
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/../backup/verify_backup.sh" ]; then
    exec "$SCRIPT_DIR/../backup/verify_backup.sh"
else
    echo "verify_backup.sh not found in repo backup/ directory"
    exit 2
fi
