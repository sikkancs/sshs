#!/usr/bin/env bash

# SSHs - Interactive SSH Host Picker
#
# Features:
# - Reads standard OpenSSH configuration
# - Supports ~/.ssh/config.d/*.conf
# - Native ssh compatibility
# - Tag-based searching
# - Host configuration preview
#
# Directory layout:
#
# ~/.ssh/
# ├── config
# └── config.d/
#   ├── customer-a.conf
#   ├── customer-b.conf
#   └── lab.conf
#
# ~/.config/sshs/
# ├── sshs.sh
# └── sshs.awk
#

# Primary SSH config file.
# Can be overridden with SSH_CONFIG environment variable.
CONFIG_FILE="${SSH_CONFIG:-$HOME/.ssh/config}"

# Directory containing customer/project specific SSH configs.
# Can be overridden with SSH_CONFIG_DIR environment variable.
CONFIG_DIR="${SSH_CONFIG_DIR:-$HOME/.ssh/config.d}"

# Create a temporary merged SSH configuration.
# SSHs parses this file so it can see both:
# ~/.ssh/config
# and all *.conf files from config.d/
TMP_CONFIG=$(mktemp)

# Recent file
RECENT_FILE="$HOME/.config/sshs/recent"
mkdir -p "$HOME/.config/sshs"
touch "$RECENT_FILE"

# Start with main config
echo "# Source: config" > "$TMP_CONFIG"
cat "$CONFIG_FILE" >> "$TMP_CONFIG"

# Append config.d files
if [ -d "$CONFIG_DIR" ]; then
    find "$CONFIG_DIR" -name "*.conf" -type f | sort |
    while read -r f; do
        echo "" >> "$TMP_CONFIG"
        echo "# Source: $(basename "$f")" >> "$TMP_CONFIG"
        cat "$f" >> "$TMP_CONFIG"
    done
fi

# Automatically remove temporary merged config on exit.
trap 'rm -f "$TMP_CONFIG"' EXIT

# --- Help / usage function ---
usage() {
    cat << EOF
SSHs - Interactive SSH menu

Usage:
  sshs           Launch the SSH menu
  sshs -h|--help Show this help message

Key bindings in menu:
  Enter         Connect normally (ssh {host})
  Ctrl+V        Connect in verbose mode (ssh -vvvv {host})
  Ctrl+E        Open source config in VS Code
  ?             Toggle preview (show SSH config)
  Esc/Ctrl-C    Exit
EOF
}

# --- Check for -h / --help ---
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi

# --- Build host list: real host, display text, tags ---
hostlist=$(
    awk '
    BEGIN {
        host = ip = tags = source = ""
        n = 0
        maxlen = 0
        maxtags = 0
    }

    function save_host() {

        if (host == "")
            return

        display = host

        if (ip != "")
            display = display " (" ip ")"

        entries[n,0] = host
        entries[n,1] = display
        entries[n,2] = tags
        entries[n,3] = source

        if (length(display) > maxlen)
            maxlen = length(display)

        if (length(tags) > maxtags)
            maxtags = length(tags)

        n++
    }

    # Source file marker inserted by sshs.sh
    /^[[:space:]]*#[[:space:]]*Source:/ {

        # Save previous host before switching source file
        save_host()

        host = ""
        ip = ""
        tags = ""

        source = $3
        next
    }

    # Host block
    /^[[:space:]]*Host[[:space:]]+/ {

        save_host()

        host = ""
        ip = ""
        tags = ""

        if ($2 == "" || $2 ~ /^[[:space:]]*$/)
            next

        # Skip wildcard hosts
        if (index($2, "*"))
            next

        host = $2
        next
    }

    # HostName
    /^[[:space:]]*HostName[[:space:]]+/ {
        ip = $2
        next
    }

    # Tags
    /^[[:space:]]*#[[:space:]]*Tags[[:space:]]+/ {
        sub(/^[[:space:]]*#[[:space:]]*Tags[[:space:]]+/, "", $0)
        tags = $0
        next
    }

    END {

        save_host()

        printf "%s\t%-" maxlen "s\t%-" maxtags "s\t%s\n",
               "_header_",
               "Host (Hostname)",
               "Tags",
               "Source"

        for (i = 0; i < n; i++) {

            if (entries[i,0] != "")
                printf "%s\t%-" maxlen "s\t%-" maxtags "s\t%s\n",
                       entries[i,0],
                       entries[i,1],
                       entries[i,2],
                       entries[i,3]
        }
    }
    ' "$TMP_CONFIG" | tr -d "\r"
)

# Move recent hosts to the top
header=$(printf "%s\n" "$hostlist" | head -1)
rows=$(printf "%s\n" "$hostlist" | tail -n +2)
recentrows=""
normalrows="$rows"

while read -r h; do
    [ -z "$h" ] && continue
    row=$(printf "%s\n" "$normalrows" | grep "^${h}[[:space:]]")
    if [ -n "$row" ]; then
        recentrows+="$row"$'\n'
        normalrows=$(printf "%s\n" "$normalrows" | grep -v "^${h}[[:space:]]")
    fi
done < "$RECENT_FILE"

displaylist="$header"
if [ -n "$recentrows" ]; then
displaylist="$header"
displaylist+=$'\n'
displaylist+="$recentrows"
displaylist+=$'\n'
displaylist+="────────────────────────────────────────────────────────────"
displaylist+=$'\n'
displaylist+="$normalrows"
fi

displaylist+=$'\n'
displaylist+="$normalrows"

# Remove empty lines
displaylist=$(printf "%s\n" "$displaylist" | awk 'NF')

# Export merged config path so fzf preview commands can access the same combined configuration.
export SSHS_TMP_CONFIG="$TMP_CONFIG"

# Export config directory for Ctrl-E
export SSHS_CONFIG_DIR="$CONFIG_DIR"

# --- FZF config ---
export FZF_DEFAULT_OPTS='
--height=60%
--reverse
--exact
--tiebreak=begin,length
--delimiter="\t"
--with-nth=2,3,4
--preview="awk -v HOST={1} -f ~/.config/sshs/sshs.awk \$SSHS_TMP_CONFIG"
--preview-window=down:50%:wrap:hidden
--bind "?":toggle-preview
--bind "ctrl-v:execute(ssh -vvvv {1})+abort"
--bind "ctrl-e:execute-silent(code \$SSHS_CONFIG_DIR/{4})"
--prompt="[Recent 5 hosts at top] Search: "
--layout=reverse
--info=right
--header-lines=1
--border=rounded
--border-label=" SSHs │ Enter=Connect │ Ctrl-V=Verbose │ Ctrl-E=Edit | ?=Details"
--ellipsis=...
'

# --- Run menu ---
entry=$(printf "%s\n" "$displaylist" | fzf --ansi)
host=$(printf "%s" "$entry" | cut -f1)
case "$host" in
_recent_|_separator_)
exit 0
;;
esac

if [ -n "$host" ]; then
    {
        echo "$host"
        cat "$RECENT_FILE" 2>/dev/null
    } |
    awk '!seen[$0]++' |
    head -5 > "${RECENT_FILE}.tmp"
    mv "${RECENT_FILE}.tmp" "$RECENT_FILE"
    ssh "$host"
fi
