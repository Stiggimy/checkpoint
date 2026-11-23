#!/usr/bin/env bash
set -e

# --- checkpoint Installer (per-user, XDG-aware) ---
#
# Installs into the XDG base directories when they are set:
#   binaries   -> ~/.local/bin (no XDG equivalent)
#   libraries  -> $XDG_DATA_HOME/checkpoint/lib (plus ~/.local/lib/checkpoint symlink)
#   catalog    -> $XDG_DATA_HOME/checkpoint/catalog
#   man page   -> $XDG_DATA_HOME/man/man1
#   config     -> $XDG_CONFIG_HOME/checkpoint
#
# For a system-wide install use the PKGBUILD (makepkg -si) instead.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"

BIN_DIR="$HOME/.local/bin"
MAN_DIR="$XDG_DATA_HOME/man/man1"
DATA_DIR="${CHECKPOINT_DATA_DIR:-$XDG_DATA_HOME/checkpoint}"
LIB_DIR="$DATA_DIR/lib"
LEGACY_LIB_DIR="$HOME/.local/lib/checkpoint"
CATALOG_DIR="$DATA_DIR/catalog"
CONFIG_DIR="${CHECKPOINT_CONFIG_DIR:-$XDG_CONFIG_HOME/checkpoint}"
BACKENDS_DIR="$CONFIG_DIR/backends.d"

QUIET=false
for arg in "$@"; do
    case "$arg" in
        -q|--quiet) QUIET=true ;;
    esac
done

# Ensure standard user tool directories are in PATH during installation
for _p in "$HOME/.local/bin"; do
    [[ -d "$_p" && ":$PATH:" != *":$_p:"* ]] && PATH="$_p:$PATH"
done
unset _p

