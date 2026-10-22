#!/bin/bash
set -e

# --- checkpoint Installer ---

BIN_DIR="$HOME/.local/bin"
MAN_DIR="$HOME/.local/share/man/man1"

# Color Setup (with compatibility check)
RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""; RESET=""
if [ -t 1 ]; then
    ncolors=$(tput colors 2>/dev/null || echo 0)
    if [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
        RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"
        BLUE="$(tput setaf 4)"; BOLD="$(tput bold)"; RESET="$(tput sgr0)"
    fi
fi

echo "${BLUE}>>> [Phase: Installation] Setting up Checkpoint...${RESET}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure directories exist
mkdir -p "$BIN_DIR"
mkdir -p "$MAN_DIR"
mkdir -p "$HOME/.local/lib"
mkdir -p "$HOME/.local/share/checkpoint"
mkdir -p "$HOME/.config/checkpoint/backends.d"

# Copy / link files
ln -sf "$SCRIPT_DIR/checkpoint" "$BIN_DIR/checkpoint"
ln -sfn "$SCRIPT_DIR/lib" "$HOME/.local/lib/checkpoint"
ln -sfn "$SCRIPT_DIR/catalog" "$HOME/.local/share/checkpoint/catalog"
[ -f "$SCRIPT_DIR/CHANGELOG.md" ] && ln -sf "$SCRIPT_DIR/CHANGELOG.md" "$HOME/.local/share/checkpoint/CHANGELOG.md"
cp "$SCRIPT_DIR/checkpoint.1" "$MAN_DIR/checkpoint.1"

# Auto-enroll active backend into ~/.config/checkpoint/backends.d/
BACKENDS_DIR="$HOME/.config/checkpoint/backends.d"
if ! find -L "$BACKENDS_DIR" -type f -name "*.conf" 2>/dev/null | grep -q .; then
    # Auto-detect best backend (snapper -> timeshift-btrfs -> timeshift-rsync)
    target_backend="timeshift-btrfs"
    if command -v snapper >/dev/null 2>&1 && sudo snapper -c root get-config >/dev/null 2>&1; then
        target_backend="snapper"
    elif [[ $(stat -f -c %T / 2>/dev/null) == 'btrfs' ]] && command -v timeshift >/dev/null 2>&1; then
        target_backend="timeshift-btrfs"
    elif command -v timeshift >/dev/null 2>&1; then
        target_backend="timeshift-rsync"
    fi
    if [ -f "$SCRIPT_DIR/catalog/backends/${target_backend}.conf" ]; then
        ln -sf "$HOME/.local/share/checkpoint/catalog/backends/${target_backend}.conf" "$BACKENDS_DIR/${target_backend}.conf"
        echo "  ${GREEN}[ENROLL]${RESET} Default backend: ${target_backend} (symlinked to catalog)"
    fi
fi

# Set permissions
chmod +x "$BIN_DIR/checkpoint"

echo "${GREEN}[OK] Checkpoint installed successfully!${RESET}"
echo "   - Binary: $BIN_DIR/checkpoint"
echo "   - Libraries: $HOME/.local/lib/checkpoint"
echo "   - Catalog: $HOME/.local/share/checkpoint/catalog"
echo "   - Changelog: $HOME/.local/share/checkpoint/CHANGELOG.md"
echo "   - Backends: $HOME/.config/checkpoint/backends.d/"
echo "   - Manual: $MAN_DIR/checkpoint.1"
echo ""
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "${YELLOW}[WARN] $BIN_DIR is not in your PATH. Add this to your shell profile:${RESET}"
    echo "       export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

echo "[INFO] Usage: Type 'checkpoint --help' or 'man checkpoint' to get started."
