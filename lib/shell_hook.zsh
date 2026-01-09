# Codex Status - ZSH Hook
# Auto-starts status monitor when codex/ccb is launched

_codex_status_preexec() {
    local cmd="$1"

    # Match: codex, ccb up codex, ccb up ... codex
    if [[ "$cmd" =~ (^codex([[:space:]]|$)|^codex-ccbdone([[:space:]]|$)|^codex-done([[:space:]]|$)|ccb.*codex) ]] && [[ ! "$cmd" =~ codex-status ]]; then
        # Get current TTY
        local tty_name=$(tty 2>/dev/null | sed 's|/dev/||')
        [[ -z "$tty_name" || "$tty_name" == "not a tty" ]] && return

        local start_cwd
        start_cwd="$(pwd -P 2>/dev/null || echo "$PWD")"

        # Start monitor after codex starts
        (
            sleep 2
            ~/.local/bin/codex-status-bg "$tty_name" "$start_cwd" &>/dev/null
        ) &
        disown
    fi
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _codex_status_preexec
