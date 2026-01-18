#!/usr/bin/env bash
#
# Bash Prompt Configuration
# Managed by GNU Stow from /opt/Homelab/dotfiles
#

# =============================================================================
# COLOR DEFINITIONS
# =============================================================================

# Standard colors with prompt escape sequences
readonly PROMPT_RED="\[\e[1;31m\]"
readonly PROMPT_GREEN="\[\e[1;32m\]"
readonly PROMPT_YELLOW="\[\e[1;33m\]"
readonly PROMPT_BLUE="\[\e[1;34m\]"
readonly PROMPT_MAGENTA="\[\e[1;35m\]"
readonly PROMPT_CYAN="\[\e[1;36m\]"
readonly PROMPT_WHITE="\[\e[1;37m\]"
readonly PROMPT_GRAY="\[\e[1;90m\]"
readonly PROMPT_RESET="\[\e[0m\]"

# =============================================================================
# GIT PROMPT FUNCTIONS
# =============================================================================

__git_branch() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    [[ -n "${branch}" ]] && echo "${branch}"
}

__git_status() {
    # Quick check if we're in a git repo
    git rev-parse --git-dir &>/dev/null || return
    
    local branch
    branch=$(__git_branch)
    [[ -z "${branch}" ]] && return
    
    local status_output
    status_output=$(git status --porcelain 2>/dev/null)
    
    local staged=0 modified=0 untracked=0
    while IFS= read -r line; do
        [[ -z "${line}" ]] && continue
        case "${line:0:2}" in
            "??") ((untracked++)) ;;
            "A "| "M "| "D "| "R "| "C ") ((staged++)) ;;
            " M"| " D") ((modified++)) ;;
            "MM"| "AM"| "AD") ((staged++)); ((modified++)) ;;
        esac
    done <<< "${status_output}"
    
    local indicators=""
    [[ ${staged} -gt 0 ]] && indicators+="+"
    [[ ${modified} -gt 0 ]] && indicators+="!"
    [[ ${untracked} -gt 0 ]] && indicators+="?"
    
    if [[ -z "${indicators}" ]]; then
        echo " (${branch} ✓)"
    else
        echo " (${branch} ${indicators})"
    fi
}

# =============================================================================
# ENVIRONMENT INDICATORS
# =============================================================================

__ssh_indicator() {
    [[ -n "${SSH_CONNECTION}" ]] && echo "${PROMPT_RED}[ssh]${PROMPT_RESET}"
}

__virtualenv_indicator() {
    [[ -n "${VIRTUAL_ENV}" ]] && echo "${PROMPT_MAGENTA}($(basename "${VIRTUAL_ENV}"))${PROMPT_RESET} "
}

__exit_code_indicator() {
    local exit_code=$?
    [[ ${exit_code} -ne 0 ]] && echo "${PROMPT_RED}[${exit_code}]${PROMPT_RESET} "
}

# =============================================================================
# PROMPT CONFIGURATION
# =============================================================================

__set_prompt() {
    local exit_code=$?
    
    # Start with newline for visual separation
    PS1="\n"
    
    # Exit code if non-zero
    [[ ${exit_code} -ne 0 ]] && PS1+="${PROMPT_RED}[${exit_code}]${PROMPT_RESET} "
    
    # Python virtualenv
    [[ -n "${VIRTUAL_ENV}" ]] && PS1+="${PROMPT_MAGENTA}($(basename "${VIRTUAL_ENV}"))${PROMPT_RESET} "
    
    # User (green for normal, red for root)
    if [[ ${EUID} -eq 0 ]]; then
        PS1+="${PROMPT_RED}\u${PROMPT_RESET}"
    else
        PS1+="${PROMPT_GREEN}\u${PROMPT_RESET}"
    fi
    
    # SSH indicator
    [[ -n "${SSH_CONNECTION}" ]] && PS1+="${PROMPT_RED}@ssh${PROMPT_RESET}"
    
    # Host
    PS1+=" ${PROMPT_WHITE}at${PROMPT_RESET} ${PROMPT_YELLOW}\h${PROMPT_RESET}"
    
    # Working directory
    PS1+=" ${PROMPT_WHITE}in${PROMPT_RESET} ${PROMPT_BLUE}\w${PROMPT_RESET}"
    
    # Git status
    PS1+="${PROMPT_CYAN}$(__git_status)${PROMPT_RESET}"
    
    # New line and prompt character
    PS1+="\n"
    
    # Prompt character (# for root, $ for user)
    if [[ ${EUID} -eq 0 ]]; then
        PS1+="${PROMPT_RED}#${PROMPT_RESET} "
    else
        PS1+="${PROMPT_CYAN}\$${PROMPT_RESET} "
    fi
}

# Set PROMPT_COMMAND to update PS1 before each command
PROMPT_COMMAND='__set_prompt'

# PS2 for multi-line commands
PS2="${PROMPT_CYAN}→${PROMPT_RESET} "

# PS4 for debugging (set -x)
PS4='+ ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
