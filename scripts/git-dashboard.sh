#!/usr/bin/env bash
set -euo pipefail
# ── Git Dashboard ─────────────────────────────────────────────────────
# Auto-refreshing git status, branch, and recent log for the current repo.
# Usage: git-dashboard.sh [repo_path]

REPO="${1:-.}"
INTERVAL=5
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

cd "$REPO" 2>/dev/null || { echo "Not a valid path: $REPO"; exit 1; }

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Not a git repository: $REPO"
    exit 1
fi

git_dashboard() {
    local branch remote_url ahead behind staged modified untracked

    branch=$(git branch --show-current 2>/dev/null || echo "detached")
    remote_url=$(git remote get-url origin 2>/dev/null || echo "no remote")

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║         Git Dashboard            ║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════╝${RESET}"
    echo -e "  ${DIM}$(date '+%H:%M:%S')${RESET}  •  ${DIM}$(basename "$(git rev-parse --show-toplevel)")${RESET}"
    echo ""

    # Branch + remote
    echo -e "${YELLOW}${BOLD}── Branch ──${RESET}"
    echo -e "  ${GREEN}$branch${RESET}"
    echo -e "  ${DIM}$remote_url${RESET}"

    # Ahead/behind
    if git rev-parse --abbrev-ref '@{upstream}' &>/dev/null; then
        ahead=$(git rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
        behind=$(git rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)
        if [ "$ahead" -gt 0 ] || [ "$behind" -gt 0 ]; then
            echo -e "  ⇡${ahead} ⇣${behind}"
        else
            echo -e "  ${GREEN}Up to date${RESET}"
        fi
    fi
    echo ""

    # Status summary
    echo -e "${YELLOW}${BOLD}── Status ──${RESET}"
    staged=$(git diff --cached --numstat 2>/dev/null | wc -l)
    modified=$(git diff --numstat 2>/dev/null | wc -l)
    untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l)
    echo -e "  Staged:    ${GREEN}${staged}${RESET}"
    echo -e "  Modified:  ${RED}${modified}${RESET}"
    echo -e "  Untracked: ${CYAN}${untracked}${RESET}"
    echo ""

    # File changes (compact)
    local changes
    changes=$(git status --short 2>/dev/null)
    if [ -n "$changes" ]; then
        echo -e "${YELLOW}${BOLD}── Changes ──${RESET}"
        echo "$changes" | head -15 | sed 's/^/  /'
        local total
        total=$(echo "$changes" | wc -l)
        if [ "$total" -gt 15 ]; then
            echo -e "  ${DIM}... and $((total - 15)) more${RESET}"
        fi
        echo ""
    fi

    # Recent commits
    echo -e "${YELLOW}${BOLD}── Recent Commits ──${RESET}"
    git log --oneline --graph --decorate -10 2>/dev/null | sed 's/^/  /'
    echo ""

    # Stashes
    local stash_count
    stash_count=$(git stash list 2>/dev/null | wc -l)
    if [ "$stash_count" -gt 0 ]; then
        echo -e "${YELLOW}${BOLD}── Stashes (${stash_count}) ──${RESET}"
        git stash list 2>/dev/null | head -5 | sed 's/^/  /'
        echo ""
    fi
}

while true; do
    clear
    git_dashboard
    echo -e "${DIM}Refreshing in ${INTERVAL}s... (Ctrl+C to stop)${RESET}"
    sleep "$INTERVAL"
done
