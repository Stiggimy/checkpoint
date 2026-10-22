#!/usr/bin/env bash
set -e

# --- checkpoint Installer (per-user, XDG-aware) ---
#
# Installs into the XDG base directories when they are set:
#   binaries   -> ~/.local/bin (no XDG equivalent)
#   libraries  -> $XDG_DATA_HOME/checkpoint/lib
#   catalog    -> $XDG_DATA_HOME/checkpoint/catalog
#   man page   -> $XDG_DATA_HOME/man/man1
#   config     -> $XDG_CONFIG_HOME/checkpoint
#
# For a system-wide install use the PKGBUILD (makepkg -si) instead.

: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"

BIN_DIR="$HOME/.local/bin"
MAN_DIR="$XDG_DATA_HOME/man/man1"
DATA_DIR="${CHECKPOINT_DATA_DIR:-$XDG_DATA_HOME/checkpoint}"
LIB_DIR="$DATA_DIR/lib"
CATALOG_DIR="$DATA_DIR/catalog"
CONFIG_DIR="${CHECKPOINT_CONFIG_DIR:-$XDG_CONFIG_HOME/checkpoint}"
BACKENDS_DIR="$CONFIG_DIR/backends.d"

# Color Setup (with compatibility check)
RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""; RESET=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    ncolors=$(tput colors 2>/dev/null || echo 0)
    if [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
        RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"
        BLUE="$(tput setaf 4)"; BOLD="$(tput bold)"; RESET="$(tput sgr0)"
    fi
fi

echo "${BLUE}>>> [Phase: Installation] Setting up Checkpoint...${RESET}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Replace a real file/directory with a symlink, keeping a backup of user data.
link_path() {
    local src="$1" dest="$2"
    if [[ -e "$dest" && ! -L "$dest" ]]; then
        local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
        mv "$dest" "$backup"
        echo "  ${YELLOW}[BACKUP]${RESET} $dest -> $backup"
    fi
    mkdir -p "$(dirname "$dest")"
    ln -sfn "$src" "$dest"
}

# Ensure directories exist
mkdir -p "$BIN_DIR" "$MAN_DIR" "$DATA_DIR" "$BACKENDS_DIR"

# Copy / link files
link_path "$SCRIPT_DIR/checkpoint" "$BIN_DIR/checkpoint"
link_path "$SCRIPT_DIR/lib" "$LIB_DIR"
link_path "$SCRIPT_DIR/catalog" "$CATALOG_DIR"
install -Dm644 "$SCRIPT_DIR/checkpoint.1" "$MAN_DIR/checkpoint.1"

# Auto-enroll active backend into the user config directory
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
        ln -sf "$SCRIPT_DIR/catalog/backends/${target_backend}.conf" "$BACKENDS_DIR/${target_backend}.conf"
        echo "  ${GREEN}[ENROLL]${RESET} Default backend: ${target_backend} (symlinked to catalog)"
    fi
fi

# Set permissions
chmod +x "$BIN_DIR/checkpoint"

echo "${GREEN}[OK] Checkpoint installed successfully!${RESET}"
echo "   - Binary: $BIN_DIR/checkpoint"
echo "   - Libraries: $LIB_DIR"
echo "   - Catalog: $CATALOG_DIR"
echo "   - Backends: $BACKENDS_DIR/"
echo "   - Manual: $MAN_DIR/checkpoint.1"
echo "   - Configuration: $CONFIG_DIR"
echo ""

if ! command -v fzf >/dev/null 2>&1; then
    echo "${YELLOW}[WARN] 'fzf' is not installed. 'checkpoint config' and interactive deletion need it.${RESET}"
    echo ""
fi

if ! command -v sudo >/dev/null 2>&1; then
    echo "${YELLOW}[WARN] 'sudo' is not installed. Checkpoint needs it to run snapshot commands.${RESET}"
    echo ""
fi

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "${YELLOW}[WARN] $BIN_DIR is not in your PATH. Add this to your shell profile:${RESET}"
    echo "       export PATH=\"$BIN_DIR:\$PATH\""
    echo ""
fi

echo "[INFO] Usage: Type 'checkpoint --help' or 'man checkpoint' to get started."
