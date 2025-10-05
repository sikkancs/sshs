#!/bin/zsh

# --- Help / usage function ---
usage() {
    cat << EOF
SSHs - Interactive SSH menu

Usage:
  sshs           Launch the SSH menu
  sshs -h|--help Show this help message

Key bindings in menu:
  Enter         Connect normally (ssh {host})
  Ctrl+v        Connect in verbose mode (ssh -vvvv {host})
  ?             Toggle preview (show SSH config)
  Esc/Ctrl-c    Exit
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
            host = ip = tags = ""
            n = 0
            maxlen = 0
        }

        /^[[:space:]]*Host[[:space:]]+/ {
            # Print previous host entry
            if (host != "") {
                display = host
                if (ip != "") display = display " (" ip ")"
                entries[n,0] = host
                entries[n,1] = display
                entries[n,2] = tags
                if (length(display) > maxlen) maxlen = length(display)
                n++
            }

            if ($2 == "*" || $2 == "" || $2 ~ /^\s*$/) { host=""; next }
            host = $2
            ip = ""
            tags = ""
            next
        }

        /^[[:space:]]*HostName[[:space:]]+/ { ip = $2; next }

        /^[[:space:]]*#[[:space:]]*Tags[[:space:]]+/ {
            sub(/^[[:space:]]*#[[:space:]]*Tags[[:space:]]+/, "", $0)
            tags = $0
            next
        }

        END {
            if (host != "") {
                display = host
                if (ip != "") display = display " (" ip ")"
                entries[n,0] = host
                entries[n,1] = display
                entries[n,2] = tags
                if (length(display) > maxlen) maxlen = length(display)
                n++
            }

            # Add header
            printf "%s\t%-" maxlen "s\t%s\n", "_header_", "Host (Hostname)", "Tags"

            # Print aligned host rows
            for (i = 0; i < n; i++) {
                if (entries[i,0] != "")
                    printf "%s\t%-" maxlen "s\t%s\n", entries[i,0], entries[i,1], entries[i,2]
            }
        }
    ' ~/.ssh/config | tr -d "\r"
)

# --- FZF config ---
export FZF_DEFAULT_OPTS='
--height=~12
--reverse
--exact
--tiebreak=begin,length
--delimiter="\t"
--with-nth=2,3
--preview="awk -v HOST={1} -f ~/.ssh/sshs/sshs.awk ~/.ssh/config"
--preview-window=down:50%:wrap:hidden
--bind "?":toggle-preview
--bind "ctrl-v:execute(ssh -vvvv {1})+abort"
--prompt="Search hosts, hostnames, or tags: "
--border=rounded
--layout=reverse
--header-lines=1
'

# --- Run menu ---
entry=$(printf "%s/n" "$hostlist" | fzf --ansi)

host=$(printf "%s" "$entry" | cut -f1)

[ -n "$host" ] && ssh "$host"
