# ~/.ssh/sshs.awk
# Parse SSH config and print the configuration for HOST in a readable table.
# Supports quoted values with spaces and CRLF line endings.

BEGIN {
    n = 0
    width = 0
    did_find_host = 0
}

# Convert CRLF to LF
{
    sub(/\r$/, "")
}

# Skip comments and empty lines
/^$/ || /^#/ {
    next
}

# A new host definition after we found our host terminates
($1 == "Host" || $1 == "Match") && did_find_host {
    exit
}

# Detect the host block
$1 == "Host" && $2 == HOST {
    did_find_host = 1
    next
}

# Inside host definition, parse key/value pairs
did_find_host {
    key = $1
    # Capture the rest of the line after the first space (preserving quotes/spaces)
    val = substr($0, index($0, $2))
    # Remove surrounding quotes if present
    gsub(/^"|"$/, "", val)
    keys[n] = key
    values[n++] = val
    width = max(length(key), width)
}

END {
    for (i = 0; i < n; ++i)
        printf "%-"width"s  %s\n", keys[i], values[i]
}

function max(a, b) {
    return a > b ? a : b
}
