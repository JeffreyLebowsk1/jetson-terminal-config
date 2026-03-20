#!/usr/bin/env bash
set -euo pipefail
# ── Tmux Dev Layout ──────────────────────────────────────────────────
# Creates a standard development tmux session with:
#   Pane 0: main shell (editor/work)
#   Pane 1: logs (docker-compose logs)
#   Pane 2: GPU/system monitor
#   Pane 3: small shell for quick commands

SESSION="dev"

if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "Session '$SESSION' already exists. Attaching..."
    tmux attach -t "$SESSION"
    exit 0
fi

# Create session with main pane
tmux new-session -d -s "$SESSION" -n work

# Split right: logs pane (40% width)
tmux split-window -h -t "$SESSION:work" -l '40%'

# Split the right pane vertically: GPU monitor on top, quick shell on bottom
tmux split-window -v -t "$SESSION:work.1" -l '50%'

# Start docker logs in top-right pane
tmux send-keys -t "$SESSION:work.1" 'docker compose logs -f --tail=30 2>/dev/null || echo "No compose project running"' C-m

# Start GPU watch in bottom-right pane
tmux send-keys -t "$SESSION:work.2" 'watch -n 2 "nvidia-smi 2>/dev/null || cat /sys/devices/gpu.0/load 2>/dev/null || echo No GPU info"' C-m

# Focus main pane
tmux select-pane -t "$SESSION:work.0"

# Attach
tmux attach -t "$SESSION"
