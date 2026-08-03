#!/bin/bash
# Custom installation script for gcloud on Raspberry Pi OS
set -euo pipefail

echo "🌩️ Installing Google Cloud SDK (gcloud) for Raspberry Pi OS..."

# Check if we're on ARM architecture
ARCH=$(uname -m)
if [[ "$ARCH" != "armv7l" && "$ARCH" != "aarch64" ]]; then
    echo "⚠️ Warning: This script is designed for ARM architecture (Raspberry Pi)"
fi

# Add the Cloud SDK distribution URI as a package source
if [[ ! -f /etc/apt/sources.list.d/google-cloud-sdk.list ]]; then
    echo "📋 Adding Google Cloud SDK repository..."
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
fi

# Import the Google Cloud public key
if [[ ! -f /usr/share/keyrings/cloud.google.gpg ]]; then
    echo "🔑 Adding Google Cloud SDK signing key..."
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
fi

# Update package lists
echo "🔄 Updating package lists..."
sudo apt-get update -qq

# Install the Cloud SDK
echo "📦 Installing Google Cloud SDK..."
if sudo apt-get install -y -qq google-cloud-cli; then
    echo "✅ Installed Google Cloud SDK via apt"
else
    echo "⚠️ apt installation failed, trying manual installation..."

    # Fallback to manual installation
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    echo "📥 Downloading Google Cloud SDK for ARM..."
    curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-arm.tar.gz

    echo "📂 Extracting Google Cloud SDK..."
    tar -xf google-cloud-cli-linux-arm.tar.gz

    # Install to /opt
    echo "📦 Installing to /opt/google-cloud-sdk..."
    sudo mv google-cloud-sdk /opt/

    # Create symlinks
    sudo ln -sf /opt/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud
    sudo ln -sf /opt/google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil
    sudo ln -sf /opt/google-cloud-sdk/bin/bq /usr/local/bin/bq

    # Cleanup
    cd ~
    rm -rf "$TEMP_DIR"
fi

# Verify installation
if command -v gcloud &>/dev/null; then
    echo "✅ Google Cloud SDK installed successfully"
    gcloud version
else
    echo "❌ Google Cloud SDK installation failed"
    exit 1
fi

echo "🎉 Google Cloud SDK installation complete!"
echo "💡 Run 'gcloud init' to initialize and authenticate your setup"