#!/usr/bin/env bash
#
# Server Utility Functions
#

# =============================================================================
# DIRECTORY OPERATIONS
# =============================================================================

mkcd() { mkdir -p "$1" && cd "$1" || return 1; }

bak() {
    [[ -z "$1" ]] && { echo "Usage: bak <file>"; return 1; }
    cp -v "$1" "$1.bak.$(date +%Y%m%d_%H%M%S)"
}

# =============================================================================
# ARCHIVE OPERATIONS
# =============================================================================

extract() {
    [[ -z "$1" ]] && { echo "Usage: extract <file>"; return 1; }
    [[ ! -f "$1" ]] && { echo "Error: '$1' not found"; return 1; }
    
    case "$1" in
        *.tar.bz2|*.tbz2) tar xjf "$1" ;;
        *.tar.gz|*.tgz)   tar xzf "$1" ;;
        *.tar.xz)         tar xJf "$1" ;;
        *.tar)            tar xf "$1"  ;;
        *.gz)             gunzip "$1"  ;;
        *.bz2)            bunzip2 "$1" ;;
        *.xz)             unxz "$1"    ;;
        *.zip)            unzip "$1"   ;;
        *.7z)             7z x "$1"    ;;
        *)                echo "Unknown format: $1" ;;
    esac
}

mktar() {
    [[ -z "$1" ]] && { echo "Usage: mktar <dir> [name]"; return 1; }
    tar -czvf "${2:-$(basename "$1")}.tar.gz" "$1"
}

# =============================================================================
# SEARCH
# =============================================================================

hgrep() { history | grep -i --color=auto "$1"; }
ff() { find . -type f -iname "*$1*" 2>/dev/null; }
rgrep() { grep -rn --color=auto "$1" "${2:-.}"; }

# =============================================================================
# FILE INFO
# =============================================================================

dirsize() { du -sh "${1:-.}" 2>/dev/null | awk '{print $1}'; }
countfiles() { find "${1:-.}" -type f 2>/dev/null | wc -l; }

# =============================================================================
# GIT
# =============================================================================

gcmsg() {
    [[ -z "$1" ]] && { echo "Usage: gcmsg <message>"; return 1; }
    git add -A && git commit -m "$1"
}

gacp() {
    [[ -z "$1" ]] && { echo "Usage: gacp <message>"; return 1; }
    git add -A && git commit -m "$1" && git push
}

# =============================================================================
# UTILITIES
# =============================================================================

genpass() {
    tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c "${1:-32}"
    echo
}

genalnum() {
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "${1:-32}"
    echo
}

calc() { echo "scale=4; $*" | bc -l; }
