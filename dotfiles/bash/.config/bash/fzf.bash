#!/usr/bin/env bash
#
# FZF Configuration and Functions
# Managed by GNU Stow from /opt/Homelab/dotfiles
#

# =============================================================================
# EARLY EXIT IF FZF NOT INSTALLED
# =============================================================================

command -v fzf &>/dev/null || return 0

# =============================================================================
# SOURCE SYSTEM FZF FILES
# =============================================================================

# Debian/Ubuntu paths
[[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]] && \
    source /usr/share/doc/fzf/examples/key-bindings.bash

[[ -f /usr/share/doc/fzf/examples/completion.bash ]] && \
    source /usr/share/doc/fzf/examples/completion.bash

# Arch Linux paths
[[ -f /usr/share/fzf/key-bindings.bash ]] && \
    source /usr/share/fzf/key-bindings.bash

[[ -f /usr/share/fzf/completion.bash ]] && \
    source /usr/share/fzf/completion.bash

# =============================================================================
# FZF DEFAULT OPTIONS
# =============================================================================

export FZF_DEFAULT_OPTS='
    --height=40%
    --layout=reverse
    --border=rounded
    --info=inline
    --margin=1
    --padding=1
    --bind=ctrl-d:half-page-down
    --bind=ctrl-u:half-page-up
    --bind=ctrl-a:select-all
    --bind=ctrl-y:execute-silent(echo {+} | xclip -selection clipboard 2>/dev/null || pbcopy 2>/dev/null)
    --color=fg:#c0caf5,bg:#1a1b26,hl:#bb9af7
    --color=fg+:#c0caf5,bg+:#292e42,hl+:#7dcfff
    --color=info:#7aa2f7,prompt:#7dcfff,pointer:#7dcfff
    --color=marker:#9ece6a,spinner:#9ece6a,header:#9ece6a
'

# Use fd or find for file listing
if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
else
    export FZF_DEFAULT_COMMAND='find . -type f -not -path "*/\.git/*"'
    export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
    export FZF_ALT_C_COMMAND='find . -type d -not -path "*/\.git/*"'
fi

# Preview for files (use bat if available)
if command -v bat &>/dev/null; then
    export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :300 {}' --preview-window=right:60%:wrap"
else
    export FZF_CTRL_T_OPTS="--preview 'head -300 {}' --preview-window=right:60%:wrap"
fi

export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -100'"

# =============================================================================
# FZF FUNCTIONS
# =============================================================================

# Fuzzy cd into directory
fcd() {
    local dir
    dir=$(find "${1:-.}" -type d 2>/dev/null | fzf --prompt="cd> " +m) || return
    cd "${dir}" || return
}

# Fuzzy file finder with editor
fe() {
    local file
    file=$(fzf --prompt="Edit> " -m \
        --preview 'bat --style=numbers --color=always {} 2>/dev/null || cat {}' \
        --preview-window=right:60%:wrap) || return
    
    if [[ -n "${file}" ]]; then
        ${EDITOR:-vim} "${file}"
    fi
}

# Fuzzy history search and execute
fh() {
    local cmd
    cmd=$(history | tac | awk '!seen[$0]++' | fzf --prompt="History> " +s --tac | \
        sed 's/^[ ]*[0-9]*[ ]*//')
    
    if [[ -n "${cmd}" ]]; then
        echo "Executing: ${cmd}"
        eval "${cmd}"
    fi
}

# Fuzzy kill process
fkill() {
    local pid
    pid=$(ps -ef | sed 1d | fzf --prompt="Kill> " -m | awk '{print $2}')
    
    if [[ -n "${pid}" ]]; then
        echo "Killing PID: ${pid}"
        echo "${pid}" | xargs kill -9
    fi
}

# Fuzzy git checkout branch
fco() {
    local branch
    branch=$(git branch -a | grep -v HEAD | sed 's/.* //' | sed 's#remotes/origin/##' | \
        sort -u | fzf --prompt="Checkout> ")
    
    if [[ -n "${branch}" ]]; then
        git checkout "${branch}"
    fi
}

# Fuzzy git log browser
fgl() {
    git log --oneline --graph --color=always | \
        fzf --ansi --no-sort --reverse --prompt="Git Log> " \
            --preview 'git show --color=always $(echo {} | grep -o "[a-f0-9]\{7,\}" | head -1)' \
            --preview-window=right:60%:wrap \
            --bind 'enter:execute(git show --color=always $(echo {} | grep -o "[a-f0-9]\{7,\}" | head -1) | less -R)'
}

# Fuzzy git stash browser
fstash() {
    local stash
    stash=$(git stash list | fzf --prompt="Stash> " --no-sort --reverse | cut -d: -f1)
    
    if [[ -n "${stash}" ]]; then
        git stash show -p "${stash}"
    fi
}

# Fuzzy SSH host selector (from ~/.ssh/config)
fssh() {
    local host
    host=$(grep "^Host " ~/.ssh/config 2>/dev/null | \
        grep -v "[*?]" | awk '{print $2}' | \
        fzf --prompt="SSH> ")
    
    if [[ -n "${host}" ]]; then
        ssh "${host}"
    fi
}

# Fuzzy environment variable browser
fenv() {
    env | fzf --prompt="Env> " --preview 'echo {} | cut -d= -f2-'
}

# Fuzzy man page search
fman() {
    local page
    page=$(man -k . 2>/dev/null | fzf --prompt="Man> " | awk '{print $1}' | sed 's/(.*//') || return
    
    if [[ -n "${page}" ]]; then
        man "${page}"
    fi
}

# Fuzzy docker container exec
fdex() {
    local container
    container=$(docker ps --format '{{.Names}}' 2>/dev/null | fzf --prompt="Container> ") || return
    
    if [[ -n "${container}" ]]; then
        docker exec -it "${container}" "${1:-/bin/bash}"
    fi
}

# Fuzzy docker logs
fdlogs() {
    local container
    container=$(docker ps -a --format '{{.Names}}' 2>/dev/null | fzf --prompt="Logs> ") || return
    
    if [[ -n "${container}" ]]; then
        docker logs -f "${container}"
    fi
}

# Fuzzy systemd unit browser
fsc() {
    local unit
    unit=$(systemctl list-units --all --no-pager | sed 1d | \
        fzf --prompt="Systemd> " | awk '{print $1}') || return
    
    if [[ -n "${unit}" ]]; then
        systemctl status "${unit}"
    fi
}
