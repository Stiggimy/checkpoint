#!/usr/bin/env bash
# ==============================================================================
# Checkpoint Module: XDG Base Directory resolution
# ==============================================================================

# XDG Base Directory defaults (https://specifications.freedesktop.org/basedir-spec/)
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"
export XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME

# Checkpoint-specific directories. They can be overridden independently with
# CHECKPOINT_CONFIG_DIR and CHECKPOINT_DATA_DIR.
_migrate_config=true
_migrate_data=true
if [[ -n "${CHECKPOINT_CONFIG_DIR:-}" ]]; then _migrate_config=false; fi
if [[ -n "${CHECKPOINT_DATA_DIR:-}" ]]; then _migrate_data=false; fi

CHECKPOINT_CONFIG_DIR="${CHECKPOINT_CONFIG_DIR:-$XDG_CONFIG_HOME/checkpoint}"
CHECKPOINT_DATA_DIR="${CHECKPOINT_DATA_DIR:-$XDG_DATA_HOME/checkpoint}"
CHECKPOINT_CATALOG_DIR="${CHECKPOINT_CATALOG_DIR:-$CHECKPOINT_DATA_DIR/catalog}"

# Move the old hardcoded locations once. Never overwrite an existing
# destination, and let explicit CHECKPOINT_* overrides opt out.
_migrate_legacy_dir() {
    local legacy="$1" new="$2" label="$3"
    if [[ "$legacy" == "$new" || -e "$new" || ! -e "$legacy" ]]; then
        return 0
    fi
    mkdir -p "$(dirname "$new")" 2>/dev/null || return 0
    if mv "$legacy" "$new" 2>/dev/null; then
        printf 'checkpoint: migrated %s from %s to %s\n' "$label" "$legacy" "$new" >&2
    fi
}

if [[ "$_migrate_config" == true ]]; then
    _migrate_legacy_dir "$HOME/.config/checkpoint" "$CHECKPOINT_CONFIG_DIR" "configuration"
fi
if [[ "$_migrate_data" == true ]]; then
    _migrate_legacy_dir "$HOME/.local/share/checkpoint" "$CHECKPOINT_DATA_DIR" "data"
    _migrate_legacy_dir "$HOME/.local/lib/checkpoint" "$CHECKPOINT_DATA_DIR/lib" "libraries"
fi
unset _migrate_config _migrate_data

# If the entrypoint started from the legacy library directory, follow it to
# the new location after migration.
if [[ "${LIB_DIR:-}" == "$HOME/.local/lib/checkpoint" && -d "$CHECKPOINT_DATA_DIR/lib" ]]; then
    LIB_DIR="$CHECKPOINT_DATA_DIR/lib"
fi

CONFIG_FILE="$CHECKPOINT_CONFIG_DIR/config"
BACKENDS_USER_DIR="$CHECKPOINT_CONFIG_DIR/backends.d"
CATALOG_DIR="$CHECKPOINT_CATALOG_DIR"

# Print a path with $HOME shortened to ~ for user-facing messages.
tilde_path() {
    local p="$1"
    printf '%s\n' "${p/#$HOME/~}"
}
