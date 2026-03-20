#!/usr/bin/env bash
# ── Aliases & functions for Jetson workflow ───────────────────────────
# Loaded automatically by bashrc-extras.sh

# ── Git shortcuts ─────────────────────────────────────────────────────
alias gst='git status'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gpl='git pull'
alias gps='git push'
alias glog='git log --oneline -20'
alias gd='git diff'
alias gds='git diff --staged'
alias ga='git add'
alias gc='git commit'
alias gcm='git commit -m'
alias gb='git branch'

# ── Docker shortcuts ──────────────────────────────────────────────────
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dpsa='docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dcup='docker compose up -d'
alias dcd='docker compose down'
alias dcr='docker compose restart'
alias dcl='docker compose logs -f --tail=50'
alias dclean='docker system prune -f'

# ── Navigation ────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

# ── Safety ────────────────────────────────────────────────────────────
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# ── Disk / system ────────────────────────────────────────────────────
alias df='df -h'
alias du='du -h'
alias free='free -h'

# ── Jetson-specific ───────────────────────────────────────────────────
alias jtop='sudo jtop 2>/dev/null || echo "Install jetson-stats: sudo pip3 install jetson-stats"'
alias tegra='sudo tegrastats'
alias nvp='sudo nvpmodel -q'
alias jpower='cat /sys/bus/i2c/drivers/ina3221x/*/iio:device*/in_power*_input 2>/dev/null || echo "Power sensors not available"'

jetson-mode() {
    # Set Jetson power mode: jetson-mode 0 = MAXN, jetson-mode 1 = 10W, etc.
    local mode="${1:?Usage: jetson-mode <mode_number>}"
    sudo nvpmodel -m "$mode" && sudo nvpmodel -q
}

jetson-fan() {
    # Set fan speed: jetson-fan 255 = max, jetson-fan 0 = off
    local speed="${1:?Usage: jetson-fan <0-255>}"
    echo "$speed" | sudo tee /sys/devices/pwm-fan/target_pwm
}

# ── Tmux shortcuts ───────────────────────────────────────────────────
alias ta='tmux attach -t'
alias tls='tmux list-sessions'
alias tn='tmux new-session -s'
alias tk='tmux kill-session -t'

# ── Quick diagnostics ────────────────────────────────────────────────
alias jhealth='~/jetson-terminal-config/scripts/jetson-health.sh'
alias jlayout='~/jetson-terminal-config/scripts/tmux-dev-layout.sh'
