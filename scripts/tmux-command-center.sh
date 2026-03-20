#!/usr/bin/env bash
set -euo pipefail
# ── Jetson Command Center ─────────────────────────────────────────────
# A tmux session with fixed panes for daily work:
#
#   ┌──────────────────────┬──────────────────┐
#   │                      │  Git Dashboard   │
#   │     Terminal         │                  │
#   │     (main)           ├──────────────────┤
#   │                      │  System Health   │
#   ├──────────────────────┤                  │
#   │  Quick Reference     ├──────────────────┤
#   │                      │  Docker Status   │
#   └──────────────────────┴──────────────────┘
#
# Usage: tmux-command-center.sh [work_dir]

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
SESSION="center"
WORK_DIR="${1:-$HOME}"

CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Kill existing session if it exists
if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo -e "${CYAN}Restarting command center...${RESET}"
    tmux kill-session -t "$SESSION"
fi

# ── Create session ────────────────────────────────────────────────────
# Main terminal (top-left, 65% width)
tmux new-session -d -s "$SESSION" -c "$WORK_DIR"

# ── Right column ──────────────────────────────────────────────────────
# Git dashboard (top-right, 35% width)
tmux split-window -h -l 35% -t "$SESSION" -c "$WORK_DIR"
tmux send-keys -t "$SESSION" "$SCRIPT_DIR/git-dashboard.sh $WORK_DIR" Enter

# System health (middle-right)
tmux split-window -v -l 60% -t "$SESSION"
tmux send-keys -t "$SESSION" "$SCRIPT_DIR/jetson-health.sh --watch" Enter

# Docker status (bottom-right)
tmux split-window -v -l 40% -t "$SESSION"
tmux send-keys -t "$SESSION" "watch -n 10 -t -c $SCRIPT_DIR/docker-status.sh" Enter

# ── Left column (split bottom) ───────────────────────────────────────
# Select top-left pane (main terminal)
tmux select-pane -t "$SESSION:0.0"

# Info / logs area (bottom-left, 30% height)
tmux split-window -v -l 30% -t "$SESSION" -c "$WORK_DIR"

# Show placeholder with useful quick-reference info
tmux send-keys -t "$SESSION" "echo -e '\\033[1;33m  ╔══════════════════════════════════════╗'" Enter
tmux send-keys -t "$SESSION" "echo -e '  ║  📋 Quick Reference                  ║'" Enter
tmux send-keys -t "$SESSION" "echo -e '  ╠══════════════════════════════════════╣'" Enter
tmux send-keys -t "$SESSION" "echo -e '  ║  jcam    — dog cam (port 8920)      ║'" Enter
tmux send-keys -t "$SESSION" "echo -e '  ║  jhealth — system health            ║'" Enter
tmux send-keys -t "$SESSION" "echo -e '  ║  jdocker — docker status            ║'" Enter
tmux send-keys -t "$SESSION" "echo -e '  ║  jgit    — git dashboard            ║'" Enter
tmux send-keys -t "$SESSION" "echo -e '  ╚══════════════════════════════════════╝\\033[0m'" Enter

# ── Select main terminal pane ────────────────────────────────────────
tmux select-pane -t "$SESSION:0.0"

# ── Name the window ──────────────────────────────────────────────────
tmux rename-window -t "$SESSION" "Command Center"

# ── Attach ────────────────────────────────────────────────────────────
if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$SESSION"
else
    echo -e "${BOLD}${CYAN}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║       Jetson Command Center              ║"
    echo "  ╠══════════════════════════════════════════╣"
    echo "  ║  Ctrl+A then arrow keys = switch panes  ║"
    echo "  ║  Ctrl+A then z          = zoom pane     ║"
    echo "  ║  Ctrl+A then d          = detach        ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${RESET}"
    tmux attach-session -t "$SESSION"
fi
