#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }

# --- Firefox Betterfox user.js ---
info "Installing Firefox user.js (Betterfox)..."
FF_PROFILE_DIR=""
for candidate in "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox"; do
    if [[ -d "$candidate" ]]; then
        FF_PROFILE_DIR="$candidate"
        break
    fi
done

if [[ -n "$FF_PROFILE_DIR" ]]; then
    profile_path="$(find "$FF_PROFILE_DIR" -maxdepth 1 -name "*.default-release" -type d | head -1)"
    if [[ -n "$profile_path" ]]; then
        if [[ -f "$profile_path/user.js" ]]; then
            if ! diff -q "$REPO_DIR/firefox/user.js" "$profile_path/user.js" &>/dev/null; then
                cp "$profile_path/user.js" "$profile_path/user.js.bak"
                info "  Backed up existing user.js -> user.js.bak"
            fi
        fi
        cp "$REPO_DIR/firefox/user.js" "$profile_path/user.js"
        info "  Copied to $profile_path/user.js"
    else
        warn "No Firefox profile found. Run Firefox once first, then re-run this script."
    fi
else
    warn "Firefox profile directory not found. Run Firefox once first."
fi

# --- GTK dark mode ---
info "Setting GTK dark mode..."
if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark 2>/dev/null || true
fi

# --- Create user directories ---
info "Creating user directories..."
mkdir -p ~/Pictures/Screenshots
mkdir -p ~/Pictures/Wallpapers

# --- Rebuild KDE service cache ---
info "Rebuilding KDE service cache..."
kbuildsycoca6 2>/dev/null || true

# --- Set default text editor (Kate, since VS Code is not included) ---
info "Setting default text editor..."
xdg-mime default org.kde.kate.desktop text/plain 2>/dev/null || true

info "Post-install complete."
