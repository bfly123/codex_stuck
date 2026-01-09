#!/usr/bin/env python3
"""Core monitoring logic for Codex CLI status detection."""

import os
import re
import json
import time
import subprocess
from pathlib import Path
from dataclasses import dataclass
from typing import Optional, Dict, Any, List, Tuple
from enum import Enum
from datetime import datetime


class State(Enum):
    STARTING = "starting"
    RUNNING = "running"
    THINKING = "thinking"
    FREE = "free"
    IDLE = "idle"
    STUCK = "stuck"
    EXITED = "exited"


@dataclass
class CodexStatus:
    state: State = State.STARTING
    pid: Optional[int] = None
    elapsed_s: float = 0
    silence_s: float = 0
    task_s: float = 0  # seconds since current request started (if pending)
    cpu_delta: float = 0
    io_read_delta: int = 0
    io_write_delta: int = 0
    last_tool: Optional[str] = None
    current_step: Optional[str] = None
    plan_progress: Optional[str] = None  # e.g. "3/5"
    error: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "state": self.state.value,
            "pid": self.pid,
            "elapsed_s": self.elapsed_s,
            "silence_s": self.silence_s,
            "task_s": self.task_s,
            "cpu_delta": self.cpu_delta,
            "io_read_delta": self.io_read_delta,
            "io_write_delta": self.io_write_delta,
            "last_tool": self.last_tool,
            "current_step": self.current_step,
            "plan_progress": self.plan_progress,
            "error": self.error,
            "timestamp": time.time(),
        }


class ProcSampler:
    """Sample process metrics from /proc when available, otherwise via `ps`.

    This keeps the monitor usable on macOS (no /proc by default) and WSL.
    """

    def __init__(self, pid: int):
        self.pid = pid
        self._last_cpu = 0.0
        self._last_io_r = 0
        self._last_io_w = 0
        self._clk_tck = os.sysconf("SC_CLK_TCK") if hasattr(os, "sysconf") else 100
        self._has_procfs = Path("/proc").is_dir() and Path(f"/proc/{self.pid}").exists()
        self._is_windows = os.name == "nt"

    def is_alive(self) -> bool:
        if self._has_procfs:
            return Path(f"/proc/{self.pid}").exists()
        if self._is_windows:
            try:
                out = subprocess.run(
                    ["tasklist", "/FI", f"PID eq {self.pid}"],
                    capture_output=True,
                    text=True,
                ).stdout
                return str(self.pid) in out
            except Exception:
                return False
        try:
            os.kill(self.pid, 0)
            return True
        except OSError:
            return False

    def get_state(self) -> Optional[str]:
        if self._has_procfs:
            try:
                stat = Path(f"/proc/{self.pid}/stat").read_text()
                # Format: pid (comm) state ...
                match = re.search(r"\)\s+(\S)", stat)
                return match.group(1) if match else None
            except Exception:
                return None
        if self._is_windows:
            return None
        try:
            out = subprocess.run(
                ["ps", "-p", str(self.pid), "-o", "state="],
                capture_output=True,
                text=True,
            ).stdout.strip()
            return out[:1] if out else None
        except Exception:
            return None

    def _parse_ps_time_to_seconds(self, s: str) -> float:
        s = (s or "").strip()
        if not s:
            return 0.0
        # Common formats:
        # - [[dd-]hh:]mm:ss
        # - hh:mm:ss
        # - mm:ss
        days = 0
        if "-" in s:
            d, rest = s.split("-", 1)
            try:
                days = int(d)
            except Exception:
                days = 0
            s = rest
        parts = s.split(":")
        try:
            parts_i = [int(p) for p in parts]
        except Exception:
            return 0.0
        if len(parts_i) == 3:
            h, m, sec = parts_i
        elif len(parts_i) == 2:
            h, m, sec = 0, parts_i[0], parts_i[1]
        else:
            return 0.0
        return float(days * 86400 + h * 3600 + m * 60 + sec)

    def sample_cpu(self) -> float:
        """Returns CPU time delta since last sample."""
        if self._has_procfs:
            try:
                stat = Path(f"/proc/{self.pid}/stat").read_text()
                parts = stat.rsplit(")", 1)[1].split()
                utime = int(parts[11])
                stime = int(parts[12])
                cpu_s = (utime + stime) / self._clk_tck
                delta = cpu_s - self._last_cpu
                self._last_cpu = cpu_s
                return max(0, delta)
            except Exception:
                return 0.0
        if self._is_windows:
            return 0.0
        try:
            # BSD/Linux: `ps ... -o time=` gives total CPU time.
            out = subprocess.run(
                ["ps", "-p", str(self.pid), "-o", "time="],
                capture_output=True,
                text=True,
            ).stdout.strip()
            cpu_s = self._parse_ps_time_to_seconds(out)
            delta = cpu_s - self._last_cpu
            self._last_cpu = cpu_s
            return max(0.0, delta)
        except Exception:
            return 0.0

    def sample_io(self) -> Tuple[int, int]:
        """Returns (read_bytes_delta, write_bytes_delta)."""
        if not self._has_procfs:
            return 0, 0
        try:
            io_text = Path(f"/proc/{self.pid}/io").read_text()
            io_map = {}
            for line in io_text.splitlines():
                if ":" in line:
                    k, v = line.split(":", 1)
                    io_map[k.strip()] = int(v.strip())

            r = io_map.get("read_bytes", 0)
            w = io_map.get("write_bytes", 0)

            delta_r = max(0, r - self._last_io_r)
            delta_w = max(0, w - self._last_io_w)

            self._last_io_r = r
            self._last_io_w = w

            return delta_r, delta_w
        except Exception:
            return 0, 0


