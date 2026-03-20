#!/usr/bin/env bash
set -euo pipefail
# ── Jetson Health Dashboard ──────────────────────────────────────────
# Usage: jetson-health.sh [--watch]
# Shows GPU, CPU, memory, disk, power, and thermal info at a glance.

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

header() { echo -e "\n${YELLOW}${BOLD}── $1 ──${RESET}"; }

jetson_health() {
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║       Jetson Health Report       ║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════╝${RESET}"
    echo -e "  $(date '+%Y-%m-%d %H:%M:%S')  •  $(hostname)"

    # ── Power mode ────────────────────────────────────────────────
    header "Power Mode"
    sudo nvpmodel -q 2>/dev/null || echo "  nvpmodel not available"

    # ── CPU ───────────────────────────────────────────────────────
    header "CPU"
    echo -n "  Load: "; cat /proc/loadavg
    echo -n "  Cores online: "; nproc
    if command -v lscpu &>/dev/null; then
        lscpu | grep -E "^(Model name|CPU MHz)" | sed 's/^/  /'
    fi

    # ── GPU ───────────────────────────────────────────────────────
    header "GPU"
    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu \
            --format=csv,noheader 2>/dev/null | sed 's/^/  /' || echo "  nvidia-smi query failed"
    elif [ -f /sys/devices/gpu.0/load ]; then
        echo "  GPU load: $(cat /sys/devices/gpu.0/load)"
    else
        echo "  No GPU info available"
    fi

    # ── Memory ────────────────────────────────────────────────────
    header "Memory"
    free -h | head -2 | sed 's/^/  /'

    # ── Disk ──────────────────────────────────────────────────────
    header "Disk"
    df -h / | tail -1 | awk '{printf "  Root: %s used of %s (%s)\n", $3, $2, $5}'

    # ── Thermals ──────────────────────────────────────────────────
    header "Thermals"
    if [ -d /sys/devices/virtual/thermal ]; then
        for zone in /sys/devices/virtual/thermal/thermal_zone*/; do
            if [ -f "$zone/type" ] && [ -f "$zone/temp" ]; then
                local name temp
                name=$(cat "$zone/type")
                temp=$(cat "$zone/temp")
                printf "  %-20s %s°C\n" "$name" "$(echo "scale=1; $temp/1000" | bc 2>/dev/null || echo "$temp")"
            fi
        done
    else
        echo "  No thermal zones found"
    fi

    # ── Docker ────────────────────────────────────────────────────
    header "Docker"
    if command -v docker &>/dev/null; then
        local running stopped
        running=$(docker ps -q 2>/dev/null | wc -l)
        stopped=$(docker ps -aq 2>/dev/null | wc -l)
        echo "  Containers: $running running / $stopped total"
        if [ "$running" -gt 0 ]; then
            docker ps --format '  • {{.Names}} ({{.Status}})' 2>/dev/null
        fi
    else
        echo "  Docker not installed"
    fi

    echo ""
}

if [ "${1:-}" = "--watch" ]; then
    while true; do
        clear
        jetson_health
        echo -e "${GREEN}Refreshing in 5s... (Ctrl+C to stop)${RESET}"
        sleep 5
    done
else
    jetson_health
fi
