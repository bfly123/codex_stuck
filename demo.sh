#!/bin/bash
# Demo script: cycle through all codex-status states for video recording
# Run this in a separate terminal while codex is running

set -e

# Short thresholds for demo
export CODEX_STATUS_THINKING_S=3
export CODEX_STATUS_IDLE_S=8
export CODEX_STATUS_MODEL_STUCK_S=15

echo "======================================"
echo "  codex-status Demo Controller"
echo "======================================"
echo ""
echo "Before running this script:"
echo "  1. Open another terminal"
echo "  2. Set these env vars:"
echo "     export CODEX_STATUS_THINKING_S=3"
echo "     export CODEX_STATUS_IDLE_S=8"
echo "     export CODEX_STATUS_MODEL_STUCK_S=15"
echo "  3. Run: codex"
echo "  4. Send a message to codex (e.g. 'hello')"
echo ""
read -p "Press Enter when codex is running and has responded..."

find_codex_pid() {
    pgrep -f "@openai/codex" 2>/dev/null | head -1
}

PID=$(find_codex_pid)
if [ -z "$PID" ]; then
    echo "Error: codex process not found"
    exit 1
fi

echo ""
echo "Found codex PID: $PID"
echo ""
echo "Starting demo cycle... (Ctrl+C to stop)"
echo ""

cycle=1
while true; do
    echo "===== Cycle $cycle ====="

    # Verify process still exists
    PID=$(find_codex_pid)
    if [ -z "$PID" ]; then
        echo "Codex process ended. Waiting for restart..."
        while [ -z "$PID" ]; do
            sleep 1
            PID=$(find_codex_pid)
        done
        echo "Found new codex PID: $PID"
    fi

    # State 1: STUCK (via SIGSTOP)
    echo "[1/5] ■ STUCK - Sending SIGSTOP..."
    kill -STOP $PID 2>/dev/null || true
    sleep 5

    # Resume
    echo "      Resuming process..."
    kill -CONT $PID 2>/dev/null || true
    sleep 1

    # State 2: RUN (process active)
    echo "[2/5] ▶ RUN - Process active (send a message in codex now!)"
    echo "      Waiting 4 seconds..."
    sleep 4

    # State 3: THINK (short silence)
    echo "[3/5] ▷ THINK - Waiting for think threshold (3s silence)..."
    sleep 5

    # State 4: IDLE (longer silence)
    echo "[4/5] ◇ IDLE - Waiting for idle threshold (8s silence)..."
    sleep 6

    # State 5: FREE (after model responds)
    echo "[5/5] □ FREE - Model should have responded by now"
    echo "      (If still showing other state, send another message)"
    sleep 4

    echo ""
    cycle=$((cycle + 1))

    read -p "Press Enter to run next cycle, or Ctrl+C to exit..."
    echo ""
done