class LogWatcher:
    """Watch and parse Codex log file."""

    TOOL_CALL_RE = re.compile(r'ToolCall:\s+(\w+)\s+(.*)$')
    UPDATE_PLAN_RE = re.compile(r'"plan":\s*\[(.*?)\]', re.DOTALL)

    def __init__(self, log_path: Optional[Path] = None):
        self.log_path = log_path or Path.home() / ".codex/log/codex-tui.log"
        self._last_size = 0
        self._last_mtime = 0.0
        self.last_tool: Optional[str] = None
        self.current_step: Optional[str] = None
        self.plan_progress: Optional[str] = None

    def check_activity(self) -> bool:
        """Returns True if log has new content."""
        try:
            stat = self.log_path.stat()
            if stat.st_size > self._last_size or stat.st_mtime > self._last_mtime:
                self._parse_new_content(self._last_size, stat.st_size)
                self._last_size = stat.st_size
                self._last_mtime = stat.st_mtime
                return True
            return False
        except Exception:
            return False

    def get_silence_s(self) -> float:
        """Returns seconds since last log activity."""
        try:
            mtime = self.log_path.stat().st_mtime
            return time.time() - mtime
        except Exception:
            return 0.0

    def _parse_new_content(self, start: int, end: int):
        """Parse new log content for ToolCall and plan updates."""
        try:
            with open(self.log_path, 'r', errors='replace') as f:
                f.seek(start)
                content = f.read(end - start)

            # Find last ToolCall
            for match in self.TOOL_CALL_RE.finditer(content):
                self.last_tool = match.group(1)

            # Find last update_plan
            if "update_plan" in content:
                self._parse_plan(content)
        except Exception:
            pass

    def _parse_plan(self, content: str):
        """Extract current step and progress from update_plan."""
        try:
            # Find the last update_plan occurrence
            idx = content.rfind("update_plan")
            if idx == -1:
                return

            snippet = content[idx:idx+2000]

            # Parse plan array
            match = self.UPDATE_PLAN_RE.search(snippet)
            if not match:
                return

            plan_content = "[" + match.group(1) + "]"
            # Fix common JSON issues
            plan_content = re.sub(r',\s*]', ']', plan_content)

            try:
                steps = json.loads(plan_content)
            except json.JSONDecodeError:
                return

            completed = 0
            in_progress = None
            total = len(steps)

            for step in steps:
                status = step.get("status", "")
                if status == "completed":
                    completed += 1
                elif status == "in_progress" and not in_progress:
                    in_progress = step.get("step", "")[:50]

            self.current_step = in_progress
            self.plan_progress = f"{completed}/{total}"
        except Exception:
            pass


