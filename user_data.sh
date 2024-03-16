#!/bin/bash

# Update all packages
yum update -y

# Install Docker
yum install -y docker

# Start Docker
systemctl start docker

# Enable Docker to start on boot
systemctl enable docker

# If you plan to use Docker without sudo (optional)
usermod -aG docker ssm-user