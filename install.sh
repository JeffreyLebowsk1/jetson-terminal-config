#!/usr/bin/env bash
set -euo pipefail
# ── Install / Setup Script ───────────────────────────────────────────
# Run on the Jetson to symlink configs and install dependencies.
# Usage: bash install.sh

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

info()  { echo -e "${GREEN}[✓]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[!]${RESET} $1"; }

echo "── Jetson Terminal Config Installer ──"
echo "  Repo: $REPO_DIR"
echo ""

# ── Shell config ─────────────────────────────────────────────────────
BASHRC_LINE="[ -f $REPO_DIR/shell/bashrc-extras.sh ] && . $REPO_DIR/shell/bashrc-extras.sh"
if ! grep -qF "bashrc-extras.sh" ~/.bashrc 2>/dev/null; then
    echo "" >> ~/.bashrc
    echo "# Jetson terminal config" >> ~/.bashrc
    echo "$BASHRC_LINE" >> ~/.bashrc
    info "Added bashrc-extras.sh source line to ~/.bashrc"
else
    warn "bashrc-extras.sh already sourced in ~/.bashrc — skipping"
fi

# ── Tmux config ──────────────────────────────────────────────────────
ln -sf "$REPO_DIR/tmux/tmux.conf" ~/.tmux.conf
info "Symlinked tmux.conf → ~/.tmux.conf"

# ── Starship ─────────────────────────────────────────────────────────
if command -v starship &>/dev/null; then
    info "Starship already installed"
else
    warn "Installing starship to ~/.local/bin..."
    mkdir -p ~/.local/bin
    curl -sS https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin
    info "Starship installed to ~/.local/bin"
fi
# Ensure ~/.local/bin is on PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi
mkdir -p ~/.config
ln -sf "$REPO_DIR/starship/starship.toml" ~/.config/starship.toml
info "Symlinked starship.toml → ~/.config/starship.toml"

# ── Make scripts executable ──────────────────────────────────────────
chmod +x "$REPO_DIR"/scripts/*.sh
info "Made scripts executable"

# ── Tmux ─────────────────────────────────────────────────────────────
if command -v tmux &>/dev/null; then
    info "Tmux already installed"
else
    warn "Installing tmux..."
    sudo apt-get update -qq && sudo apt-get install -y -qq tmux
    info "Tmux installed"
fi

# ── Done ─────────────────────────────────────────────────────────────
echo ""
echo "── Setup complete! ──"
echo "  • Restart your shell or run: source ~/.bashrc"
echo "  • Start dev layout:     jlayout"
echo "  • Start monitor layout: bash $REPO_DIR/scripts/tmux-monitor-layout.sh"
echo "  • Run health check:     jhealth"
