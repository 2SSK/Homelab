.PHONY: install uninstall dotfiles dotfiles-unstow dotfiles-restow dotfiles-verify

# =============================================================================
# CLI Installation
# =============================================================================

install-cli:
	@echo "Installing homelab CLI..."
	sudo ln -s $(PWD)/cli/homelab.sh /usr/local/bin/homelab
	@echo "Installation complete. Run 'homelab help' to get started."

uninstall-cli:
	@echo "Uninstalling homelab CLI..."
	sudo rm -f /usr/local/bin/homelab
	@echo "Uninstallation complete."

# =============================================================================
# Dotfiles Management
# =============================================================================

dotfiles:
	@echo "Installing dotfiles with GNU Stow..."
	@./cli/bootstrap/phases/dotfiles.sh stow

dotfiles-unstow:
	@echo "Removing dotfiles symlinks..."
	@./cli/bootstrap/phases/dotfiles.sh unstow

dotfiles-restow:
	@echo "Restowing dotfiles..."
	@./cli/bootstrap/phases/dotfiles.sh restow

dotfiles-verify:
	@echo "Verifying dotfiles symlinks..."
	@./cli/bootstrap/phases/dotfiles.sh verify

dotfiles-status:
	@./cli/bootstrap/phases/dotfiles.sh status

# =============================================================================
# Combined Targets
# =============================================================================

install: install-cli dotfiles
	@echo "Full installation complete."

uninstall: uninstall-cli dotfiles-unstow
	@echo "Full uninstallation complete."

# =============================================================================
# Help
# =============================================================================

help:
	@echo "Homelab Makefile Commands:"
	@echo ""
	@echo "CLI:"
	@echo "  make install-cli      - Install homelab CLI to /usr/local/bin"
	@echo "  make uninstall-cli    - Remove homelab CLI"
	@echo ""
	@echo "Dotfiles:"
	@echo "  make dotfiles         - Stow dotfiles to home directory"
	@echo "  make dotfiles-unstow  - Remove dotfiles symlinks"
	@echo "  make dotfiles-restow  - Restow dotfiles (update)"
	@echo "  make dotfiles-verify  - Verify all symlinks are correct"
	@echo "  make dotfiles-status  - Show dotfiles status"
	@echo ""
	@echo "Combined:"
	@echo "  make install          - Full install (CLI + dotfiles)"
	@echo "  make uninstall        - Full uninstall"
