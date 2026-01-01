.PHONY: install uninstall

install-cli:
	@echo "Installing homelab CLI..."
	sudo cp cli/homelab.sh /usr/local/bin/homelab
	sudo chmod +x /usr/local/bin/homelab
	@echo "Installation complete. Run 'homelab help' to get started."

uninstall-cli:
	@echo "Uninstalling homelab CLI..."
	sudo rm -f /usr/local/bin/homelab
	@echo "Uninstallation complete."
