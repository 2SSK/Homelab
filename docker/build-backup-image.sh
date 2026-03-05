#!/usr/bin/env bash
# Helper to build the backup docker image and tag it for local use
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DOCKERFILE="$ROOT/docker/backup-image/Dockerfile"
TAG="homelab/backup-image:local"

if [ ! -f "$DOCKERFILE" ]; then
    echo "ERROR: Dockerfile not found at $DOCKERFILE"
    exit 2
fi

echo "Building Docker image from $DOCKERFILE..."
docker build -f "$DOCKERFILE" -t "$TAG" "$ROOT/docker/backup-image"

echo "Build complete: $TAG"
echo "Next steps:"
echo "  - To run the image interactively: docker run --rm -it $TAG /bin/sh"
echo "  - Use this image as a lightweight environment for archiving and restic operations in CI or local testing."
echo "  - Do NOT run backup jobs in containers with restic credentials baked into images. Keep secrets out of images."

exit 0
