#!/usr/bin/env bash

set -euo pipefail

SSHS_DIR="$HOME/.config/sshs"

echo "==> Creating SSHs directory..."
mkdir -p "$SSHS_DIR"

echo "==> Downloading files..."

curl -fsSL \
  https://raw.githubusercontent.com/sikkancs/sshs/main/sshs.sh \
  -o "$SSHS_DIR/sshs.sh"

curl -fsSL \
  https://raw.githubusercontent.com/sikkancs/sshs/main/sshs.awk \
  -o "$SSHS_DIR/sshs.awk"

echo "==> Setting permissions..."

chmod +x "$SSHS_DIR/sshs.sh"
chmod +x "$SSHS_DIR/sshs.awk"

echo "==> Checking fzf..."

if ! command -v fzf >/dev/null 2>&1; then
    echo
    echo "fzf is not installed."
    echo
    echo "Install fzf first:"
    echo
    echo "  brew install fzf"
    echo
    echo "If Homebrew is not installed:"
    echo
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    echo
else
    echo "fzf found."
fi

echo "==> Checking alias..."

if ! grep -q 'alias sshs=' "$HOME/.zshrc" 2>/dev/null; then

    echo '' >> "$HOME/.zshrc"
    echo '# SSHs' >> "$HOME/.zshrc"
    echo 'alias sshs="$HOME/.config/sshs/sshs.sh"' >> "$HOME/.zshrc"

    echo "Alias added to ~/.zshrc"

else

    echo "Alias already exists in ~/.zshrc"

fi

echo
echo "Installation complete."
echo
echo "Run:"
echo
echo "  source ~/.zshrc"
echo "  sshs"
echo
echo "Help:"
echo
echo "  sshs -h"
