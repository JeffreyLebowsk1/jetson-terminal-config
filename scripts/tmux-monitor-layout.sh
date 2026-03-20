#!/usr/bin/env bash
set -euo pipefail
# ── Tmux Monitor Layout ──────────────────────────────────────────────
# Monitoring-focused tmux session:
#   Pane 0: jetson-health --watch
#   Pane 1: docker stats
#   Pane 2: tegrastats or nvtop

SESSION="monitor"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "Session '$SESSION' already exists. Attaching..."
    tmux attach -t "$SESSION"
    exit 0
fi

tmux new-session -d -s "$SESSION" -n dash

# Top-left: Jetson health dashboard
tmux send-keys -t "$SESSION:dash" "bash $SCRIPTS_DIR/jetson-health.sh --watch" C-m

# Right pane: docker stats
tmux split-window -h -t "$SESSION:dash" -l '50%'
tmux send-keys -t "$SESSION:dash.1" 'docker stats 2>/dev/null || echo "Docker not available"' C-m

# Bottom-right: tegrastats or nvtop
tmux split-window -v -t "$SESSION:dash.1" -l '50%'
if command -v nvtop &>/dev/null; then
    tmux send-keys -t "$SESSION:dash.2" 'nvtop' C-m
else
    tmux send-keys -t "$SESSION:dash.2" 'sudo tegrastats 2>/dev/null || echo "tegrastats not available"' C-m
fi

tmux select-pane -t "$SESSION:dash.0"
tmux attach -t "$SESSION"
