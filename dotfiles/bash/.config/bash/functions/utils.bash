#!/usr/bin/env bash
#
# Utility Functions
# Managed by GNU Stow from /opt/Homelab/dotfiles
#

# =============================================================================
# DIRECTORY OPERATIONS
# =============================================================================

# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1" || return 1
}

# Create directory with date
mkdated() {
    local dirname="${1:-backup}"
    local dated_dir="${dirname}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "${dated_dir}" && cd "${dated_dir}" || return 1
    echo "Created: ${dated_dir}"
}

# Backup a file with timestamp
bak() {
    if [[ -z "$1" ]]; then
        echo "Usage: bak <file>"
        return 1
    fi
    cp -v "$1" "$1.bak.$(date +%Y%m%d_%H%M%S)"
}

# =============================================================================
# ARCHIVE OPERATIONS
# =============================================================================

# Universal archive extractor
extract() {
    if [[ -z "$1" ]]; then
        echo "Usage: extract <archive_file>"
        return 1
    fi
    
    if [[ ! -f "$1" ]]; then
        echo "Error: '$1' is not a valid file"
        return 1
    fi
    
    case "$1" in
        *.tar.bz2)   tar xjf "$1"     ;;
        *.tar.gz)    tar xzf "$1"     ;;
        *.tar.xz)    tar xJf "$1"     ;;
        *.tar.zst)   tar --zstd -xf "$1" ;;
        *.bz2)       bunzip2 "$1"     ;;
        *.rar)       unrar x "$1"     ;;
        *.gz)        gunzip "$1"      ;;
        *.tar)       tar xf "$1"      ;;
        *.tbz2)      tar xjf "$1"     ;;
        *.tgz)       tar xzf "$1"     ;;
        *.zip)       unzip "$1"       ;;
        *.Z)         uncompress "$1"  ;;
        *.7z)        7z x "$1"        ;;
        *.deb)       ar x "$1"        ;;
        *.xz)        unxz "$1"        ;;
        *.zst)       unzstd "$1"      ;;
        *)           echo "'$1' cannot be extracted via extract()" ;;
    esac
}

# Create a compressed tarball
mktar() {
    if [[ -z "$1" ]]; then
        echo "Usage: mktar <directory> [archive_name]"
        return 1
    fi
    
    local source="$1"
    local name="${2:-$(basename "$1")}"
    
    tar -czvf "${name}.tar.gz" "${source}"
    echo "Created: ${name}.tar.gz"
}

# =============================================================================
# TEXT AND SEARCH
# =============================================================================

# Search history
hgrep() {
    if [[ -z "$1" ]]; then
        echo "Usage: hgrep <pattern>"
        return 1
    fi
    history | grep -i --color=auto "$1"
}

# Find files by name
ff() {
    if [[ -z "$1" ]]; then
        echo "Usage: ff <filename_pattern>"
        return 1
    fi
    find . -type f -iname "*$1*" 2>/dev/null
}

# Find directories by name
fd() {
    if [[ -z "$1" ]]; then
        echo "Usage: fd <dirname_pattern>"
        return 1
    fi
    find . -type d -iname "*$1*" 2>/dev/null
}

# Grep recursively in files
rgrep() {
    if [[ -z "$1" ]]; then
        echo "Usage: rgrep <pattern> [path]"
        return 1
    fi
    grep -rn --color=auto "$1" "${2:-.}"
}

# =============================================================================
# FILE INFORMATION
# =============================================================================

# Get size of directory
dirsize() {
    du -sh "${1:-.}" 2>/dev/null | awk '{print $1}'
}

# Show directory tree with size
tresize() {
    local depth="${1:-2}"
    du -h --max-depth="${depth}" 2>/dev/null | sort -h
}

# Show PATH in readable format
showpath() {
    echo "${PATH}" | tr ':' '\n' | nl
}

# Count files in directory
countfiles() {
    find "${1:-.}" -type f 2>/dev/null | wc -l
}

# =============================================================================
# QUICK SERVERS
# =============================================================================

# Start a simple HTTP server
serve() {
    local port="${1:-8000}"
    local ip
    ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
    
    echo "Starting HTTP server at http://${ip}:${port}"
    echo "Press Ctrl+C to stop"
    
    if command -v python3 &>/dev/null; then
        python3 -m http.server "${port}"
    elif command -v python &>/dev/null; then
        python -m SimpleHTTPServer "${port}"
    else
        echo "Python not found"
        return 1
    fi
}

# =============================================================================
# GIT HELPERS
# =============================================================================

# Git commit with message
gcmsg() {
    if [[ -z "$1" ]]; then
        echo "Usage: gcmsg <commit_message>"
        return 1
    fi
    git add -A && git commit -m "$1"
}

# Git add, commit, and push
gacp() {
    if [[ -z "$1" ]]; then
        echo "Usage: gacp <commit_message>"
        return 1
    fi
    git add -A && git commit -m "$1" && git push
}

# Git status short
gss() {
    git status -sb
}

# =============================================================================
# MISC UTILITIES
# =============================================================================

# Generate random password
genpass() {
    local length="${1:-32}"
    < /dev/urandom tr -dc 'A-Za-z0-9!@#$%^&*' | head -c "${length}"
    echo ""
}

# Generate random alphanumeric string
genalnum() {
    local length="${1:-32}"
    < /dev/urandom tr -dc 'A-Za-z0-9' | head -c "${length}"
    echo ""
}

# Weather
weather() {
    local location="${1:-}"
    curl -s "wttr.in/${location}?format=3"
}

# Calculator
calc() {
    if [[ -z "$1" ]]; then
        echo "Usage: calc <expression>"
        return 1
    fi
    echo "scale=4; $*" | bc -l
}

# URL encode
urlencode() {
    python3 -c "import urllib.parse; print(urllib.parse.quote('$1'))"
}

# URL decode
urldecode() {
    python3 -c "import urllib.parse; print(urllib.parse.unquote('$1'))"
}
