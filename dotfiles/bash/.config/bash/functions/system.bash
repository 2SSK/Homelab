#!/usr/bin/env bash
#
# System Functions
# Managed by GNU Stow from /opt/Homelab/dotfiles
#

# =============================================================================
# UTILITY HELPERS
# =============================================================================

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check if running as root
is_root() {
    [[ ${EUID} -eq 0 ]]
}

# =============================================================================
# SYSTEM INFORMATION
# =============================================================================

# Comprehensive system info
sysinfo() {
    echo "═══════════════════════════════════════════════════════════"
    echo "                    SYSTEM INFORMATION"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Hostname:    $(hostname -f 2>/dev/null || hostname)"
    echo "  Kernel:      $(uname -r)"
    echo "  OS:          $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')"
    echo "  Uptime:      $(uptime -p 2>/dev/null || uptime)"
    echo ""
    echo "  CPU:         $(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs)"
    echo "  Cores:       $(nproc)"
    echo "  Load:        $(uptime | awk -F'load average:' '{print $2}' | xargs)"
    echo ""
    echo "  Memory:      $(free -h | awk '/^Mem:/ {print $3 " / " $2}')"
    echo "  Swap:        $(free -h | awk '/^Swap:/ {print $3 " / " $2}')"
    echo ""
    echo "  Disk (/):    $(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 " used)"}')"
    echo ""
    
    if [[ -n "${SSH_CONNECTION}" ]]; then
        echo "  SSH From:    $(echo "${SSH_CONNECTION}" | awk '{print $1}')"
    fi
    
    if command_exists ip; then
        echo "  IP (local):  $(ip -4 addr show scope global | grep inet | head -1 | awk '{print $2}' | cut -d/ -f1)"
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
}

# Quick status
status() {
    echo "Load: $(uptime | awk -F'load average:' '{print $2}' | xargs)"
    echo "Mem:  $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
    echo "Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2}')"
}

# =============================================================================
# PROCESS MANAGEMENT
# =============================================================================

# Process grep with header
psg() {
    if [[ -z "$1" ]]; then
        echo "Usage: psg <process_name>"
        return 1
    fi
    ps aux | head -1
    ps aux | grep -v "grep" | grep -i --color=auto "$1"
}

# Kill process by name
killbyname() {
    if [[ -z "$1" ]]; then
        echo "Usage: killbyname <process_name>"
        return 1
    fi
    
    local pids
    pids=$(pgrep -f "$1")
    
    if [[ -z "${pids}" ]]; then
        echo "No processes found matching: $1"
        return 1
    fi
    
    echo "Found processes:"
    ps aux | grep -v grep | grep -i "$1"
    echo ""
    read -rp "Kill these processes? [y/N] " confirm
    
    if [[ "${confirm}" =~ ^[Yy]$ ]]; then
        pkill -f "$1"
        echo "Processes killed."
    fi
}

# Top memory consumers
topmem() {
    local count="${1:-10}"
    echo "Top ${count} memory consumers:"
    ps aux | head -1
    ps aux --sort=-%mem | head -n $((count + 1)) | tail -n "${count}"
}

# Top CPU consumers
topcpu() {
    local count="${1:-10}"
    echo "Top ${count} CPU consumers:"
    ps aux | head -1
    ps aux --sort=-%cpu | head -n $((count + 1)) | tail -n "${count}"
}

# =============================================================================
# NETWORK UTILITIES
# =============================================================================

# Show listening ports
listening() {
    echo "Listening ports:"
    ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null
}

# Check if port is in use
portcheck() {
    if [[ -z "$1" ]]; then
        echo "Usage: portcheck <port>"
        return 1
    fi
    ss -tlnp | grep ":$1 " || echo "Port $1 is not in use"
}

# Get external IP
extip() {
    curl -s ifconfig.me && echo ""
}

# Quick ping test
pingtest() {
    local hosts=("1.1.1.1" "8.8.8.8" "google.com")
    
    for host in "${hosts[@]}"; do
        if ping -c 1 -W 2 "${host}" &>/dev/null; then
            echo "✓ ${host} - reachable"
        else
            echo "✗ ${host} - unreachable"
        fi
    done
}

# =============================================================================
# SERVICE MANAGEMENT
# =============================================================================

# Restart service with status check
srestart() {
    if [[ -z "$1" ]]; then
        echo "Usage: srestart <service_name>"
        return 1
    fi
    
    echo "Restarting $1..."
    sudo systemctl restart "$1"
    sleep 1
    systemctl status "$1" --no-pager
}

# Check service logs
slogs() {
    if [[ -z "$1" ]]; then
        echo "Usage: slogs <service_name> [lines]"
        return 1
    fi
    
    local lines="${2:-50}"
    journalctl -u "$1" -n "${lines}" --no-pager
}

# Follow service logs
slogf() {
    if [[ -z "$1" ]]; then
        echo "Usage: slogf <service_name>"
        return 1
    fi
    
    journalctl -u "$1" -f
}
