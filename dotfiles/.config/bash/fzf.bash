#!/usr/bin/env bash

# Exit if fzf not installed
command -v fzf >/dev/null 2>&1 || return 0

# Default FZF options
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --info=inline --bind=ctrl-d:half-page-down,ctrl-u:half-page-up'

# Fuzzy cd into a directory
fcd() {
    local dir
    dir=$(find "${1:-.}" -type d 2>/dev/null | fzf +m --prompt="cd> ")
    [[ -n "$dir" ]] && cd "$dir"
}

# Fuzzy search command history
fhist() {
    local cmd
    cmd=$(history | fzf --tac --prompt="Hist> " | sed 's/ *[0-9]* *//')
    [[ -n "$cmd" ]] && eval "$cmd"
}

# Fuzzy kill process
fkill() {
    local pid
    pid=$(ps -ef | sed 1d | fzf -m --prompt="Kill> " | awk '{print $2}')
    [[ -n "$pid" ]] && kill -9 $pid
}

# Alias for fcd
fd() { fcd "$1"; }

# Fuzzy find file
ffind() {
    local file
    file=$(find "${1:-.}" -type f 2>/dev/null | fzf --prompt="Find> ")
    [[ -n "$file" ]] && echo "$file"
}

# Print fzf version
fzf_version() { fzf --version; }
