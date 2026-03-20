# Jetson Terminal Config — Copilot Instructions

This project contains shell configuration files, tmux setup, prompt theming, and diagnostic scripts for an NVIDIA Jetson device accessed via SSH and web terminal.

## Target environment
- **Host**: NVIDIA Jetson (ARM64, Ubuntu-based)
- **User**: madmatter
- **Access**: SSH from Windows (`madmatter-lan` alias → `madmatter@192.168.1.146`) and noVNC web terminal
- **Shell**: Bash

## Conventions
- All config files target Bash on Ubuntu/L4T (no zsh/fish assumptions)
- Scripts use `#!/usr/bin/env bash` and `set -euo pipefail`
- Tmux prefix is `C-a` (not default `C-b`)
- Color schemes must work in both 256-color SSH terminals and the noVNC web terminal
- Keep aliases short but mnemonic; group by domain (git, docker, jetson, navigation)
- Diagnostic scripts go in `scripts/` and are callable standalone or via tmux keybindings
