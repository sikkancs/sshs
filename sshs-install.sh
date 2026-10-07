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

    if command -v brew >/dev/null 2>&1; then

        echo "Install fzf with:"
        echo
        echo "  brew install fzf"

    elif command -v apt >/dev/null 2>&1; then

        echo "Install fzf with:"
        echo
        echo "  sudo apt install fzf"

    elif command -v dnf >/dev/null 2>&1; then

        echo "Install fzf with:"
        echo
        echo "  sudo dnf install fzf"

    elif command -v yum >/dev/null 2>&1; then

        echo "Install fzf with:"
        echo
        echo "  sudo yum install fzf"

    elif command -v pacman >/dev/null 2>&1; then

        echo "Install fzf with:"
        echo
        echo "  sudo pacman -S fzf"

    elif command -v zypper >/dev/null 2>&1; then

        echo "Install fzf with:"
        echo
        echo "  sudo zypper install fzf"

    else

        echo "Please install fzf manually:"
        echo
        echo "  https://github.com/junegunn/fzf#installation"

    fi

    echo

else

    echo "fzf found."

fi

echo "==> Detecting shell..."

if [ -n "${ZSH_VERSION:-}" ]; then

    RC_FILE="$HOME/.zshrc"

elif [ -n "${BASH_VERSION:-}" ]; then

    RC_FILE="$HOME/.bashrc"

elif [ -f "$HOME/.zshrc" ]; then

    RC_FILE="$HOME/.zshrc"

else

    RC_FILE="$HOME/.bashrc"

fi

echo "Using shell config: $RC_FILE"

echo "==> Checking alias..."

if ! grep -q 'alias sshs=' "$RC_FILE" 2>/dev/null; then

    {
        echo
        echo '# SSHs'
        echo 'alias sshs="$HOME/.config/sshs/sshs.sh"'
    } >> "$RC_FILE"

    echo "Alias added to $RC_FILE"

else

    echo "Alias already exists in $RC_FILE"

fi

echo
echo "Installation complete."
echo
echo "Reload your shell:"
echo
echo "  source $RC_FILE"
echo
echo "Start SSHs:"
echo
echo "  sshs"
echo
echo "Help:"
echo
echo "  sshs -h"
