#!/usr/bin/env bash
#
# ~/.bashrc - Bash Startup File
# Managed by GNU Stow from /opt/Homelab/dotfiles
#
# This is the minimal bootstrap file that sources the main configuration.
# The actual configuration lives in ~/.config/bash/
#

# Source the main bashrc configuration
if [[ -f "${HOME}/.config/bash/bashrc" ]]; then
    source "${HOME}/.config/bash/bashrc"
fi
