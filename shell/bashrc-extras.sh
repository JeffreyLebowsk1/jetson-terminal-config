#!/usr/bin/env bash
# ── Jetson .bashrc additions ─────────────────────────────────────────
# Source this from ~/.bashrc:  [ -f ~/jetson-terminal-config/shell/bashrc-extras.sh ] && . ~/jetson-terminal-config/shell/bashrc-extras.sh

# ── Path ──────────────────────────────────────────────────────────────
REPO_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" 2>/dev/null && pwd)"
for _d in "$HOME/.local/bin" "$REPO_BIN"; do
    if [[ -d "$_d" && ":$PATH:" != *":$_d:"* ]]; then
        export PATH="$_d:$PATH"
    fi
done
unset _d REPO_BIN

# ── History ───────────────────────────────────────────────────────────
export HISTCONTROL=ignoredups:erasedups
export HISTSIZE=50000
export HISTFILESIZE=100000
shopt -s histappend                       # append, don't overwrite
PROMPT_COMMAND="history -a; $PROMPT_COMMAND"   # write every command immediately

# Incremental history search with arrow keys (interactive only)
if [[ $- == *i* ]]; then
    bind '"\e[A": history-search-backward'
    bind '"\e[B": history-search-forward'
fi

# ── Colors & ls ───────────────────────────────────────────────────────
export CLICOLOR=1
if command -v dircolors &>/dev/null; then
    eval "$(dircolors -b)"
fi
alias ls='ls --color=auto'
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'

# ── grep colors ───────────────────────────────────────────────────────
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# ── Editor ────────────────────────────────────────────────────────────
export EDITOR=nano
export VISUAL=nano

# ── Disable terminal bell ─────────────────────────────────────────────
if [[ $- == *i* ]]; then
    bind 'set bell-style none'
fi

# ── Starship prompt (if installed) ────────────────────────────────────
if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
fi

# ── Load aliases ──────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/bash-aliases.sh" ]; then
    . "$SCRIPT_DIR/bash-aliases.sh"
fi

# ── 256-color support ─────────────────────────────────────────────────
if [ "$TERM" = "xterm" ]; then
    export TERM=xterm-256color
fi
