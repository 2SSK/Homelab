#!/usr/bin/env bash

# Vi mode
set -o vi
bind -m vi-insert '"jk": vi-movement-mode'

# History search with arrows
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# Ctrl+L to clear screen (vi mode)
bind -m vi-insert '"\C-l": clear-screen'
bind -m vi-command '"\C-l": clear-screen'

# Tab completion
bind 'set show-all-if-ambiguous on'
bind 'set completion-ignore-case on'
