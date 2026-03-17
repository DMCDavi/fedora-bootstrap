#!/usr/bin/env bash
set -euo pipefail

CURSOR_SCRIPTS_REPO="https://github.com/phstella/cursor-update-scripts.git"
CURSOR_SCRIPTS_DIR="$HOME/dev/cursor-update-scripts"
CURSOR_ARGV="$HOME/.cursor/argv.json"

info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }

# --- Clone / update the installer scripts ---
info "Setting up cursor-update-scripts..."
if [[ -d "$CURSOR_SCRIPTS_DIR/.git" ]]; then
    git -C "$CURSOR_SCRIPTS_DIR" pull --quiet
    info "  Updated existing clone at $CURSOR_SCRIPTS_DIR"
else
    rm -rf "$CURSOR_SCRIPTS_DIR"
    git clone --quiet "$CURSOR_SCRIPTS_REPO" "$CURSOR_SCRIPTS_DIR"
    info "  Cloned to $CURSOR_SCRIPTS_DIR"
fi

# --- Install Cursor via the extracted-AppImage script ---
if [[ -d "/opt/cursor" ]]; then
    info "Cursor is already installed at /opt/cursor, skipping install."
else
    info "Installing Cursor IDE..."
    bash "$CURSOR_SCRIPTS_DIR/update-cursor-fixed.sh"
fi

# --- Fix CLI symlink ---
# The upstream install script symlinks /usr/local/bin/cursor to the raw
# Electron binary. This causes every CLI invocation (--list-extensions,
# --install-extension, etc.) to open a GUI window instead of running
# headlessly. Point the symlink at the proper CLI wrapper which uses
# ELECTRON_RUN_AS_NODE=1 for non-GUI commands.
CLI_WRAPPER="/opt/cursor/usr/share/cursor/bin/cursor"
BIN_SYMLINK="/usr/local/bin/cursor"
if [[ -f "$CLI_WRAPPER" ]]; then
    current_target=$(readlink -f "$BIN_SYMLINK" 2>/dev/null || true)
    if [[ "$current_target" != "$CLI_WRAPPER" ]]; then
        sudo ln -sf "$CLI_WRAPPER" "$BIN_SYMLINK"
        info "  Fixed CLI symlink: $BIN_SYMLINK → $CLI_WRAPPER"
    else
        info "  CLI symlink already correct."
    fi
fi

# --- Configure keyring for Hyprland ---
info "Configuring Cursor keyring (gnome-libsecret for Hyprland)..."
mkdir -p "$HOME/.cursor"

if [[ -f "$CURSOR_ARGV" ]]; then
    if grep -q '"password-store"' "$CURSOR_ARGV"; then
        info "  password-store already configured, skipping."
    else
        sed -i 's/}$/,\n\t"password-store": "gnome-libsecret"\n}/' "$CURSOR_ARGV"
        info "  Added password-store to existing argv.json"
    fi
else
    cat > "$CURSOR_ARGV" <<'JSON'
{
	"enable-crash-reporter": true,
	"password-store": "gnome-libsecret"
}
JSON
    info "  Created argv.json with password-store configured"
fi

info "Cursor setup complete."
