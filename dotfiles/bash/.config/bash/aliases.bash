#!/usr/bin/env bash
#
# Shell Aliases
# Managed by GNU Stow from /opt/Homelab/dotfiles
#

# =============================================================================
# NAVIGATION
# =============================================================================

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias -- -='cd -'

# =============================================================================
# LS VARIANTS
# =============================================================================

# Use exa/eza if available, fallback to ls
if command -v eza &>/dev/null; then
    alias ls='eza --color=auto --group-directories-first'
    alias l='eza -lF --color=auto --group-directories-first'
    alias ll='eza -laF --color=auto --group-directories-first'
    alias la='eza -a --color=auto --group-directories-first'
    alias lt='eza --tree --level=2 --color=auto'
    alias lh='eza -lah --sort=modified --color=auto'
elif command -v exa &>/dev/null; then
    alias ls='exa --color=auto --group-directories-first'
    alias l='exa -lF --color=auto --group-directories-first'
    alias ll='exa -laF --color=auto --group-directories-first'
    alias la='exa -a --color=auto --group-directories-first'
    alias lt='exa --tree --level=2 --color=auto'
    alias lh='exa -lah --sort=modified --color=auto'
else
    alias ls='ls --color=auto'
    alias l='ls -lF --color=auto'
    alias ll='ls -laF --color=auto'
    alias la='ls -A --color=auto'
    alias lt='tree -L 2 -C'
    alias lh='ls -lath --color=auto'
fi

# =============================================================================
# FILE OPERATIONS (safe defaults)
# =============================================================================

alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -Iv'
alias mkdir='mkdir -pv'
alias ln='ln -iv'

# =============================================================================
# SYSTEM INFORMATION
# =============================================================================

alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ps='ps auxf'
alias top='btop 2>/dev/null || htop 2>/dev/null || top'
alias mem='free -h && echo && ps aux | head -1 && ps aux | sort -rnk 4 | head -5'
alias cpu='ps aux | head -1 && ps aux | sort -rnk 3 | head -5'

# =============================================================================
# NETWORK
# =============================================================================

myip() {
    hostname -I | awk '{print $1}'
    echo -n 'External: '
    curl -s ifconfig.me
    echo
}
alias ports='ss -tulanp'
# listening is a function in system.bash

# =============================================================================
# PACKAGE MANAGEMENT (Debian/Ubuntu)
# =============================================================================

if command -v apt &>/dev/null; then
    alias install='sudo apt install'
    alias search='apt search'
    alias update='sudo apt update'
    alias upgrade='sudo apt update && sudo apt upgrade -y'
    alias remove='sudo apt remove'
    alias uplist='apt list --upgradable'
    alias autoremove='sudo apt autoremove --purge -y'
fi

# =============================================================================
# GIT
# =============================================================================

alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit'
alias gcm='git commit -m'
alias gp='git push'
alias gpu='git push -u origin $(git branch --show-current)'
alias gpl='git pull'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gb='git branch -v'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -20'
alias gla='git log --oneline --graph --decorate --all'
alias gclone='git clone'
alias gstash='git stash'
alias gpop='git stash pop'

# =============================================================================
# EDITORS AND CONFIG
# =============================================================================

alias vi='vim'
alias vv='vim .'
alias e='${EDITOR}'

# Config quick access
alias bashrc='${EDITOR} ~/.config/bash/bashrc'
alias reload='source ~/.bashrc && echo "Reloaded .bashrc"'
alias vimrc='${EDITOR} ~/.vimrc'
alias dotfiles='cd /opt/Homelab/dotfiles'

# =============================================================================
# UTILITIES
# =============================================================================

alias c='clear'
alias h='history'
alias j='jobs -l'
alias which='type -a'
alias now='date +"%Y-%m-%d %T"'
alias week='date +%V'
alias path='echo -e ${PATH//:/\\n}'

# Grep with color
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Disk usage
alias biggest='du -h --max-depth=1 2>/dev/null | sort -h'
alias ducks='du -cks * 2>/dev/null | sort -rn | head'

# Process management
alias k9='kill -9'

# Archive extraction (see functions/utils.bash for extract function)
alias untar='tar -xvf'
alias ungz='tar -xzvf'
alias unbz2='tar -xjvf'

# =============================================================================
# SYSTEMD
# =============================================================================

if command -v systemctl &>/dev/null; then
    alias sc='systemctl'
    alias scs='systemctl status'
    alias scr='sudo systemctl restart'
    alias sce='sudo systemctl enable'
    alias scd='sudo systemctl disable'
    alias scstart='sudo systemctl start'
    alias scstop='sudo systemctl stop'
    alias jctl='journalctl -xe'
    alias jctlf='journalctl -f'
fi

# =============================================================================
# DOCKER
# =============================================================================

if command -v docker &>/dev/null; then
    alias d='docker'
    alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
    alias dpsa='docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
    alias di='docker images'
    alias dex='docker exec -it'
    alias dlogs='docker logs -f'
    alias dprune='docker system prune -af'
    alias dc='docker compose'
    alias dcu='docker compose up -d'
    alias dcd='docker compose down'
    alias dcr='docker compose restart'
    alias dcl='docker compose logs -f'
fi

# =============================================================================
# SAFETY NETS
# =============================================================================

# Prevent overwriting files accidentally
alias cp='cp -i'
alias mv='mv -i'

# Prevent accidental shutdowns on servers
alias shutdown='echo "Use: sudo shutdown -h now"'
alias reboot='echo "Use: sudo reboot"'