# Color Setup (with compatibility check)
RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""; RESET=""
if [ -t 1 ]; then
    ncolors=$(tput colors 2>/dev/null || echo 0)
    if [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
        RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"
        BLUE="$(tput setaf 4)"; BOLD="$(tput bold)"; RESET="$(tput sgr0)"
    fi
fi

[ "$QUIET" != true ] && echo "${BLUE}>>> [Phase: Installation] Setting up Checkpoint...${RESET}"

# Replace a real file/directory with a symlink, keeping a backup of user data.
link_path() {
    local src="$1" dest="$2"
    if [[ -e "$dest" && ! -L "$dest" ]]; then
        local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
        mv "$dest" "$backup"
        [ "$QUIET" != true ] && echo "  ${YELLOW}[BACKUP]${RESET} $dest -> $backup"
    fi
    mkdir -p "$(dirname "$dest")"
    ln -sfn "$src" "$dest"
}

# Ensure directories exist
mkdir -p "$BIN_DIR" "$MAN_DIR" "$DATA_DIR" "$HOME/.local/lib" "$BACKENDS_DIR"

# Copy / link files
link_path "$SCRIPT_DIR/checkpoint" "$BIN_DIR/checkpoint"
link_path "$SCRIPT_DIR/lib" "$LIB_DIR"
link_path "$SCRIPT_DIR/lib" "$LEGACY_LIB_DIR"
link_path "$SCRIPT_DIR/catalog" "$CATALOG_DIR"
[ -f "$SCRIPT_DIR/CHANGELOG.md" ] && link_path "$SCRIPT_DIR/CHANGELOG.md" "$DATA_DIR/CHANGELOG.md"
cp "$SCRIPT_DIR/checkpoint.1" "$MAN_DIR/checkpoint.1"

# Auto-enroll active backend into $CONFIG_DIR/backends.d/
if ! find -L "$BACKENDS_DIR" -type f -name "*.conf" 2>/dev/null | grep -q .; then
    # Auto-detect best backend (snapper -> timeshift-btrfs -> timeshift-rsync)
    target_backend=""
    if command -v snapper >/dev/null 2>&1 && sudo -n true 2>/dev/null && sudo snapper -c root get-config >/dev/null 2>&1; then
        target_backend="snapper"
    elif [[ $(stat -f -c %T / 2>/dev/null) == 'btrfs' ]] && command -v timeshift >/dev/null 2>&1; then
        target_backend="timeshift-btrfs"
    elif command -v timeshift >/dev/null 2>&1; then
        target_backend="timeshift-rsync"
    fi
    if [ -n "$target_backend" ] && [ -f "$SCRIPT_DIR/catalog/backends/${target_backend}.conf" ]; then
        ln -sf "$CATALOG_DIR/backends/${target_backend}.conf" "$BACKENDS_DIR/${target_backend}.conf"
        [ "$QUIET" != true ] && echo "  ${GREEN}[ENROLL]${RESET} Default backend: ${target_backend} (symlinked to catalog)"
    elif [ "$QUIET" != true ]; then
        echo "  ${YELLOW}[INFO]${RESET} No snapshot backend detected. Install Timeshift or Snapper to enable snapshots."
    fi
fi

# Set permissions
chmod +x "$BIN_DIR/checkpoint"

if [ "$QUIET" != true ]; then
    echo "${GREEN}[OK] Checkpoint installed successfully!${RESET}"
    echo "   - Binary: $BIN_DIR/checkpoint"
    echo "   - Libraries: $LIB_DIR"
    echo "   - Catalog: $CATALOG_DIR"
    echo "   - Changelog: $DATA_DIR/CHANGELOG.md"
    echo "   - Backends: $BACKENDS_DIR/"
    echo "   - Manual: $MAN_DIR/checkpoint.1"
    echo ""
fi

# Auto-install fzf if missing
if ! command -v fzf >/dev/null 2>&1 && [ ! -x "$BIN_DIR/fzf" ] && [ ! -x "$HOME/.local/bin/fzf" ] && [ ! -x "$HOME/.fzf/bin/fzf" ]; then
    [ "$QUIET" != true ] && echo "${BLUE}>>> [Phase: Dependencies] Installing fzf...${RESET}"
    for cat_conf in "$HOME/.local/share/advance/catalog/managers/system/"*.conf "$SCRIPT_DIR/../advance/catalog/managers/system/"*.conf; do
        [ -f "$cat_conf" ] || continue
        req=$(grep '^REQUIRES_CMD=' "$cat_conf" 2>/dev/null | head -1 | cut -d'=' -f2-)
        probe_cmd=$(grep '^PROBE_ACTIVE_CMD=' "$cat_conf" 2>/dev/null | head -1 | cut -d'=' -f2-)
        inst_cmd=$(grep '^INSTALL_CMD=' "$cat_conf" 2>/dev/null | head -1 | cut -d'=' -f2-)

        if [ -n "$inst_cmd" ] && [ -n "$req" ] && command -v "$req" >/dev/null 2>&1; then
            if [ -z "$probe_cmd" ] || eval "$probe_cmd" >/dev/null 2>&1; then
                # Avoid non-interactive password prompt hangs
                if [[ "$inst_cmd" == *sudo* ]] && ! sudo -n true 2>/dev/null && [ ! -t 0 ]; then
                    continue
                fi
                [ "$QUIET" != true ] && echo "  ${GREEN}[INSTALL]${RESET} Installing fzf via $req ($inst_cmd fzf)..."
                if eval "$inst_cmd fzf"; then
                    break
                fi
            fi
        fi
    done

    # Fallback: official fzf binary via git installer if package manager fails
    if ! command -v fzf >/dev/null 2>&1 && [ ! -x "$BIN_DIR/fzf" ]; then
        [ "$QUIET" != true ] && echo "  ${YELLOW}[INFO]${RESET} Attempting user-level fallback installation of fzf..."
        fzf_dir="$HOME/.fzf"
        if command -v git >/dev/null 2>&1; then
            if [ ! -d "$fzf_dir" ]; then
                git clone --depth 1 https://github.com/junegunn/fzf.git "$fzf_dir" >/dev/null 2>&1 || true
            fi
            if [ -x "$fzf_dir/install" ]; then
                "$fzf_dir/install" --bin >/dev/null 2>&1 || true
                if [ -x "$fzf_dir/bin/fzf" ]; then
                    mkdir -p "$BIN_DIR"
                    ln -sf "$fzf_dir/bin/fzf" "$BIN_DIR/fzf"
                fi
            fi
        fi
    fi

    if [ "$QUIET" != true ]; then
        if command -v fzf >/dev/null 2>&1; then
            echo "  ${GREEN}[OK]${RESET} fzf installed successfully: $(fzf --version 2>/dev/null | head -1)"
        else
            echo "${YELLOW}[WARN] Could not install 'fzf' automatically. Interactive menus need it.${RESET}"
        fi
        echo ""
    fi
fi

# Ensure ~/.local/bin is in ~/.bashrc / ~/.zshrc for login and non-login shells
for _rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$_rc" ]] && ! grep -q '\.local/bin' "$_rc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$_rc"
        [ "$QUIET" != true ] && echo "  ${GREEN}[CONFIG]${RESET} Added ~/.local/bin to $_rc."
    fi
done
unset _rc

if [ "$QUIET" != true ]; then
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo "${YELLOW}[WARN] $BIN_DIR is not in your current PATH. Add this to your shell profile:${RESET}"
        echo "       export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
    fi

    echo "[INFO] Usage: Type 'checkpoint --help' or 'man checkpoint' to get started."
fi
