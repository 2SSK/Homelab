#!/usr/bin/env bash
#
# Dotfiles Bootstrap Phase
# Stows configuration files from /opt/Homelab/dotfiles
#
# Usage: source this file or run directly
# Dependencies: stow, git
#

set -euo pipefail

# =============================================================================
# SOURCE SHARED UTILITIES
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../libs/utils.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

# Support both /opt/Homelab (production) and script-relative path (development/bootstrap)
if [[ -d "/opt/Homelab/dotfiles" ]]; then
    DOTFILES_ROOT="/opt/Homelab/dotfiles"
else
    # Fallback to relative path from script location
    DOTFILES_ROOT="$(cd "${SCRIPT_DIR}/../../../dotfiles" && pwd)"
fi
readonly DOTFILES_ROOT

readonly STOW_TARGET="${HOME}"
readonly STOW_PACKAGES=(bash vim)
BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly BACKUP_DIR="${HOME}/.dotfiles_backup/${BACKUP_TIMESTAMP}"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

ensure_stow_installed() {
    if ! command_exists stow; then
        log_info "Installing GNU Stow..."
        if command_exists apt-get; then
            sudo apt-get update -qq && sudo apt-get install -y stow
        elif command_exists dnf; then
            sudo dnf install -y stow
        elif command_exists pacman; then
            sudo pacman -S --noconfirm stow
        else
            log_error "Cannot install stow: unknown package manager"
            return 1
        fi
    fi
    log_info "GNU Stow $(stow --version | head -1 | awk '{print $NF}') available"
}

ensure_dotfiles_exist() {
    if [[ ! -d "${DOTFILES_ROOT}" ]]; then
        log_error "Dotfiles directory not found: ${DOTFILES_ROOT}"
        log_info "Ensure /opt/Homelab is cloned and contains the dotfiles directory"
        return 1
    fi
    log_info "Dotfiles directory found: ${DOTFILES_ROOT}"
}

backup_existing_file() {
    local file="$1"
    
    if [[ -e "${file}" && ! -L "${file}" ]]; then
        log_warning "Backing up existing file: ${file}"
        mkdir -p "${BACKUP_DIR}"
        local relative_path="${file#"${HOME}"/}"
        local backup_path="${BACKUP_DIR}/${relative_path}"
        mkdir -p "$(dirname "${backup_path}")"
        mv "${file}" "${backup_path}"
        log_info "Backed up to: ${backup_path}"
    elif [[ -L "${file}" ]]; then
        rm -f "${file}"
    fi
}

# =============================================================================
# STOW OPERATIONS
# =============================================================================

prestow_cleanup() {
    local package="$1"
    local package_dir="${DOTFILES_ROOT}/${package}"
    
    log_info "Pre-stow cleanup for package: ${package}"
    
    # Find all files in the stow package and backup conflicting files
    while IFS= read -r -d '' file; do
        # Get relative path from package directory
        local relative_path="${file#"${package_dir}"/}"
        local target_path="${STOW_TARGET}/${relative_path}"
        
        backup_existing_file "${target_path}"
    done < <(find "${package_dir}" -type f -print0 2>/dev/null)
}

stow_package() {
    local package="$1"
    local package_dir="${DOTFILES_ROOT}/${package}"
    
    if [[ ! -d "${package_dir}" ]]; then
        log_warning "Package directory not found: ${package_dir}"
        return 1
    fi
    
    log_info "Stowing package: ${package}"
    
    # Perform pre-stow cleanup
    prestow_cleanup "${package}"
    
    # Run stow
    if stow -v -d "${DOTFILES_ROOT}" -t "${STOW_TARGET}" "${package}" 2>&1; then
        log_success "Successfully stowed: ${package}"
        return 0
    else
        log_error "Failed to stow: ${package}"
        return 1
    fi
}

unstow_package() {
    local package="$1"
    
    log_info "Unstowing package: ${package}"
    
    if stow -v -D -d "${DOTFILES_ROOT}" -t "${STOW_TARGET}" "${package}" 2>&1; then
        log_success "Successfully unstowed: ${package}"
        return 0
    else
        log_error "Failed to unstow: ${package}"
        return 1
    fi
}

restow_package() {
    local package="$1"
    
    log_info "Restowing package: ${package}"
    
    if stow -v -R -d "${DOTFILES_ROOT}" -t "${STOW_TARGET}" "${package}" 2>&1; then
        log_success "Successfully restowed: ${package}"
        return 0
    else
        log_error "Failed to restow: ${package}"
        return 1
    fi
}

