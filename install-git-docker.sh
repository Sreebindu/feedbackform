#!/bin/bash
set -e

echo "=================================="
echo " Installing Git and Docker on Ubuntu"
echo "=================================="

# Update packages
sudo apt update -y

# Install Git, Docker, and utilities
sudo apt install -y git docker.io curl unzip

# Start and enable Docker
sudo systemctl enable --now docker

# Add current user to Docker group
sudo usermod -aG docker "$USER"

# Verify installation
echo "=================================="
echo " Installation Verification"
echo "=================================="

git --version
sudo docker --version
sudo systemctl is-active docker

echo "=================================="
echo " Git and Docker installed!"
echo "=================================="

echo "Log out and reconnect through SSH"
echo "to use Docker without sudo."
