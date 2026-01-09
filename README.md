# codex-status

<div align="center">

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macos%20%7C%20windows%20%7C%20wsl-lightgrey)
![Shell](https://img.shields.io/badge/shell-bash%20%7C%20zsh%20%7C%20powershell-green)
![License](https://img.shields.io/badge/license-MIT-orange)

**Real-time status monitor for Codex CLI in your terminal title.**

**English** | [中文](README_zh.md)

</div>

---

<div align="center">
  <img src="images/demo.png" alt="codex-status demo" width="800">
  <br>
  <em>(Screenshot placeholder)</em>
</div>

---

## What it does
`codex-status` tracks Codex CLI state and shows it in:
- Terminal title/tab (recommended, via `codex-status-bg` + shell hook)
- A CLI status line (`codex-status --watch`)

To reliably detect “waiting for input vs waiting for output”, this project also installs wrappers that inject a stable completion marker (`CODEX_DONE` / `CCB_DONE`) into Codex prompts.

## Core idea (how it works)
This is intentionally a “best-effort, no-integration” monitor. It does not require any official Codex API.

1) **Make completion machine-detectable**: wrappers inject a rule so every assistant turn ends with `CODEX_DONE` (or `CCB_DONE`).
2) **Use Codex session files as source of truth**: read `~/.codex/sessions/*.jsonl` and compare timestamps:
   - latest user message time vs latest done-tag time → pending vs free
3) **Use lightweight process signals as hints**:
   - CPU/IO deltas and (when available) process state help classify Run/Think/Idle/Stuck
4) **Render to the terminal title**:
   - Generic terminals: write OSC title sequences
   - WezTerm: optionally use `wezterm cli set-tab-title` / `set-window-title`

## Status icons
| Icon (Emoji) | Icon (Shape) | Status | Meaning |
| :---: | :---: | :--- | :--- |
| 🟢 | ▶ | Run | Codex is producing output / progressing. |
| 🟡 | ▷ | Think | Pending, but little recent session activity. |
| 🟠 | ◇ | Idle | Pending, long quiet period (but not stuck yet). |
| 🔵 | □ | Free | Waiting for your input. |
| 🔴 | ■ | Stuck | Very long quiet period (configurable). |
| ⚫ | × | Exit | Codex process exited. |

## Installation

### Linux / WSL (recommended) / macOS
Prereqs:
- `python3`
- `bash` or `zsh`
- `codex` already installed and in `PATH`

Install:
```bash
./install.sh
```

Enable auto-start hook (choose one):
- Zsh: add to `~/.zshrc`
  ```bash
  export PATH="$HOME/.local/bin/priority:$PATH"
  source "$HOME/.local/lib/codex-status/shell_hook.zsh"
  ```
- Bash: add to `~/.bashrc`
  ```bash
  export PATH="$HOME/.local/bin/priority:$PATH"
  source "$HOME/.local/lib/codex-status/shell_hook.bash"
  ```

Then restart your shell (or `source` the rc file).

### Windows (WezTerm + PowerShell)
Native Windows + **WezTerm** is supported via `install.ps1` + `wezterm cli` (no bash/zsh hook).

Prereqs:
- WezTerm installed and `wezterm` available in `PATH` (so `wezterm cli ...` works)
- Python 3 available as `py -3` or `python`
- `codex` installed and available in `PATH`

