# Codex Status - Bash Hook (source this in .bashrc)
# Automatically starts status monitor when codex is launched

_codex_status_preexec() {
    local cmd="$BASH_COMMAND"

    # Check if command starts with codex (but not codex-status)
    if [[ "$cmd" =~ ^codex([[:space:]]|$) || "$cmd" =~ ^codex-ccbdone([[:space:]]|$) || "$cmd" =~ ^codex-done([[:space:]]|$) ]] && [[ ! "$cmd" =~ ^codex-status ]]; then
        local tty_name
        tty_name="$(tty 2>/dev/null | sed 's|/dev/||')"
        [[ -z "$tty_name" || "$tty_name" == "not a tty" ]] && return

        local start_cwd
        start_cwd="$(pwd -P 2>/dev/null || echo "$PWD")"

        (
            sleep 2
            ~/.local/bin/codex-status-bg "$tty_name" "$start_cwd" &>/dev/null
        ) &
        disown 2>/dev/null || true
    fi
}

# Register DEBUG trap for preexec-like behavior
trap '_codex_status_preexec' DEBUG

echo "✅ Codex status hook loaded"
