#!/bin/bash
# Custom installation script for gcloud on Debian/Ubuntu
set -euo pipefail

echo "🌩️ Installing Google Cloud SDK (gcloud) for Debian/Ubuntu..."

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
sudo apt-get install -y -qq google-cloud-cli

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