# =============================================================================
# MAIN OPERATIONS
# =============================================================================

stow_all() {
    log_info "Stowing all packages..."
    
    local failed=0
    for package in "${STOW_PACKAGES[@]}"; do
        if ! stow_package "${package}"; then
            ((failed++))
        fi
    done
    
    if [[ ${failed} -gt 0 ]]; then
        log_error "${failed} package(s) failed to stow"
        return 1
    fi
    
    log_success "All packages stowed successfully"
}

unstow_all() {
    log_info "Unstowing all packages..."
    
    for package in "${STOW_PACKAGES[@]}"; do
        unstow_package "${package}" || true
    done
    
    log_success "All packages unstowed"
}

restow_all() {
    log_info "Restowing all packages..."
    
    local failed=0
    for package in "${STOW_PACKAGES[@]}"; do
        if ! restow_package "${package}"; then
            ((failed++))
        fi
    done
    
    if [[ ${failed} -gt 0 ]]; then
        log_error "${failed} package(s) failed to restow"
        return 1
    fi
    
    log_success "All packages restowed successfully"
}

verify_stow() {
    log_info "Verifying stowed symlinks..."
    
    local errors=0
    for package in "${STOW_PACKAGES[@]}"; do
        local package_dir="${DOTFILES_ROOT}/${package}"
        
        if [[ ! -d "${package_dir}" ]]; then
            continue
        fi
        
        while IFS= read -r -d '' file; do
            local relative_path="${file#"${package_dir}"/}"
            local target_path="${STOW_TARGET}/${relative_path}"
            
            if [[ -L "${target_path}" ]]; then
                local link_target
                link_target=$(readlink -f "${target_path}")
                if [[ "${link_target}" == "${file}" ]]; then
                    echo -e "  ${GREEN}✓${NC} ${target_path}"
                else
                    log_error "✗ ${target_path} points to wrong target"
                    ((errors++))
                fi
            else
                log_error "✗ ${target_path} is not a symlink"
                ((errors++))
            fi
        done < <(find "${package_dir}" -type f -print0 2>/dev/null)
    done
    
    if [[ ${errors} -gt 0 ]]; then
        log_error "Verification failed with ${errors} error(s)"
        return 1
    fi
    
    log_success "All symlinks verified successfully"
}

show_status() {
    echo ""
    echo "=== Dotfiles Status ==="
    echo "Source: ${DOTFILES_ROOT}"
    echo "Target: ${STOW_TARGET}"
    echo ""
    echo "Packages:"
    for package in "${STOW_PACKAGES[@]}"; do
        local package_dir="${DOTFILES_ROOT}/${package}"
        if [[ -d "${package_dir}" ]]; then
            echo "  ✓ ${package}"
        else
            echo "  ✗ ${package} (not found)"
        fi
    done
    echo ""
}

# =============================================================================
# LEGACY FUNCTION (for bootstrap.sh compatibility)
# =============================================================================

setup_dotfiles() {
    log_info "Phase 5: Setting up dotfiles with GNU Stow..."
    
    ensure_stow_installed || return 1
    ensure_dotfiles_exist || return 1
    stow_all
    verify_stow
    
    log_success "Dotfiles setup completed"
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

main() {
    local action="${1:-stow}"
    
    log_info "Dotfiles bootstrap starting..."
    
    # Ensure prerequisites
    ensure_stow_installed || exit 1
    ensure_dotfiles_exist || exit 1
    
    case "${action}" in
        stow|install)
            stow_all
            verify_stow
            ;;
        unstow|uninstall|remove)
            unstow_all
            ;;
        restow|reinstall|update)
            restow_all
            verify_stow
            ;;
        verify|check)
            verify_stow
            ;;
        status)
            show_status
            ;;
        *)
            echo "Usage: $0 {stow|unstow|restow|verify|status}"
            echo ""
            echo "Commands:"
            echo "  stow     - Install dotfiles symlinks"
            echo "  unstow   - Remove dotfiles symlinks"
            echo "  restow   - Reinstall (unstow + stow)"
            echo "  verify   - Verify symlinks are correct"
            echo "  status   - Show current status"
            exit 1
            ;;
    esac
    
    log_success "Dotfiles bootstrap completed"
}

# Run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
