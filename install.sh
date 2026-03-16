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

phases=(
    "01-repos.sh:Repository setup (Terra, COPR nett00n/hyprland, Twingate, Flathub)"
    "02-packages.sh:Package installation (DNF + native RPMs + Flatpak)"
    "03-services.sh:Systemd services"
    "04-fonts.sh:JetBrainsMono Nerd Font"
    "05-shell.sh:Shell setup (zsh + Oh My Zsh)"
    "06-stow.sh:Dotfile symlinks (GNU Stow + Fedora patches)"
    "07-post.sh:Post-install tweaks (Firefox, GTK, MIME)"
    "08-cursor.sh:Cursor IDE (install + keyring config)"
)

info "Fedora Bootstrap — Hyprland + noctalia-shell"
info "============================================="
echo

for entry in "${phases[@]}"; do
    script="${entry%%:*}"
    desc="${entry#*:}"
    info "Phase: $desc ($script)"
    bash "$SCRIPT_DIR/scripts/$script"
    echo
done

info "Bootstrap complete!"
info ""
info "Manual steps remaining:"
echo "  - Run 'lpf update spotify-client' to build the Spotify native RPM"
echo "  - Reboot to switch from KDE/Plasma to Hyprland at the SDDM login screen"
echo "  - Log into Firefox and install extensions"
echo "  - Add wallpapers to ~/Pictures/Wallpapers/"
echo "  - Configure SDDM theme if desired (/etc/sddm.conf.d/)"
echo "  - Copy SSH keys to ~/.ssh/ if not already present"
echo "  - Run 'sudo twingate setup' to configure Twingate"
echo ""
info "After reboot, select 'Hyprland' from the SDDM session dropdown."
