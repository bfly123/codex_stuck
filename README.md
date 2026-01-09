<div align="center">

# codex_stuck

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Platform](https://img.shields.io/badge/platform-Linux%20|%20macOS%20|%20Windows%20|%20WSL-lightgrey)
![License](https://img.shields.io/badge/license-MIT-green)

**Detect whether Codex is running or stuck.**

*Have you ever experienced Codex running for a long time with no response, wanting to kill it but afraid it's still working silently?*

[English](README.md) | [中文](README_zh.md)

![demo](images/demo.gif)

</div>

---

## Core Idea

> A **lightweight** terminal status display plugin for Codex.

It determines whether Codex is stuck by monitoring:
- Session file status
- Traffic changes
- Silence duration

This plugin was created not only for easily detecting Codex status, but also as a monitor for fully automated operation of **[cca](https://github.com/bfly123/claude_code_autoflow)** and **[ccb](https://github.com/bfly123/claude_code_bridge)**.

### Solution

1. Inject completion markers (`CODEX_DONE`) into Codex prompts
2. Monitor session files (`~/.codex/sessions/*.jsonl`) to detect state
3. Display status in terminal title via OSC sequences

---

## Status Icons

| Icon | Status | Meaning |
|:---:|:---|:---|
| `▶` | **Run** | Producing output |
| `▷` | **Think** | Pending, low activity |
| `◇` | **Idle** | Long quiet period |
| `□` | **Free** | Waiting for input |
| `■` | **Stuck** | Very long quiet |
| `×` | **Exit** | Process exited |

---

## Installation

### Linux / macOS / WSL

```bash
./install.sh
```

> Auto-configures shell (zsh/bash). Restart terminal after install.

### Windows (PowerShell)

```powershell
.\install.ps1
```

> Auto-configures PATH. Restart terminal after install.

---

## Usage

After installation, just run:

```bash
codex
```

The terminal title will show **real-time status**.

---

## Uninstall

```bash
./uninstall.sh      # Linux/macOS/WSL
.\uninstall.ps1     # Windows
```

---

## Configuration (optional)

| Variable | Default | Description |
|:---|:---:|:---|
| `CODEX_STATUS_ICON_STYLE` | `shape` | `shape` or `emoji` |
| `CODEX_STATUS_INTERVAL_S` | `2` | Sample interval (seconds) |
| `CODEX_STATUS_MODEL_STUCK_S` | `900` | Stuck threshold (seconds) |

---

<div align="center">

**Related Projects**: [cca](https://github.com/bfly123/claude_code_autoflow) | [ccb](https://github.com/bfly123/claude_code_bridge)

</div>
