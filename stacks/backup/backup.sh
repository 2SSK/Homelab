#!/usr/bin/env bash
#
# Homelab backup orchestrator (moved to stacks/backup)
# See docs/backup-and-restore.md for runbook and operator guidance
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOSTNAME="$(hostname -s)"
TS="$(date +%Y%m%dT%H%M%S%z)"
TMPDIR="$(mktemp -d -t homelab-backup-XXXXXX)"
BACKUP_BASE="/var/backups/homelab"
DEST_DIR="$BACKUP_BASE/$HOSTNAME/$TS"
MANIFEST_FILE="$TMPDIR/manifest.txt"
CHECKSUM_FILE="$TMPDIR/checksums.sha256"
RESTIC_LOG="$TMPDIR/restic.stdout.log"
PAUSED_CONTAINERS=""

cleanup() {
    local rc=$?
    echo "Cleanup: rc=$rc"
    if [ -d "$DEST_DIR" ] || mkdir -p "$DEST_DIR" 2>/dev/null; then
        cp -a "$MANIFEST_FILE" "$CHECKSUM_FILE" "$RESTIC_LOG" "$DEST_DIR/" 2>/dev/null || true
    fi
    if [ -n "$PAUSED_CONTAINERS" ]; then
        for c in $PAUSED_CONTAINERS; do
            if docker ps -a --format '{{.ID}}' | grep -q "$c"; then
                docker unpause "$c" || true
            fi
        done
    fi
    rm -rf "$TMPDIR" || true
    exit $rc
}
trap cleanup EXIT INT TERM

# Look for restic.env in script directory first, then /etc/homelab for systemd installations
if [ -f "$SCRIPT_DIR/restic.env" ]; then
    . "$SCRIPT_DIR/restic.env"
elif [ -f "/etc/homelab/restic.env" ]; then
    . "/etc/homelab/restic.env"
else
    echo "ERROR: restic.env not found in $SCRIPT_DIR or /etc/homelab. Copy restic.env.example and create secure values."
    exit 2
fi

if [ -z "${RESTIC_REPOSITORY:-}" ]; then
    echo "ERROR: RESTIC_REPOSITORY not set in restic.env"
    exit 2
fi
if [ -z "${RESTIC_PASSWORD_FILE:-}" ] && [ -z "${RESTIC_PASSWORD:-}" ]; then
    echo "ERROR: RESTIC_PASSWORD_FILE or RESTIC_PASSWORD must be set"
    exit 2
fi

echo "Backup starting for host=$HOSTNAME timestamp=$TS"
if command -v docker >/dev/null 2>&1; then
    RUNNING_CONTAINERS="$(docker ps -q || true)"
    if [ -n "$RUNNING_CONTAINERS" ]; then
        for c in $RUNNING_CONTAINERS; do
            STATUS="$(docker inspect --format='{{.State.Status}}' "$c" 2>/dev/null || true)"
            if [ "$STATUS" = "running" ]; then
                docker pause "$c" && PAUSED_CONTAINERS="$PAUSED_CONTAINERS $c" || true
            fi
        done
    fi
fi

{
    echo "host: $HOSTNAME"
    echo "timestamp: $TS"
    echo "paths: /etc, /var/lib/docker/volumes, $REPO_ROOT"
} > "$MANIFEST_FILE"

ETC_ARCH="$TMPDIR/etc.$TS.tar.zst"
if [ -d /etc ]; then
    (cd / && tar -cpf - etc) | zstd -T0 -q -o "$ETC_ARCH"
    echo "/etc -> $(basename "$ETC_ARCH")" >> "$MANIFEST_FILE"
fi

REPO_ARCH="$TMPDIR/homelab-repo.$TS.tar.zst"
if [ -d "$REPO_ROOT" ]; then
    (cd "$REPO_ROOT" && tar --exclude='.git/objects' -cpf - .) | zstd -T0 -q -o "$REPO_ARCH"
    echo "$REPO_ROOT -> $(basename "$REPO_ARCH")" >> "$MANIFEST_FILE"
fi

VOLUME_DIR="/var/lib/docker/volumes"
if command -v docker >/dev/null 2>&1; then
    for v in $(docker volume ls -q 2>/dev/null || true); do
        MOUNTPOINT="$(docker volume inspect -f '{{.Mountpoint}}' "$v" 2>/dev/null || true)"
        if [ -n "$MOUNTPOINT" ] && [ -d "$MOUNTPOINT" ]; then
            OUT="$TMPDIR/vol_${v}.tar.zst"
            (cd "$MOUNTPOINT" && tar -cpf - .) | zstd -T0 -q -o "$OUT" || true
            echo "volume:$v -> $(basename "$OUT")" >> "$MANIFEST_FILE"
        fi
    done
elif [ -d "$VOLUME_DIR" ]; then
    for d in "$VOLUME_DIR"/*/; do
        [ -d "$d" ] || continue
        name="$(basename "$d")"
        DATA_DIR="$d/_data"
        if [ -d "$DATA_DIR" ]; then
            OUT="$TMPDIR/vol_${name}.tar.zst"
            (cd "$DATA_DIR" && tar -cpf - .) | zstd -T0 -q -o "$OUT" || true
            echo "volume:$name -> $(basename "$OUT")" >> "$MANIFEST_FILE"
        fi
    done
fi

(cd "$TMPDIR" && sha256sum ./* 2>/dev/null) > "$CHECKSUM_FILE" || true

RESTIC_ARGS=()
if [ -f "$SCRIPT_DIR/excludes.txt" ]; then
    RESTIC_ARGS+=(--exclude-file "$SCRIPT_DIR/excludes.txt")
fi

if [ "${DRY_RUN:-0}" = "1" ] || [ "${DRY_RUN:-false}" = "true" ]; then
    echo "DRY_RUN set: skipping restic backup. Would run: restic backup $TMPDIR /etc $VOLUME_DIR $REPO_ROOT ${RESTIC_ARGS[*]}"
    RESTIC_EXIT=0
else
    restic backup "$TMPDIR" /etc "$VOLUME_DIR" "$REPO_ROOT" "${RESTIC_ARGS[@]}" > "$RESTIC_LOG" 2>&1 || RESTIC_EXIT=$?
    RESTIC_EXIT=${RESTIC_EXIT:-0}
fi

if [ "${DRY_RUN:-0}" != "1" ] && [ "${DRY_RUN:-false}" != "true" ]; then
    restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune >> "$RESTIC_LOG" 2>&1 || true
fi

if mkdir -p "$DEST_DIR" 2>/dev/null; then
    cp -a "$MANIFEST_FILE" "$CHECKSUM_FILE" "$RESTIC_LOG" "$DEST_DIR/" 2>/dev/null || true
    chmod 0640 "$DEST_DIR/"* || true
fi

exit ${RESTIC_EXIT:-0}
