#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }

current_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [[ "$current_shell" != */zsh ]]; then
    info "Setting zsh as default shell..."
    chsh -s "$(command -v zsh)"
fi

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Installing Oh My Zsh (unattended)..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

info "Stowing zsh config..."
cd "$REPO_DIR"
if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
    mv "$HOME/.zshrc" "$HOME/.zshrc.omz-default"
    info "  Backed up oh-my-zsh default .zshrc -> .zshrc.omz-default"
fi
stow -v -t "$HOME" zsh

info "Shell setup complete."
