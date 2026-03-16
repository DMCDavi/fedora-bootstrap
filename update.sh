#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
error() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; }

if [[ $EUID -eq 0 ]]; then
    error "Do not run this script as root. It will call sudo when needed."
    exit 1
fi

if ! grep -qi fedora /etc/os-release 2>/dev/null; then
    error "This script is designed for Fedora. Detected a different distribution."
    exit 1
fi

info "Fedora Bootstrap — Update"
info "========================="
echo

# ── Packages ─────────────────────────────────────────────────────────────────
info "Syncing DNF packages..."
missing_pkgs=()
while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    if ! rpm -q "$pkg" &>/dev/null; then
        missing_pkgs+=("$pkg")
    fi
done < "$SCRIPT_DIR/packages/dnf.txt"

if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
    info "  Installing ${#missing_pkgs[@]} missing package(s): ${missing_pkgs[*]}"
    sudo dnf install -y "${missing_pkgs[@]}"
else
    info "  All DNF packages are installed."
fi

info "Syncing Flatpak apps..."
while IFS= read -r app; do
    [[ -z "$app" || "$app" == \#* ]] && continue
    if ! flatpak list --app --columns=application 2>/dev/null | grep -q "$app"; then
        info "  Installing $app..."
        flatpak install -y flathub "$app"
    fi
done < "$SCRIPT_DIR/packages/flatpak.txt"
echo

# ── Shell ────────────────────────────────────────────────────────────────────
info "Syncing shell config..."
bash "$SCRIPT_DIR/scripts/05-shell.sh"
echo

# ── Dotfiles (re-stow) ──────────────────────────────────────────────────────
info "Re-stowing dotfiles..."
bash "$SCRIPT_DIR/scripts/06-stow.sh"
echo

# ── Post-install tweaks ──────────────────────────────────────────────────────
info "Applying post-install tweaks..."
bash "$SCRIPT_DIR/scripts/07-post.sh"
echo

# ── Cursor ───────────────────────────────────────────────────────────────────
info "Syncing Cursor IDE setup..."
bash "$SCRIPT_DIR/scripts/08-cursor.sh"
echo

# ── Services ─────────────────────────────────────────────────────────────────
info "Ensuring services are enabled..."
bash "$SCRIPT_DIR/scripts/03-services.sh"
echo

info "Update complete!"
