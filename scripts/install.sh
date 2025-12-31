#!/usr/bin/env bash
set -e

# Install all scripts in the scripts/ directory to /usr/local/bin/
for script in "$PWD"/scripts/*.sh; do
    if [[ "$(basename "$script")" != "install.sh" ]]; then
        name=$(basename "$script" .sh)
        echo "Installing $script to /usr/local/bin/$name ..."
        sudo cp "$script" "/usr/local/bin/$name"
        sudo chmod +x "/usr/local/bin/$name"
    fi
done

echo "Done."


