#!/bin/bash
# Auto demo: automatically cycles through states with visual countdown
# Just run codex in another terminal, this script handles the rest

THINK_S=3
IDLE_S=8
STUCK_S=15

find_codex_pid() {
    pgrep -f "@openai/codex" 2>/dev/null | head -1
}

countdown() {
    local secs=$1
    local msg=$2
    while [ $secs -gt 0 ]; do
        printf "\r  %s (%ds remaining)   " "$msg" "$secs"
        sleep 1
        secs=$((secs - 1))
    done
    printf "\r  %s - done!              \n" "$msg"
}

clear
echo "╔══════════════════════════════════════════════════════╗"
echo "║         codex-status Auto Demo                       ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  States to show:                                     ║"
echo "║    ▶ Run    - Active processing                      ║"
echo "║    ▷ Think  - Pending, low activity (${THINK_S}s)            ║"
echo "║    ◇ Idle   - Long quiet period (${IDLE_S}s)                ║"
echo "║    ■ Stuck  - Very long wait / stopped (${STUCK_S}s)         ║"
echo "║    □ Free   - Waiting for input                      ║"
echo "║    × Exit   - Process ended                          ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "SETUP: In another terminal, run:"
echo ""
echo "  export CODEX_STATUS_THINKING_S=$THINK_S"
echo "  export CODEX_STATUS_IDLE_S=$IDLE_S"
echo "  export CODEX_STATUS_MODEL_STUCK_S=$STUCK_S"
echo "  codex"
echo ""
read -p "Press Enter when codex is running..."

PID=$(find_codex_pid)
if [ -z "$PID" ]; then
    echo "Error: No codex process found!"
    exit 1
fi

echo ""
echo "Found codex (PID: $PID)"
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Starting demo... Watch the terminal title!"
echo "═══════════════════════════════════════════════════════"
echo ""

while true; do
    PID=$(find_codex_pid)
    if [ -z "$PID" ]; then
        echo "⚠ Codex exited. Restart codex and press Enter..."
        read
        PID=$(find_codex_pid)
        [ -z "$PID" ] && continue
    fi

    echo "▶ [RUN] Send a message to codex now!"
    echo "  (e.g. type 'explain this code' or any question)"
    sleep 6

    echo ""
    echo "▷ [THINK] Waiting ${THINK_S}s for think state..."
    countdown $THINK_S "Think state"

    echo ""
    echo "◇ [IDLE] Waiting $((IDLE_S - THINK_S))s more for idle state..."
    countdown $((IDLE_S - THINK_S)) "Idle state"

    echo ""
    echo "■ [STUCK] Stopping process to simulate stuck..."
    kill -STOP $PID 2>/dev/null
    countdown 5 "Stuck state (SIGSTOP)"
    kill -CONT $PID 2>/dev/null
    echo "  Process resumed"

    echo ""
    echo "□ [FREE] Should show Free if model has responded"
    sleep 3

    echo ""
    echo "× [EXIT] Killing codex to show exit state..."
    kill $PID 2>/dev/null
    sleep 3

    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Cycle complete! All states demonstrated."
    echo "═══════════════════════════════════════════════════════"
    echo ""
    read -p "Press Enter to restart codex and run another cycle, or Ctrl+C to quit..."

    echo ""
    echo "Please start codex again in the other terminal..."
    read -p "Press Enter when ready..."
done