class CodexMonitor:
    """Main monitor combining process sampling and log watching."""

    # Thresholds
    CPU_ACTIVE_S = 0.05
    FREE_SILENCE_S = 2
    D_STUCK_S = 10
    MODEL_STUCK_S = 900
    PENDING_REFRESH_S = 2
    THINKING_S = 5
    IDLE_S = 30

    def __init__(self, pid: Optional[int] = None, start_cwd: Optional[str] = None):
        self.pid = pid
        self.start_cwd = start_cwd
        self.sampler: Optional[ProcSampler] = None
        self.log_watcher = LogWatcher()
        self.start_time = time.time()
        self._silence_start = time.time()
        self._d_start: Optional[float] = None
        self._session_id: Optional[str] = None
        self._session_file: Optional[Path] = None
        self._pending_cached: Optional[bool] = None
        self._req_started_at_cached: float = 0.0
        self._last_user_ts_cached: float = 0.0
        self._last_done_ts_cached: float = 0.0
        self._last_abort_ts_cached: float = 0.0
        self._pending_checked_at: float = 0.0
        self.MODEL_STUCK_S = int(os.getenv("CODEX_STATUS_MODEL_STUCK_S", str(self.MODEL_STUCK_S)))
        self.PENDING_REFRESH_S = int(os.getenv("CODEX_STATUS_PENDING_REFRESH_S", str(self.PENDING_REFRESH_S)))
        self.THINKING_S = int(os.getenv("CODEX_STATUS_THINKING_S", str(self.THINKING_S)))
        self.IDLE_S = int(os.getenv("CODEX_STATUS_IDLE_S", str(self.IDLE_S)))

    def _read_cmdline(self, pid: int) -> str:
        if Path("/proc").is_dir():
            try:
                return Path(f"/proc/{pid}/cmdline").read_text(errors="replace").replace("\x00", " ")
            except Exception:
                pass
        try:
            return subprocess.run(
                ["ps", "-p", str(pid), "-o", "command="],
                capture_output=True,
                text=True,
            ).stdout.strip()
        except Exception:
            return ""

    def _process_start_epoch(self, pid: int) -> int:
        now = int(time.time())
        if os.name == "nt":
            return now - 3600
        # Linux: seconds since start.
        try:
            out = subprocess.run(
                ["ps", "-p", str(pid), "-o", "etimes="],
                capture_output=True,
                text=True,
            ).stdout.strip()
            if out.isdigit():
                return now - int(out)
        except Exception:
            pass
        # BSD: elapsed time string.
        try:
            out = subprocess.run(
                ["ps", "-p", str(pid), "-o", "etime="],
                capture_output=True,
                text=True,
            ).stdout.strip()
            secs = ProcSampler(pid)._parse_ps_time_to_seconds(out)  # reuse parser
            if secs > 0:
                return now - int(secs)
        except Exception:
            pass
        return now - 3600

    def _find_session_file_by_cwd(self, start_cwd: str, since_epoch: int) -> Optional[Path]:
        sessions_root = Path.home() / ".codex" / "sessions"
        if not sessions_root.exists():
            return None

        try:
            cwd_norm = os.path.realpath(start_cwd)
        except Exception:
            cwd_norm = start_cwd

        items: List[Tuple[float, Path]] = []
        try:
            for p in sessions_root.rglob("*.jsonl"):
                try:
                    st = p.stat()
                except Exception:
                    continue
                if st.st_mtime < since_epoch - 5:
                    continue
                items.append((st.st_mtime, p))
        except Exception:
            return None

        items.sort(reverse=True, key=lambda t: t[0])
        for _, p in items[:300]:
            try:
                with p.open("r", errors="replace") as f:
                    first = f.readline().strip()
                if not first:
                    continue
                obj = json.loads(first)
                if obj.get("type") != "session_meta":
                    continue
                payload = obj.get("payload") or {}
                meta_cwd = payload.get("cwd") or ""
                if not meta_cwd:
                    continue
                if os.path.realpath(meta_cwd) == cwd_norm:
                    return p
            except Exception:
                continue
        return None

    def _detect_session_file(self, pid: int) -> Optional[Path]:
        cmdline = self._read_cmdline(pid)
        if not cmdline:
            if self.start_cwd:
                return self._find_session_file_by_cwd(self.start_cwd, self._process_start_epoch(pid))
            return None

        ids = re.findall(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", cmdline)
        if not ids:
            if self.start_cwd:
                return self._find_session_file_by_cwd(self.start_cwd, self._process_start_epoch(pid))
            return None

        sid = ids[-1]
        if sid == self._session_id and self._session_file and self._session_file.exists():
            return self._session_file

        sessions_root = Path.home() / ".codex" / "sessions"
        if not sessions_root.exists():
            return None

        candidates = list(sessions_root.rglob(f"*{sid}.jsonl"))
        if not candidates:
            return None

        best = max(candidates, key=lambda p: p.stat().st_mtime)
        self._session_id = sid
        self._session_file = best
        self._pending_cached = None
        self._pending_checked_at = 0.0
        return best

    def _parse_ts(self, ts: str) -> Optional[float]:
        try:
            if ts.endswith("Z"):
                ts = ts[:-1] + "+00:00"
            return datetime.fromisoformat(ts).timestamp()
        except Exception:
            return None

    def _session_observe(self, session_file: Path) -> Tuple[float, float, float]:
        try:
            size = session_file.stat().st_size
            start = max(0, size - 1024 * 1024)
            with session_file.open("r", errors="replace") as f:
                f.seek(start)
                chunk = f.read()
        except Exception:
            return 0.0, 0.0, 0.0

        last_user: float = 0.0
        last_turn_aborted: float = 0.0
        last_done: float = 0.0

        done_re = re.compile(r"^(?:CCB_DONE|CODEX_DONE)(?::\s*[0-9a-f]{32})?$")

        for line in chunk.splitlines()[-5000:]:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except Exception:
                continue

            ts = self._parse_ts(obj.get("timestamp", ""))
            if ts is None:
                continue

            typ = obj.get("type")
            payload = obj.get("payload") or {}

            if typ == "event_msg" and payload.get("type") == "turn_aborted":
                last_turn_aborted = max(last_turn_aborted, ts)

            if typ == "response_item":
                role = (payload.get("role") or "").lower()
                if role == "user":
                    last_user = max(last_user, ts)

                content = payload.get("content") or []
                if isinstance(content, list):
                    text = "\n".join(
                        (part.get("text", "") for part in content if isinstance(part, dict) and part.get("type") in ("input_text", "output_text"))
                    )
                    if role == "assistant":
                        last_nonempty = ""
                        for ln in reversed(text.splitlines()):
                            ln = ln.strip()
                            if ln:
                                last_nonempty = ln
                                break
                        if last_nonempty and done_re.match(last_nonempty):
                            last_done = max(last_done, ts)

            if typ == "event_msg":
                ptype = payload.get("type")
                if ptype == "user_message":
                    last_user = max(last_user, ts)

        return float(last_user), float(last_done), float(last_turn_aborted)

    def _get_session_state(self, now: float, pid: int) -> Optional[Tuple[bool, float, Path]]:
        session_file = self._detect_session_file(pid)
        if not session_file:
            return None

        if self._pending_cached is None or (now - self._pending_checked_at) >= self.PENDING_REFRESH_S:
            obs_user_ts, obs_done_ts, obs_abort_ts = self._session_observe(session_file)

            if obs_user_ts > 0 and obs_user_ts > self._last_user_ts_cached:
                self._last_user_ts_cached = obs_user_ts
                self._req_started_at_cached = obs_user_ts
                self._pending_cached = True

            if obs_done_ts > 0 and obs_done_ts > self._last_done_ts_cached:
                self._last_done_ts_cached = obs_done_ts

            if obs_abort_ts > 0 and obs_abort_ts > self._last_abort_ts_cached:
                self._last_abort_ts_cached = obs_abort_ts

            if self._pending_cached is None:
                # Initial fill
                self._last_user_ts_cached = max(self._last_user_ts_cached, obs_user_ts)
                self._last_done_ts_cached = max(self._last_done_ts_cached, obs_done_ts)
                self._last_abort_ts_cached = max(self._last_abort_ts_cached, obs_abort_ts)
                self._req_started_at_cached = self._last_user_ts_cached

                if self._last_user_ts_cached > 0 and self._last_user_ts_cached > self._last_done_ts_cached:
                    self._pending_cached = True
                else:
                    self._pending_cached = False

            if self._last_user_ts_cached > 0:
                if self._last_done_ts_cached > self._last_user_ts_cached:
                    self._pending_cached = False
                if self._last_abort_ts_cached > self._last_user_ts_cached:
                    self._pending_cached = False
            self._pending_checked_at = now

        return self._pending_cached, self._req_started_at_cached, session_file

    def find_codex_pid(self) -> Optional[int]:
        """Find running Codex process."""
        if os.name == "nt":
            try:
                cmd = (
                    "Get-CimInstance Win32_Process | "
                    "Where-Object { $_.CommandLine -match '@openai/codex/vendor' -and $_.CommandLine -match 'codex' } | "
                    "Select-Object -First 1 -ExpandProperty ProcessId"
                )
                out = subprocess.run(
                    ["powershell", "-NoProfile", "-Command", cmd],
                    capture_output=True,
                    text=True,
                ).stdout.strip()
                return int(out) if out.isdigit() else None
            except Exception:
                return None
        try:
            result = subprocess.run(
                ["pgrep", "-f", "@openai/codex/vendor.*codex"],
                capture_output=True, text=True
            )
            pids = result.stdout.strip().split('\n')
            if pids and pids[0]:
                return int(pids[0])
        except Exception:
            pass
        try:
            # Fallback: scan `ps` output.
            out = subprocess.run(
                ["ps", "ax", "-o", "pid=,command="],
                capture_output=True,
                text=True,
            ).stdout.splitlines()
            for line in out:
                line = line.strip()
                if not line:
                    continue
                if "@openai/codex/vendor" in line and "codex" in line:
                    try:
                        return int(line.split(None, 1)[0])
                    except Exception:
                        continue
        except Exception:
            pass
        return None

    def sample(self) -> CodexStatus:
        """Take a single status sample."""
        status = CodexStatus()
        status.elapsed_s = time.time() - self.start_time

        # Find or verify PID
        if self.pid is None:
            self.pid = self.find_codex_pid()

        if self.pid is None:
            status.state = State.EXITED
            return status

        status.pid = self.pid

        # Initialize sampler
        if self.sampler is None:
            self.sampler = ProcSampler(self.pid)

        # Check if alive
        if not self.sampler.is_alive():
            status.state = State.EXITED
            self.pid = None
            self.sampler = None
            return status

        # Sample metrics
        status.cpu_delta = self.sampler.sample_cpu()
        status.io_read_delta, status.io_write_delta = self.sampler.sample_io()
        proc_state = self.sampler.get_state()

        # Check log activity
        log_active = self.log_watcher.check_activity()
        status.last_tool = self.log_watcher.last_tool
        status.current_step = self.log_watcher.current_step
        status.plan_progress = self.log_watcher.plan_progress

        now = time.time()
        session_state = self._get_session_state(now, self.pid) if self.pid else None
        pending_user = session_state[0] if session_state else None
        req_started_at = session_state[1] if session_state else 0.0
        session_file = session_state[2] if session_state else None

        if pending_user:
            status.task_s = max(0.0, now - float(req_started_at or 0.0))
        else:
            status.task_s = 0.0

        # Determine activity: keep this process-local (global logs may include other sessions).
        has_activity = (
            status.cpu_delta >= self.CPU_ACTIVE_S or
            status.io_read_delta > 0 or
            status.io_write_delta > 0
        )

        if has_activity:
            self._silence_start = time.time()

        status.silence_s = time.time() - self._silence_start

        # Determine state
        if proc_state == "D":
            if self._d_start is None:
                self._d_start = now
        else:
            self._d_start = None

        if proc_state == "Z":
            status.state = State.EXITED
        elif proc_state == "T":
            status.state = State.STUCK
        elif self._d_start is not None and (now - self._d_start) >= self.D_STUCK_S:
            status.state = State.STUCK
        elif pending_user is True and session_file:
            try:
                sess_silence = now - session_file.stat().st_mtime
            except Exception:
                sess_silence = 0.0
            if self.MODEL_STUCK_S > 0 and sess_silence >= self.MODEL_STUCK_S and not has_activity:
                status.state = State.STUCK
            elif self.IDLE_S > 0 and sess_silence >= self.IDLE_S and not has_activity:
                status.state = State.IDLE
            elif self.THINKING_S > 0 and sess_silence >= self.THINKING_S and not has_activity:
                status.state = State.THINKING
            else:
                status.state = State.RUNNING
        elif pending_user is False and not has_activity and status.silence_s >= self.FREE_SILENCE_S:
            status.state = State.FREE
        else:
            status.state = State.RUNNING

        return status


def format_duration(seconds: float) -> str:
    """Format seconds as human-readable duration."""
    seconds = int(seconds)
    if seconds < 60:
        return f"{seconds}s"
    m, s = divmod(seconds, 60)
    if m < 60:
        return f"{m}m{s}s"
    h, m = divmod(m, 60)
    return f"{h}h{m}m"


def format_bytes(n: int) -> str:
    """Format bytes as human-readable size."""
    for unit in ["B", "K", "M", "G"]:
        if n < 1024:
            return f"{n:.0f}{unit}" if n == int(n) else f"{n:.1f}{unit}"
        n /= 1024
    return f"{n:.1f}T"
