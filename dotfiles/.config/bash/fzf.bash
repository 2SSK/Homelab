#!/usr/bin/env bash

# Exit if fzf not installed
command -v fzf >/dev/null 2>&1 || return 0

# Source system fzf keybindings and completion (from apt package)
if [[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]]; then
    source /usr/share/doc/fzf/examples/key-bindings.bash 2>/dev/null
fi

if [[ -f /usr/share/doc/fzf/examples/completion.bash ]]; then
    source /usr/share/doc/fzf/examples/completion.bash 2>/dev/null
fi

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

# Fuzzy file editor
fedit() {
    local files
    local editor="${EDITOR:-vim}"

    # Select one or more files
    files=$(fzf -m --preview 'bat --style=numbers --color=always {} 2>/dev/null || cat {}' --preview-window=right:50%:wrap --prompt="Edit> ")

    if [[ -n "$files" ]]; then
        # Handle multiple files (one per line)
        echo "$files" | while read -r file; do
            if [[ -n "$file" ]]; then
                $editor "$file"
            fi
        done
    fi
}

# Fuzzy man page search
fman() {
    local man_page
    man_page=$(man -k . | fzf --prompt='Man> ' | awk '{print $1}')

    if [[ -n "$man_page" ]]; then
        man "$man_page"
    fi
}

# Fuzzy SSH host selection
fssh() {
    local host
    host=$(grep "^Host " ~/.ssh/config 2>/dev/null | grep -v "*" | awk '{print $2}' | fzf --prompt="SSH> ")

    if [[ -n "$host" ]]; then
        ssh "$host"
    fi
}

# Fuzzy environment variable search
fenv() {
    local var
    var=$(env | fzf --height 40% --prompt="Env> " --preview 'echo {} | cut -d= -f2')

    if [[ -n "$var" ]]; then
        echo "$var" | cut -d= -f1 | tr -d '\n' | xclip -selection clipboard 2>/dev/null
        echo "Copied to clipboard: $(echo "$var" | cut -d= -f1)"
    fi
}

# Fuzzy grep with ripgrep
fzf_grep() {
    local pattern="${1:-}"
    local file

    if [[ -z "$pattern" ]]; then
        echo "Usage: fzf_grep <pattern>"
        return 1
    fi

    if command_exists rg; then
        file=$(rg --line-number --color=never --no-heading --smart-case "$pattern" 2>/dev/null |
               fzf --delimiter=: --nth=1..2 \
                   --preview 'bat --style=numbers --color=always {1} 2>/dev/null | grep -C 3 --color=always {2}' \
                   --preview-window=right:50%:wrap \
                   --prompt="Grep> " \
                   --bind="ctrl-o:execute($EDITOR +{2} {1})+abort")
        if [[ -n "$file" ]]; then
            local line=$(echo "$file" | cut -d: -f2)
            file=$(echo "$file" | cut -d: -f1)
            ${EDITOR:-vim} +"$line" "$file"
        fi
    else
        echo "ripgrep (rg) is required for fzf_grep"
        return 1
    fi
}

# Print fzf version
fzf_version() { fzf --version; }
