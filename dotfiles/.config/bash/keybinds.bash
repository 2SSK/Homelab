#!/usr/bin/env bash

# Only set keybindings in interactive shells
if [[ $- == *i* ]]; then
  # Ctrl+L to clear screen
  bind '"\C-l":clear-screen'

  # Up/Down arrow for history search
  bind '"\e[A": history-search-backward'
  bind '"\e[B": history-search-forward'
  
  # Vi mode
  set -o vi
  bind '"jk": vi-movement-mode'
fi
