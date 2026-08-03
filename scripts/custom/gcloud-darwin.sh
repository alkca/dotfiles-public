#!/bin/bash
# Custom installation script for gcloud on macOS
set -euo pipefail

echo "🌩️ Installing Google Cloud SDK (gcloud) for macOS..."

# Determine architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    GCLOUD_ARCH="arm"
    echo "🍎 Detected Apple Silicon (M1/M2)"
else
    GCLOUD_ARCH="x86_64"
    echo "🍎 Detected Intel Mac"
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download Google Cloud SDK
echo "📥 Downloading Google Cloud SDK for macOS ($GCLOUD_ARCH)..."
curl -O "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-darwin-${GCLOUD_ARCH}.tar.gz"

echo "📂 Extracting Google Cloud SDK..."
tar -xf "google-cloud-cli-darwin-${GCLOUD_ARCH}.tar.gz"

# Install to /usr/local
echo "📦 Installing to /usr/local/google-cloud-sdk..."
sudo mv google-cloud-sdk /usr/local/

# Create symlinks
echo "🔗 Creating symlinks..."
sudo ln -sf /usr/local/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud
sudo ln -sf /usr/local/google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil
sudo ln -sf /usr/local/google-cloud-sdk/bin/bq /usr/local/bin/bq

# Cleanup
cd ~
rm -rf "$TEMP_DIR"

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