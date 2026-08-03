#!/bin/bash
# Custom installation script for gcloud on Arch Linux
set -euo pipefail

echo "🌩️ Installing Google Cloud SDK (gcloud) for Arch Linux..."

# Install from AUR using yay (or fallback to manual installation)
if command -v yay &>/dev/null; then
    echo "📦 Installing Google Cloud SDK via AUR (yay)..."
    yay -S --noconfirm google-cloud-cli
elif command -v paru &>/dev/null; then
    echo "📦 Installing Google Cloud SDK via AUR (paru)..."
    paru -S --noconfirm google-cloud-cli
else
    echo "⚠️ No AUR helper found. Installing manually..."

    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    # Download and install Google Cloud SDK
    echo "📥 Downloading Google Cloud SDK..."
    curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz

    echo "📂 Extracting Google Cloud SDK..."
    tar -xf google-cloud-cli-linux-x86_64.tar.gz

    # Install to /opt
    echo "📦 Installing to /opt/google-cloud-sdk..."
    sudo mv google-cloud-sdk /opt/

    # Create symlink
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