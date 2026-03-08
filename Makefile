.PHONY: install uninstall dotfiles dotfiles-unstow dotfiles-restow dotfiles-verify
.PHONY: backup-image-build install-backup backup-test

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
	@echo ""
	@echo "Backup:" 
	@echo "  make backup-image-build - Build docker/backup-image and tag homelab/backup-image:local"
	@echo "  make install-backup     - Install backup scripts and systemd units (requires sudo)"
	@echo "  make backup-test        - Run backup script in dry-run mode to validate (no secrets required)"

# Build the backup helper docker image and tag locally

backup-image-build:
	@echo "Building backup image..."
	@bash docker/build-backup-image.sh
	@echo "Done. Image tagged as homelab/backup-image:local"

# Install backup scripts and systemd unit files to system locations (requires sudo)
install-backup:
	@echo "Installing backup scripts and systemd units (requires sudo)..."
	# Copy scripts to /usr/local/bin
	@sudo install -d /usr/local/bin
	@for f in stacks/backup/*.sh stacks/backup/excludes.txt; do \
		[ -f $$f ] || continue; \
		echo "Installing $$f -> /usr/local/bin/"; \
		sudo cp -a $$f /usr/local/bin/; \
		sudo chmod +x /usr/local/bin/$$(basename $$f .sh) || true; \
	done
	# Install systemd units from stacks/backup/systemd
	@if [ -d stacks/backup/systemd ]; then \
		echo "Copying systemd unit files to /etc/systemd/system/"; \
		sudo cp -a stacks/backup/systemd/* /etc/systemd/system/ || true; \
		sudo systemctl daemon-reload || true; \
		echo "Systemd units copied. To enable timers/services run: sudo systemctl enable --now homelab-backup.timer homelab-prune.timer (optional)"; \
	else \
		echo "No systemd units found at stacks/backup/systemd; skipping."; \
	fi
	# Create /etc/homelab directory
	@echo "Creating /etc/homelab directory and restic.env from template.";
	@sudo install -d -m 0750 /etc/homelab
	# Copy restic.env to /etc/homelab if it exists in stacks/backup
	@if [ -f stacks/backup/restic.env ]; then \
		echo "Copying restic.env to /etc/homelab/restic.env"; \
		sudo cp -a stacks/backup/restic.env /etc/homelab/restic.env; \
		sudo chmod 640 /etc/homelab/restic.env; \
	elif [ -f stacks/backup/restic.env.example ]; then \
		echo "Note: restic.env not found. Copy stacks/backup/restic.env.example to /etc/homelab/restic.env and configure it."; \
	fi
	# Create placeholder restic.pass if needed
	@if [ ! -f /etc/homelab/restic.pass ]; then \
		echo "(placeholder) restic password file created at /etc/homelab/restic.pass"; \
		sudo sh -c 'umask 077 && : > /etc/homelab/restic.pass'; \
		sudo chmod 0600 /etc/homelab/restic.pass; \
	else \
		echo "/etc/homelab/restic.pass already exists; leaving in place."; \
	fi
	@echo "install-backup complete. Review /etc/homelab/restic.env and populate with your RESTIC_REPOSITORY and RESTIC_PASSWORD or RESTIC_PASSWORD_FILE.";

# Run a dry-run of the backup to validate environment (no secrets required)
backup-test:
	@echo "Running backup in DRY_RUN mode..."
	@DRY_RUN=1 ./stacks/backup/backup.sh || true
	@echo "Dry-run complete. Check output above for issues."
