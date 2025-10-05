# SSHs – Interactive SSH Menu for macOS

sshs is a shell script + AWK tool that lets you quickly browse and connect to your SSH hosts using fzf.

It is inspired by [trzsz-ssh](https://github.com/trzsz/trzsz-ssh) but avoids Go, using only shell and AWK, following the approach described in [How I manage SSH connections](https://hiphish.github.io/blog/2020/05/23/how-i-manage-ssh-connections/).

Works directly with your SSH config file (~/.ssh/config)

This project was created with the help of ChatGPT to simplify SSH management while keeping it lightweight, portable, and easy to extend.

## Features
- Search through SSH hosts (entries in ~/.ssh/config)
- Two-column menu: Host name (with HostName) + Tags
- Preview: shows the SSH configuration for the selected host
- Key bindings:
    - Enter: Connect normally: ssh {host}
    - Ctrl+V: Connect in verbose mode: ssh -vvvv {host}
    - ?: Toggle preview (show host config)
- Fancy help with -h


## Installation on macOS

```bash
# Ensure you have fzf installed:
brew install fzf

# Clone the repository:
git clone https://github.com/sikkancs/sshs.git ~/.ssh/sshs

# Make scripts executable:**  
chmod +x ~/.ssh/sshs/sshs.sh
chmod +x ~/.ssh/sshs/sshs.awk

# Add an alias to your shell configuration (~/.zshrc or ~/.bashrc):
echo 'alias sshs="~/.ssh/sshs/sshs.sh"' >> ~/.zshrc
source ~/.zshrc
```

## Usage
Type `sshs` in terminal.
- Start typing to filter hosts
- Press Enter to connect normally
- Press Ctrl+V to connect in verbose mode (ssh -vvvv)
- Press ? to toggle preview of the host configuration

Or type `sshs -h` for usage.

## Optional
- Customize the number of menu items (--height=~10)
- Customize preview window size (--preview-window)
- Customize hotkeys (--bind)
- Add your own #Tags in ~/.ssh/config to categorize hosts