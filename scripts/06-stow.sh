#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }

# zsh is handled in 05-shell.sh, firefox is copied in 07-post.sh
SKIP_PACKAGES=(zsh)

cd "$REPO_DIR"

for pkg in */; do
    pkg="${pkg%/}"

    [[ "$pkg" == "packages" || "$pkg" == "scripts" || "$pkg" == "firefox" || "$pkg" == ".git" ]] && continue

    skip=false
    for s in "${SKIP_PACKAGES[@]}"; do
        [[ "$pkg" == "$s" ]] && skip=true && break
    done
    $skip && continue

    info "Stowing $pkg..."

    dry_run="$(stow -n -v -t "$HOME" "$pkg" 2>&1 || true)"

    if echo "$dry_run" | grep -qi "conflict\|cannot stow"; then
        warn "Conflicts detected for $pkg, backing up existing files..."
        echo "$dry_run" | grep -oP '(?<=over existing target )\S+' | while read -r file; do
            if [[ -e "$HOME/$file" ]]; then
                mv "$HOME/$file" "$HOME/${file}.bak"
                info "  Backed up ~/$file -> ${file}.bak"
            fi
        done
    fi

    stow -v -t "$HOME" "$pkg"
done

# --- Fedora-specific fixups in stowed config files ---
info "Applying Fedora-specific config patches..."

# Hyprland: remove Arch-specific XDG_MENU_PREFIX
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
if [[ -f "$HYPR_CONF" ]] && grep -q 'XDG_MENU_PREFIX,arch-' "$HYPR_CONF"; then
    sed -i 's/env = XDG_MENU_PREFIX,arch-/# env = XDG_MENU_PREFIX,arch- # Removed: Arch-specific/' "$HYPR_CONF"
    info "  Patched hyprland.conf: commented out Arch XDG_MENU_PREFIX."
fi

# GTK: add font and DPI settings (Arch config only has theme, no font/DPI)
for gtk_ini in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    if [[ -f "$gtk_ini" ]] && ! grep -q 'gtk-font-name' "$gtk_ini"; then
        printf 'gtk-font-name=Noto Sans, 10\ngtk-xft-dpi=98304\n' >> "$gtk_ini"
        info "  Added font/DPI settings to $(basename "$(dirname "$gtk_ini")")/settings.ini"
    fi
done

# Qt6ct: normalize font size to 10 (Arch config had 12, too large for most screens)
QT6CT_CONF="$HOME/.config/qt6ct/qt6ct.conf"
if [[ -f "$QT6CT_CONF" ]] && grep -q 'Noto Sans,12' "$QT6CT_CONF"; then
    sed -i 's/Noto Sans,12/Noto Sans,10/g' "$QT6CT_CONF"
    info "  Normalized Qt6ct font size from 12 to 10."
fi

# Noctalia & qt6ct: replace hardcoded /home/shepard with actual $HOME
for cfg in "$HOME/.config/noctalia/settings.json" "$HOME/.config/qt6ct/qt6ct.conf"; do
    if [[ -f "$cfg" ]] && grep -q '/home/shepard' "$cfg"; then
        sed -i "s|/home/shepard|$HOME|g" "$cfg"
        info "  Fixed hardcoded paths in $(basename "$cfg")."
    fi
done

info "Dotfiles stowed."
