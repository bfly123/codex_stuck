#!/usr/bin/env python3
"""Status rendering for terminal title and text output."""

import os
import sys
from typing import Optional, TextIO
try:
    from .monitor import CodexStatus, State, format_duration, format_bytes
except ImportError:
    from monitor import CodexStatus, State, format_duration, format_bytes


# State icons and colors
ICON_STYLE = os.environ.get("CODEX_STATUS_ICON_STYLE", "shape").lower()

ICON_SETS = {
    "emoji": {
        State.STARTING: "⚪",
        State.RUNNING: "🟢",
        State.THINKING: "🟡",
        State.FREE: "🔵",
        State.IDLE: "🟠",
        State.STUCK: "🔴",
        State.EXITED: "⚫",
    },
    "shape": {
        State.STARTING: "○",
        State.RUNNING: "▶",
        State.THINKING: "▷",
        State.FREE: "□",
        State.IDLE: "◇",
        State.STUCK: "■",
        State.EXITED: "×",
    },
}

STATE_ICONS = ICON_SETS.get(ICON_STYLE, ICON_SETS["shape"])

STATE_LABELS = {
    State.STARTING: "Start",
    State.RUNNING: "Run",
    State.THINKING: "Think",
    State.FREE: "Free",
    State.IDLE: "Idle",
    State.STUCK: "Stuck",
    State.EXITED: "Exit",
}

# ANSI colors
COLORS = {
    State.STARTING: "\033[37m",   # white
    State.RUNNING: "\033[32m",    # green
    State.THINKING: "\033[33m",   # yellow
    State.FREE: "\033[34m",       # blue
    State.IDLE: "\033[33m",       # yellow
    State.STUCK: "\033[31m",      # red
    State.EXITED: "\033[90m",     # gray
}
RESET = "\033[0m"


def render_title(status: CodexStatus, prefix: str = "Codex") -> str:
    """Render status as terminal title string."""
    icon = STATE_ICONS.get(status.state, "❓")
    label = STATE_LABELS.get(status.state, "?")

    # Prefer per-request timer (task_s) when running/stuck; omit time for Free.
    if status.state in (State.RUNNING, State.STUCK) and status.task_s > 0:
        elapsed = format_duration(status.task_s)
    elif status.state == State.FREE:
        elapsed = ""
    else:
        elapsed = format_duration(status.elapsed_s)

    parts = [f"{icon} {label}"]
    if elapsed:
        parts.append(elapsed)

    if status.state == State.EXITED:
        return f"{icon} {prefix} Exit"

    if status.plan_progress:
        parts.append(f"[{status.plan_progress}]")

    if status.current_step and len(status.current_step) <= 30:
        parts.append(status.current_step)

    return " ".join(parts)


def render_oneline(status: CodexStatus, color: bool = True) -> str:
    """Render status as single line text."""
    icon = STATE_ICONS.get(status.state, "❓")
    label = STATE_LABELS.get(status.state, "?")

    if color:
        c = COLORS.get(status.state, "")
        state_str = f"{c}{icon} {label}{RESET}"
    else:
        state_str = f"{icon} {label}"

    parts = [state_str]

    if status.state != State.EXITED:
        if status.state in (State.RUNNING, State.STUCK) and status.task_s > 0:
            parts.append(f"run={format_duration(status.task_s)}")
        else:
            parts.append(f"elapsed={format_duration(status.elapsed_s)}")
        parts.append(f"silence={format_duration(status.silence_s)}")

        if status.cpu_delta > 0:
            parts.append(f"cpu+{status.cpu_delta:.2f}s")

        if status.io_read_delta > 0 or status.io_write_delta > 0:
            parts.append(f"io+{format_bytes(status.io_read_delta + status.io_write_delta)}")

        if status.plan_progress:
            parts.append(f"step={status.plan_progress}")

        if status.last_tool:
            parts.append(f"tool={status.last_tool}")

    return " ".join(parts)


def render_detail(status: CodexStatus) -> str:
    """Render detailed multi-line status."""
    icon = STATE_ICONS.get(status.state, "❓")
    label = STATE_LABELS.get(status.state, "?")
    c = COLORS.get(status.state, "")

    lines = [
        f"{c}╭─ Codex Status ─────────────────────────{RESET}",
        f"{c}│{RESET} State:    {icon} {label}",
        f"{c}│{RESET} PID:      {status.pid or 'N/A'}",
        f"{c}│{RESET} Elapsed:  {format_duration(status.elapsed_s)}",
        f"{c}│{RESET} Silence:  {format_duration(status.silence_s)}",
    ]

    if status.cpu_delta > 0:
        lines.append(f"{c}│{RESET} CPU Δ:    +{status.cpu_delta:.2f}s")

    if status.io_read_delta > 0 or status.io_write_delta > 0:
        lines.append(f"{c}│{RESET} IO Δ:     R+{format_bytes(status.io_read_delta)} W+{format_bytes(status.io_write_delta)}")

    if status.plan_progress:
        lines.append(f"{c}│{RESET} Progress: {status.plan_progress}")

    if status.current_step:
        step_display = status.current_step[:40] + "..." if len(status.current_step) > 40 else status.current_step
        lines.append(f"{c}│{RESET} Step:     {step_display}")

    if status.last_tool:
        lines.append(f"{c}│{RESET} LastTool: {status.last_tool}")

    lines.append(f"{c}╰─────────────────────────────────────────{RESET}")

    return "\n".join(lines)


def set_terminal_title(title: str, out: Optional[TextIO] = None) -> None:
    """Set terminal window/tab title using OSC escape sequence."""
    # OSC 0 sets both window and icon title; some terminals/prompts also write OSC 0.
    # Allow overriding via CODEX_STATUS_OSC (e.g. 2 for window title only).
    osc = os.environ.get("CODEX_STATUS_OSC", "0").strip() or "0"
    if not osc.isdigit():
        osc = "0"
    stream = out or sys.stdout
    stream.write(f"\033]{osc};{title}\007")
    stream.flush()


def update_title_with_status(status: CodexStatus, prefix: str = "Codex", out: Optional[TextIO] = None) -> None:
    """Update terminal title with current status."""
    title = render_title(status, prefix)
    set_terminal_title(title, out=out)
