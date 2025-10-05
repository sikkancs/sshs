# SSHs – Interactive SSH Menu for macOS

SSHs is a shell script + AWK tool that lets you quickly browse and connect to your SSH hosts using fzf.  
It is inspired by [trzsz-ssh](https://github.com/trzsz/trzsz-ssh) but avoids Go, using only shell and AWK, following the approach described in [How I manage SSH connections](https://hiphish.github.io/blog/2020/05/23/how-i-manage-ssh-connections/).

Works directly with your SSH config file (~/.ssh/config)

## Features
- Search through SSH hosts (entries in ~/.ssh/config)
- Two-column menu: Host name (with HostName) + Tags
- Preview: shows the SSH configuration for the selected host
- Key bindings:
    - Enter: Connect normally: ssh {host}
    - Ctrl+V: Connect in verbose mode: ssh -vvvv {host}
    - ?: Toggle preview (show host config)

## How it works

sshs parses your ~/.ssh/config and builds an interactive menu using fzf and AWK script, showing each Host, its HostName, and optional #Tags (like #Tags work prod). Select an entry to connect via SSH instantly.

It builds an interactive list of SSH hosts for fzf, showing:
- Host → the SSH alias (Host myserver)
- Hostname → the real address or IP (HostName 192.168.1.10)
- Tags → optional labels from lines like # Tags work prod

Each entry is displayed as:
`myserver (192.168.1.10)    work prod`

Tags are optional — if no # Tags line is found, the field is left empty.
The first column (Host) is used to run ssh {host} when selected.

sshs parses your ~/.ssh/config and builds an interactive menu using fzf, showing each Host, its HostName, and optional # Tags (like # Tags work prod). Select an entry to connect via SSH instantly.

## Installation on macOS

```bash
# Ensure you have fzf installed:
brew install fzf

# Clone the repository:
git clone https://github.com/sikkancs/sshs.git ~/.ssh/sshs

# Make scripts executable:
chmod +x ~/.ssh/sshs/sshs.sh
chmod +x ~/.ssh/sshs/sshs.awk

# Add an alias to your shell configuration (~/.zshrc or ~/.bashrc):
echo 'alias sshs="~/.ssh/sshs/sshs.sh"' >> ~/.zshrc
source ~/.zshrc
```

## Usage
Run `sshs` in terminal.  
Run `sshs -h` for key bindings.

## SSH config examples (~/.ssh/config)
```
Host firewall-1
	HostName 172.21.254.11
	Port 22
	User orange
	PreferredAuthentications password
	PubkeyAuthentication no
	#Tags firewall ACTIVEpair paloalto

Host test-webserver-1
	HostName 10.10.0.12
	Port 22
	User brokkoli
	PreferredAuthentications publickey
	IdentityFile ~/.ssh/test-webserver-1
	IdentitiesOnly yes
	#Tags test dev staging apache ubuntu webserver

Host NAS01
	HostName 192.168.0.100
	Port 22
	User root
	PreferredAuthentications publickey
	IdentityFile ~/.ssh/nas01.pub
	IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
	IdentitiesOnly yes
	#Tags nas prod rack10unit11
```

## Known issues
- If the SSH connection succeeds, you see the verbose logs in real-time, but if SSH fails immediately (host unreachable, wrong port, network issue), the SSH process terminates, and FZF restores the terminal buffer --> That “restore” wipes the output — so the verbose messages disappear almost instantly.
- Downsizing the terminal width will create mess.
- 
