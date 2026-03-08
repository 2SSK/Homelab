#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TMP_RESTORE_DIR_BASE="/tmp/homelab-restore"

# Look for restic.env in script directory first, then /etc/homelab for systemd installations
if [ -f "$SCRIPT_DIR/restic.env" ]; then
    . "$SCRIPT_DIR/restic.env"
elif [ -f "/etc/homelab/restic.env" ]; then
    . "/etc/homelab/restic.env"
fi

REPO="${RESTIC_REPOSITORY:-/mnt/backup/restic}"

usage() {
    cat <<EOF
Usage: $0 <command>

Commands:
  list                          List restic snapshots (human readable)
  stage <snapshot|latest>       Restore snapshot into a temporary staging dir (non-destructive)
  restore <snapshot|latest> <docker-volume-name>   Restore given snapshot's volume tar into docker volume (DESTRUCTIVE)
EOF
}

cmd="${1:-}" || true
case "$cmd" in
    list)
        restic -r "$REPO" snapshots
        ;;
    stage)
        snap="${2:-latest}"
        DIR="${TMP_RESTORE_DIR_BASE}.$(date +%s)"
        mkdir -p "$DIR"
        echo "Staging snapshot '$snap' into $DIR"
        restic -r "$REPO" restore "$snap" --target "$DIR"
        echo "Staged into: $DIR"
        ;;
    restore)
        snap="${2:-}"; vol="${3:-}"
        if [ -z "$snap" ] || [ -z "$vol" ]; then
            echo "ERROR: restore requires snapshot and docker volume name"
            usage
            exit 2
        fi
        echo "*** WARNING: This is a destructive restore. It will overwrite contents of docker volume: $vol ***"
        read -r -p "Type the volume name ($vol) to confirm: " confirm
        if [ "$confirm" != "$vol" ]; then
            echo "Confirmation mismatch; aborting"
            exit 3
        fi
        if ! docker volume inspect "$vol" >/dev/null 2>&1; then
            echo "Volume $vol does not exist; creating..."
            docker volume create "$vol"
        fi
        TMPDIR="${TMP_RESTORE_DIR_BASE}.$(date +%s)"
        mkdir -p "$TMPDIR"
        echo "Restoring snapshot '$snap' into staging $TMPDIR"
        restic -r "$REPO" restore "$snap" --target "$TMPDIR"
        TAR="$(find "$TMPDIR" -type f -name "vol_${vol}*.tar*" | head -n1 || true)"
        if [ -z "$TAR" ]; then
            echo "No archive for volume $vol found in snapshot. Available files:"
            find "$TMPDIR" -maxdepth 2 -type f -print
            exit 4
        fi
        docker run --rm -v "$vol":/target -v "$(dirname "$TAR")":/backup alpine sh -c \
            "apk add --no-cache tar zstd >/dev/null 2>&1 && zstd -dc /backup/$(basename \"$TAR\") | tar -C /target -xpf -"
        docker run --rm -v "$vol":/data alpine sh -c "chown -R 1000:1000 /data || true"
        echo "Restore complete."
        ;;
    *)
        usage
        ;;
esac
