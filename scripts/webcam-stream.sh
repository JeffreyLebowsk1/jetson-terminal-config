#!/usr/bin/env bash
set -euo pipefail
# ── Webcam Stream Launcher ────────────────────────────────────────────
# Starts the webcam server and shows the URL.
# Usage: webcam-stream.sh [--stop] [--status]

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
SERVER="$SCRIPT_DIR/webcam-server.py"
PID_FILE="/tmp/jetson-webcam.pid"
PORT="${WEBCAM_PORT:-8920}"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

get_ip() {
    hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost"
}

start_server() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo -e "${CYAN}Webcam server already running (PID $(cat "$PID_FILE"))${RESET}"
        echo -e "  URL: ${GREEN}http://$(get_ip):${PORT}${RESET}"
        return 0
    fi

    # Auto-detect source: if GStreamer RTP is running, use it; otherwise direct V4L2
    local extra_args=()
    if pgrep -f 'gst-launch.*udpsink.*port=5000' &>/dev/null; then
        echo -e "${CYAN}Detected GStreamer RTP stream on UDP :5000${RESET}"
        extra_args=(--rtp "udp://0.0.0.0:5000")
    elif [ ! -e /dev/video0 ]; then
        echo -e "${RED}No video device found${RESET}"
        return 1
    fi

    echo -e "${BOLD}Starting Jetson Dog Cam...${RESET}"
    python3 "$SERVER" --port "$PORT" --no-audio "${extra_args[@]}" "$@" &
    local pid=$!
    echo "$pid" > "$PID_FILE"
    sleep 2

    if kill -0 "$pid" 2>/dev/null; then
        echo -e "${GREEN}✓ Running${RESET} (PID $pid)"
        echo -e "  URL: ${CYAN}http://$(get_ip):${PORT}${RESET}"
    else
        echo -e "${RED}✗ Failed to start${RESET}"
        rm -f "$PID_FILE"
        return 1
    fi
}

stop_server() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            echo -e "${GREEN}Stopped webcam server (PID $pid)${RESET}"
        fi
        rm -f "$PID_FILE"
    else
        echo "No webcam server running"
    fi
}

show_status() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo -e "${GREEN}● Running${RESET} (PID $(cat "$PID_FILE")) — http://$(get_ip):${PORT}"
    else
        echo -e "${RED}● Stopped${RESET}"
        rm -f "$PID_FILE" 2>/dev/null
    fi
}

case "${1:-start}" in
    --stop)   stop_server ;;
    --status) show_status ;;
    *)        start_server "$@" ;;
esac
