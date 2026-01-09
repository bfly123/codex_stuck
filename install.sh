#!/bin/bash
# Install codex-status tools

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
PRIORITY_DIR="${HOME}/.local/bin/priority"
LIB_DIR="${HOME}/.local/lib/codex-status"
SHARE_DIR="${HOME}/.local/share/codex-status"

echo "Installing codex-status..."

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$PRIORITY_DIR"
mkdir -p "$LIB_DIR"
mkdir -p "$SHARE_DIR"
mkdir -p ~/.cache/codex-status

# Copy library
cp -r "$SCRIPT_DIR/lib/"* "$LIB_DIR/"

# Copy shared instruction templates
cp "$SCRIPT_DIR/config/ccbdone_instructions.txt" "$SHARE_DIR/ccbdone_instructions.txt"
cp "$SCRIPT_DIR/config/done_tag_instructions.txt" "$SHARE_DIR/done_tag_instructions.txt"

# Install CLI tools (they auto-resolve installed lib via ~/.local/lib/codex-status)
cp "$SCRIPT_DIR/bin/codex-status" "$INSTALL_DIR/codex-status"
cp "$SCRIPT_DIR/bin/codex-status-wrapper" "$INSTALL_DIR/codex-status-wrapper"
cp "$SCRIPT_DIR/bin/codex-status-bg" "$INSTALL_DIR/codex-status-bg"
chmod +x "$INSTALL_DIR/codex-status" "$INSTALL_DIR/codex-status-wrapper" "$INSTALL_DIR/codex-status-bg"

# Install Codex wrapper that enforces completion tags
cp "$SCRIPT_DIR/bin/codex-ccbdone" "$INSTALL_DIR/codex-ccbdone"
chmod +x "$INSTALL_DIR/codex-ccbdone"
cp "$SCRIPT_DIR/bin/codex-done" "$INSTALL_DIR/codex-done"
chmod +x "$INSTALL_DIR/codex-done"

# Install codex wrapper (auto-inject done-tag) to priority path
cp "$SCRIPT_DIR/bin/codex-wrapper" "$PRIORITY_DIR/codex"
chmod +x "$PRIORITY_DIR/codex"

echo "✅ Installed to $INSTALL_DIR"
echo ""
echo "Usage:"
echo "  codex-status              # Check current status"
echo "  codex-status --watch      # Continuous monitoring"
echo "  codex-status-wrapper ...  # Launch codex with title updates"
echo "  codex-status-bg pts/XX    # Update title for one TTY"
echo "  codex-ccbdone             # Start codex with CCB_DONE rule"
echo "  codex-done                # Start codex with CODEX_DONE rule (recommended)"
echo ""
echo "Example:"
echo "  codex-status-wrapper -c disable_paste_burst=true"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Add to your ~/.zshrc (or ~/.bashrc):"
echo ""
echo "  # Codex-status: priority PATH + shell hook + env"
echo "  export PATH=\"\$HOME/.local/bin/priority:\$PATH\""
echo "  # Zsh:"
echo "  source $LIB_DIR/shell_hook.zsh"
echo "  # Bash:"
echo "  # source $LIB_DIR/shell_hook.bash"
echo "  export CODEX_STATUS_WEZTERM_MODE=\"off\""
echo ""
echo "Then run: source ~/.zshrc   # (or source ~/.bashrc)"
echo ""
echo "After setup:"
echo "  codex        # Auto-inject done-tag + auto status monitor"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
