#!/usr/bin/env bash
set -euo pipefail
# ── Docker Stack Status ──────────────────────────────────────────────
# Quick overview of docker-compose projects running on the Jetson.

YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

echo -e "${YELLOW}${BOLD}── Docker Stack Status ──${RESET}"
echo ""

if ! command -v docker &>/dev/null; then
    echo "Docker is not installed."
    exit 1
fi

# Running containers grouped by compose project
docker ps --format '{{.Label "com.docker.compose.project"}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null | \
    sort | column -t -s $'\t' || echo "No containers running."

echo ""
echo -e "${YELLOW}${BOLD}── Resource Usage ──${RESET}"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || true
