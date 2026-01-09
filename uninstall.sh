#!/bin/bash
set -e

INSTALL_DIR="${HOME}/.local/bin"
PRIORITY_DIR="${HOME}/.local/bin/priority"
LIB_DIR="${HOME}/.local/lib/codex-status"
SHARE_DIR="${HOME}/.local/share/codex-status"
CACHE_DIR="${HOME}/.cache/codex-status"

CONFIG_START="# codex-status config"
CONFIG_END="# end codex-status config"

remove_config_from_rc() {
    local rc_file="$1"

    if [ ! -f "$rc_file" ]; then
        return 0
    fi

    if ! grep -q "$CONFIG_START" "$rc_file" 2>/dev/null; then
        return 0
    fi

    local tmp_file=$(mktemp)
    local in_block=0

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == *"$CONFIG_START"* ]]; then
            in_block=1
            continue
        fi
        if [[ "$line" == *"$CONFIG_END"* ]]; then
            in_block=0
            continue
        fi
        if [ $in_block -eq 0 ]; then
            echo "$line" >> "$tmp_file"
        fi
    done < "$rc_file"

    mv "$tmp_file" "$rc_file"
    echo "Removed config from $rc_file"
}

echo "Uninstalling codex-status..."
echo ""

read -p "Remove shell configuration from rc files? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    for rc_file in "${HOME}/.zshrc" "${HOME}/.bashrc" "${HOME}/.bash_profile"; do
        remove_config_from_rc "$rc_file"
    done
fi

echo ""
echo "Removing installed files..."

rm -f "$INSTALL_DIR/codex-status"
rm -f "$INSTALL_DIR/codex-status-wrapper"
rm -f "$INSTALL_DIR/codex-status-bg"
rm -f "$INSTALL_DIR/codex-ccbdone"
rm -f "$INSTALL_DIR/codex-done"
rm -f "$PRIORITY_DIR/codex"

if [ -d "$PRIORITY_DIR" ] && [ -z "$(ls -A "$PRIORITY_DIR" 2>/dev/null)" ]; then
    rmdir "$PRIORITY_DIR" 2>/dev/null || true
fi

rm -rf "$LIB_DIR"
rm -rf "$SHARE_DIR"

read -p "Remove cache directory ($CACHE_DIR)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$CACHE_DIR"
    echo "Cache removed."
fi

echo ""
echo "Uninstallation complete!"
echo ""
echo "Note: Restart your terminal or run 'source ~/.zshrc' (or ~/.bashrc) to apply changes."
