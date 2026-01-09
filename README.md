# codex-status

Real-time status monitor for Codex CLI in your terminal title.

**English** | [中文](README_zh.md)

![demo](images/demo.gif)

## Core Idea

**Problem**: Codex CLI has no built-in way to show if it's working or waiting for input.

**Solution**:
1. Inject completion markers (`CODEX_DONE`) into Codex prompts
2. Monitor session files (`~/.codex/sessions/*.jsonl`) to detect state
3. Display status in terminal title via OSC sequences

## Status Icons

| Icon | Status | Meaning |
|:---:|:---|:---|
| ▶ | Run | Producing output |
| ▷ | Think | Pending, low activity |
| ◇ | Idle | Long quiet period |
| □ | Free | Waiting for input |
| ■ | Stuck | Very long quiet |
| × | Exit | Process exited |

## Installation

### Linux / macOS / WSL

```bash
./install.sh
```

Auto-configures shell (zsh/bash). Restart terminal after install.

### Windows (PowerShell)

```powershell
.\install.ps1
```

Auto-configures PATH. Restart terminal after install.

## Usage

After installation, just run:

```bash
codex
```

The terminal title will show real-time status.

## Uninstall

```bash
./uninstall.sh      # Linux/macOS/WSL
.\uninstall.ps1     # Windows
```

## Configuration (optional)

Environment variables:
- `CODEX_STATUS_ICON_STYLE`: `shape` (default) or `emoji`
- `CODEX_STATUS_INTERVAL_S`: sample interval (default `2`)
- `CODEX_STATUS_MODEL_STUCK_S`: stuck threshold (default `900`)