Install (PowerShell):
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1
```

PATH setup (recommended):
- Add these to **User** `PATH`:
  - `%USERPROFILE%\.local\bin\priority`
  - `%USERPROFILE%\.local\bin`
- Restart WezTerm.

Option A (no PATH changes):
- If you don’t want to wrap `codex` automatically, only add `%USERPROFILE%\.local\bin` to `PATH` (or call the `.cmd` by full path).
- Use `codex-status-wrapper` to start Codex with title updates:
  ```powershell
  codex-status-wrapper
  ```
  Full path variant:
  ```powershell
  & "$env:USERPROFILE\.local\bin\codex-status-wrapper.cmd"
  ```

Option B (preferred: wrap `codex` automatically):
- Ensure `%USERPROFILE%\.local\bin\priority` is in `PATH` so `codex` resolves to `codex.cmd` shim.
- Verify:
  ```powershell
  Get-Command codex
  Get-Command codex-status
  wezterm cli list
  ```
- Run:
  ```powershell
  codex
  ```
  If `Get-Command codex` still points to the original `codex`, keep using `codex-status-wrapper` or prepend paths in `$PROFILE`.

PowerShell profile tip (optional, session-only or persistent):
- Session-only:
  ```powershell
  $env:PATH = "$env:USERPROFILE\.local\bin\priority;$env:USERPROFILE\.local\bin;$env:PATH"
  ```
- Persistent (User):
  ```powershell
  $u = [Environment]::GetEnvironmentVariable("Path","User")
  $p = "$env:USERPROFILE\.local\bin\priority;$env:USERPROFILE\.local\bin"
  [Environment]::SetEnvironmentVariable("Path", "$p;$u", "User")
  ```

## Usage
- Linux/WSL/macOS: recommended `codex` (after you added `~/.local/bin/priority` to `PATH`) or `codex-done` (explicit wrapper).
- Windows (WezTerm + PowerShell): recommended `codex` (after you added `%USERPROFILE%\.local\bin\priority` to `PATH`) or `codex-status-wrapper`.
- Manual watching:
  - `codex-status --watch --title`
  - `codex-status --watch --json`

## Configuration (env vars)
Linux/macOS (set in `~/.zshrc` / `~/.bashrc`) and Windows PowerShell (set in `$PROFILE` or via `[Environment]::SetEnvironmentVariable(...,"User")`):
- `CODEX_STATUS_ICON_STYLE`: `shape` (default) or `emoji`
- `CODEX_STATUS_OSC`: `0` (default) or `2` (some terminals prefer window title only)
- `CODEX_STATUS_WEZTERM_MODE`: `auto` (default), `off`, `tab`, `window`, `window-active`
- `CODEX_STATUS_INTERVAL_S`: sample interval seconds (default `2`)
- `CODEX_STATUS_WAIT_S`: how long `codex-status-bg` waits for Codex on that TTY (default `10`)
- `CODEX_STATUS_THINKING_S`: pending→Think threshold (default `5`)
- `CODEX_STATUS_IDLE_S`: pending→Idle threshold (default `30`)
- `CODEX_STATUS_MODEL_STUCK_S`: pending→Stuck threshold (default `900`)
- `CODEX_STATUS_PENDING_REFRESH_S`: session parsing refresh seconds (default `2`)

Note: `CODEX_STATUS_WAIT_S` only affects `codex-status-bg` (Linux/WSL/macOS shell hook flow).

## File layout
- `install.sh`: installs everything into `~/.local/*`
- `install.ps1`: installs everything into `%USERPROFILE%\.local\*` (Windows WezTerm)
- `bin/codex-status`: CLI viewer (`--watch`, `--json`, `--detail`, `--title`)
- `bin/codex-status-bg`: per-TTY background title updater (used by shell hooks)
- `bin/codex-status-wrapper`: runs `codex` with title updates (optional)
- `bin/codex-done`: starts Codex with `CODEX_DONE` injection (recommended wrapper)
- `bin/codex-ccbdone`: alternative wrapper using `CCB_DONE`
- `bin/codex-wrapper`: installed as `~/.local/bin/priority/codex` (transparent injection)
- `lib/monitor.py`: status detection (process + session file parsing)
- `lib/renderer.py`: title/status rendering + OSC writer
- `lib/shell_hook.zsh`, `lib/shell_hook.bash`: auto-start `codex-status-bg`
- `config/*.txt`: instruction templates installed to `~/.local/share/codex-status/`

## Uninstall
Linux/macOS/WSL remove:
- `~/.local/bin/codex-status*`, `~/.local/bin/codex-done`, `~/.local/bin/codex-ccbdone`
- `~/.local/bin/priority/codex`
- `~/.local/lib/codex-status/`
- `~/.local/share/codex-status/`
- `~/.cache/codex-status/`

Windows remove:
- `%USERPROFILE%\.local\bin\codex-status*` and `*.cmd`
- `%USERPROFILE%\.local\bin\priority\codex.cmd`
- `%USERPROFILE%\.local\lib\codex-status\`
- `%USERPROFILE%\.local\share\codex-status\`
- `%USERPROFILE%\.cache\codex-status\`

