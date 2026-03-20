# Jetson Terminal Config

Shell, tmux, and prompt configuration for an NVIDIA Jetson accessed via SSH and web terminal (noVNC).

## What's Included

| Directory | Contents |
|-----------|----------|
| `shell/` | `.bashrc` additions, aliases & functions (git, docker, jetson, navigation) |
| `tmux/` | `tmux.conf` — prefix `C-a`, mouse, vim keys, 256-color status bar |
| `starship/` | `starship.toml` — Git-aware prompt with host, path, venv, docker context |
| `scripts/` | `jetson-health.sh`, `docker-status.sh`, tmux layout launchers |

## Quick Start

SSH into the Jetson and run:

```bash
git clone <this-repo> ~/jetson-terminal-config
cd ~/jetson-terminal-config
bash install.sh
source ~/.bashrc
```

## Usage

### Shell aliases

| Alias | Command |
|-------|---------|
| `gst` | `git status` |
| `gco` | `git checkout` |
| `dcup` | `docker compose up -d` |
| `dcd` | `docker compose down` |
| `dcl` | `docker compose logs -f --tail=50` |
| `jhealth` | Run the Jetson health dashboard |
| `jlayout` | Launch the tmux dev layout |
| `ta <name>` | `tmux attach -t <name>` |
| `tls` | `tmux list-sessions` |

### Tmux keybindings

| Key | Action |
|-----|--------|
| `C-a` | Prefix (replaces `C-b`) |
| `C-a \|` | Vertical split |
| `C-a -` | Horizontal split |
| `C-a h/j/k/l` | Navigate panes (vim-style) |
| `C-a r` | Reload config |
| `C-a G` | Open Jetson health pane |

### Jetson-specific commands

| Command | Description |
|---------|-------------|
| `jhealth` | CPU, GPU, memory, thermals, docker status |
| `jhealth --watch` | Auto-refresh every 5 seconds |
| `jetson-mode <n>` | Set power mode (0 = MAXN) |
| `jetson-fan <0-255>` | Set fan speed |
| `nvp` | Query current nvpmodel |
| `tegra` | Launch tegrastats |

### Tmux layouts

- **Dev layout** (`jlayout`): main editor + docker logs + GPU monitor
- **Monitor layout** (`scripts/tmux-monitor-layout.sh`): health dashboard + docker stats + nvtop/tegrastats

## Requirements

- Bash 4+
- tmux 2.6+ (installed by `install.sh` if missing)
- [Starship](https://starship.rs) (installed by `install.sh` if missing)
- For GPU monitoring: `nvidia-smi`, `nvtop`, or `tegrastats`

## Recommended browser font

For the noVNC web terminal, set your browser's monospace font to **JetBrains Mono** or **Fira Code** and adjust zoom for comfortable reading.
