#!/bin/bash
# Custom installation script for shell-gpt on Debian/Ubuntu using uv
set -euo pipefail

echo "🤖 Installing shell-gpt via uv tool install on Debian/Ubuntu..."

# Check if uv is available
if ! command -v uv &>/dev/null; then
    echo "❌ uv is not installed or not in PATH"
    echo "💡 Please ensure uv is installed via Homebrew first"
    exit 1
fi

# Install shell-gpt using uv tool install
echo "📦 Installing shell-gpt using uv tool install..."
uv tool install shell-gpt

# Verify installation
if command -v sgpt &>/dev/null; then
    echo "✅ shell-gpt installed successfully"
    sgpt --version
else
    echo "❌ shell-gpt installation failed"
    exit 1
fi

echo "🎉 shell-gpt installation complete!"
echo "💡 Run 'sgpt --help' to get started"