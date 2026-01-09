#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
PRIORITY_DIR="${HOME}/.local/bin/priority"
LIB_DIR="${HOME}/.local/lib/codex-status"
SHARE_DIR="${HOME}/.local/share/codex-status"
CACHE_DIR="${HOME}/.cache/codex-status"

CONFIG_MARKER="# codex-status config"
CONFIG_BLOCK=$(cat <<'CONFIGEOF'
# codex-status config
export PATH="$HOME/.local/bin/priority:$PATH"
export CODEX_STATUS_WEZTERM_MODE="off"
CONFIGEOF
)

detect_shell() {
    if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "$(which zsh 2>/dev/null)" ]; then
        echo "zsh"
    elif [ -n "$BASH_VERSION" ] || [ "$SHELL" = "$(which bash 2>/dev/null)" ]; then
        echo "bash"
    else
        basename "$SHELL" 2>/dev/null || echo "unknown"
    fi
}

get_rc_file() {
    local shell_type="$1"
    case "$shell_type" in
        zsh)  echo "${HOME}/.zshrc" ;;
        bash)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                echo "${HOME}/.bash_profile"
            else
                echo "${HOME}/.bashrc"
            fi
            ;;
        *)    echo "" ;;
    esac
}

get_hook_file() {
    local shell_type="$1"
    case "$shell_type" in
        zsh)  echo "${LIB_DIR}/shell_hook.zsh" ;;
        bash) echo "${LIB_DIR}/shell_hook.bash" ;;
        *)    echo "" ;;
    esac
}

add_config_to_rc() {
    local rc_file="$1"
    local hook_file="$2"

    if [ -z "$rc_file" ]; then
        return 1
    fi

    [ -f "$rc_file" ] || touch "$rc_file"

    if grep -q "$CONFIG_MARKER" "$rc_file" 2>/dev/null; then
        echo "Config already exists in $rc_file, skipping..."
        return 0
    fi

    echo "" >> "$rc_file"
    echo "$CONFIG_BLOCK" >> "$rc_file"
    if [ -n "$hook_file" ]; then
        echo "source \"$hook_file\"" >> "$rc_file"
    fi
    echo "# end codex-status config" >> "$rc_file"

    echo "Added config to $rc_file"
    return 0
}

echo "Installing codex-status..."
echo ""

mkdir -p "$INSTALL_DIR" "$PRIORITY_DIR" "$LIB_DIR" "$SHARE_DIR" "$CACHE_DIR"

cp -r "$SCRIPT_DIR/lib/"* "$LIB_DIR/"
cp "$SCRIPT_DIR/config/ccbdone_instructions.txt" "$SHARE_DIR/"
cp "$SCRIPT_DIR/config/done_tag_instructions.txt" "$SHARE_DIR/"

cp "$SCRIPT_DIR/bin/codex-status" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/bin/codex-status-wrapper" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/bin/codex-status-bg" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/codex-status" "$INSTALL_DIR/codex-status-wrapper" "$INSTALL_DIR/codex-status-bg"

cp "$SCRIPT_DIR/bin/codex-ccbdone" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/bin/codex-done" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/codex-ccbdone" "$INSTALL_DIR/codex-done"

cp "$SCRIPT_DIR/bin/codex-wrapper" "$PRIORITY_DIR/codex"
chmod +x "$PRIORITY_DIR/codex"

echo "Files installed to $INSTALL_DIR"
echo ""

SHELL_TYPE=$(detect_shell)
RC_FILE=$(get_rc_file "$SHELL_TYPE")
HOOK_FILE=$(get_hook_file "$SHELL_TYPE")

echo "Detected shell: $SHELL_TYPE"
echo "RC file: $RC_FILE"
echo ""

if [ -n "$RC_FILE" ]; then
    read -p "Auto-configure shell? (add to $RC_FILE) [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        if add_config_to_rc "$RC_FILE" "$HOOK_FILE"; then
            echo ""
            echo "Configuration added. Run: source $RC_FILE"
        fi
    else
        echo "Skipped auto-configuration."
        echo ""
        echo "Manual setup - add to $RC_FILE:"
        echo "  export PATH=\"\$HOME/.local/bin/priority:\$PATH\""
        echo "  source $HOOK_FILE"
        echo "  export CODEX_STATUS_WEZTERM_MODE=\"off\""
    fi
else
    echo "Unknown shell. Manual setup required."
fi

echo ""
echo "Installation complete!"
echo ""
echo "Commands available:"
echo "  codex           # Auto status monitor + done-tag injection"
echo "  codex-status    # Check current status"
echo "  codex-done      # Start codex with CODEX_DONE rule"
echo ""
echo "To uninstall: $SCRIPT_DIR/uninstall.sh"
