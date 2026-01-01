#!/usr/bin/env bash

# Remove old or distro Docker (if any)
sudo apt remove docker docker-engine docker.io containerd runc -y

# Update system & install prerequistes
sudo apt update -y
sudo apt install -y ca-certificates curl gnupg lsb-release

# Add Docker’s official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker APT repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Post-installation steps: Manage Docker as a non-root user
sudo usermod -aG docker $USER
newgrp docker

# Enable and start Docker service
sudo systemctl enable docker
sudo systemctl start docker

docker --version
docker compose version
