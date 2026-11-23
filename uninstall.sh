#!/usr/bin/env bash
# Per-user Checkpoint uninstaller. Preserves system snapshots and user config by default.
set -euo pipefail

main() {
    local purge=false
    local keep_config=false
    local yes=false
    local dry_run=false
    local quiet=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --purge) purge=true; shift ;;
            --keep-config) keep_config=true; shift ;;
            -y|--yes) yes=true; shift ;;
            --dry-run) dry_run=true; shift ;;
            -q|--quiet) quiet=true; shift ;;
            -h|--help)
                cat <<'EOF'
Usage: checkpoint uninstall [OPTIONS]
   or: ./uninstall.sh [OPTIONS]

Remove a per-user Checkpoint installation from ~/.local.
Existing system snapshots (Snapper / Timeshift) are never modified.

Options:
  --purge         Also remove configuration and custom backends (~/.config/checkpoint)
  --keep-config   Keep configuration directory without prompting
  -y, --yes       Skip confirmation prompts (preserves config unless --purge is passed)
  --dry-run       Show what would be removed without making any changes
  -q, --quiet     Suppress informational output
  -h, --help      Display this help and exit
EOF
                return 0
                ;;
            *)
                echo "checkpoint uninstall: unknown option: $1" >&2
                echo "Run 'checkpoint uninstall --help' for usage." >&2
                return 1
                ;;
        esac
    done

    if [[ "$purge" == true && "$keep_config" == true ]]; then
        echo "checkpoint uninstall: --purge and --keep-config cannot be used together." >&2
        return 1
    fi

    local xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}"
    local xdg_data="${XDG_DATA_HOME:-$HOME/.local/share}"
    local xdg_cache="${XDG_CACHE_HOME:-$HOME/.cache}"

    local bin_path="$HOME/.local/bin/checkpoint"
    local data_dir="${CHECKPOINT_DATA_DIR:-$xdg_data/checkpoint}"
    local legacy_lib_dir="$HOME/.local/lib/checkpoint"
    local man_file="$xdg_data/man/man1/checkpoint.1"
    local legacy_man_file="$HOME/.local/share/man/man1/checkpoint.1"
    local config_dir="${CHECKPOINT_CONFIG_DIR:-$xdg_config/checkpoint}"
    local cache_dir="${CHECKPOINT_CACHE_DIR:-$xdg_cache/checkpoint}"

    log() {
        [[ "$quiet" == true ]] || echo "$*"
    }

    rm_target() {
        local target="$1"
        local label="$2"
        if [[ -e "$target" || -L "$target" ]]; then
            if [[ "$dry_run" == true ]]; then
                log "  [DRY-RUN] Would remove $label: $target"
            else
                rm -rf -- "$target"
                log "  [REMOVE] $label: $target"
            fi
        fi
    }

    # Refuse to run if only a system-wide package-managed copy is present.
    if [[ ! -e "$bin_path" && ! -L "$bin_path" && ! -e "$data_dir" && ! -L "$data_dir" && ! -e "$legacy_lib_dir" && ! -L "$legacy_lib_dir" ]]; then
        local active=""
        active=$(type -P checkpoint 2>/dev/null || true)
        if [[ -n "$active" && "$active" != "$bin_path" ]]; then
            echo "checkpoint uninstall: found a system-wide installation at $active." >&2
            echo "Remove it with your system package manager instead (for example: sudo pacman -R checkpoint-git)." >&2
            return 1
        fi
        log "Checkpoint does not appear to be installed for user $USER."
        return 0
    fi

    # Resolve linked source checkout before removing the launcher symlink.
    local resolved_bin="" source_dir=""
    if [[ -L "$bin_path" && -e "$bin_path" ]]; then
        resolved_bin=$(readlink -f "$bin_path" 2>/dev/null || true)
        if [[ -n "$resolved_bin" ]]; then
            source_dir=$(dirname "$resolved_bin")
        fi
    fi

    if [[ "$dry_run" != true && "$yes" != true && -t 0 && -t 1 ]]; then
        echo -n "Remove per-user Checkpoint installation from ~/.local? [y/N]: "
        local confirm=""
        read -r -n 1 confirm
        echo ""
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log "Uninstall cancelled."
            return 0
        fi
    fi

    log ">>> Uninstalling Checkpoint..."

    if [[ -L "$bin_path" ]]; then
        rm_target "$bin_path" "binary symlink"
    elif [[ -f "$bin_path" ]] && grep -qE 'Checkpoint|run_checkpoint' "$bin_path" 2>/dev/null; then
        rm_target "$bin_path" "binary"
    fi

    rm_target "$data_dir/lib" "libraries"
    rm_target "$legacy_lib_dir" "legacy library symlink"
    rm_target "$data_dir/catalog" "catalog"
    rm_target "$data_dir/CHANGELOG.md" "changelog"
    rm_target "$data_dir/bootstrap.lock" "bootstrap lock"
    rm_target "$man_file" "manual page"
    if [[ "$legacy_man_file" != "$man_file" ]]; then
        rm_target "$legacy_man_file" "legacy manual page"
    fi
    rm_target "$cache_dir" "cache"

    # Decide configuration disposition.
    local remove_config=false
    if [[ "$purge" == true ]]; then
        if [[ "$dry_run" == true || "$yes" == true || ! -t 0 || ! -t 1 ]]; then
            remove_config=true
        else
            echo -n "Also remove configuration and custom backends in $config_dir? [y/N]: "
            local purge_confirm=""
            read -r -n 1 purge_confirm
            echo ""
            [[ "$purge_confirm" =~ ^[Yy]$ ]] && remove_config=true
        fi
    elif [[ "$keep_config" != true && -d "$config_dir" && "$dry_run" != true && "$yes" != true && -t 0 && -t 1 ]]; then
        echo -n "Also remove configuration and custom backends in $config_dir? [y/N]: "
        local cfg_confirm=""
        read -r -n 1 cfg_confirm
        echo ""
        [[ "$cfg_confirm" =~ ^[Yy]$ ]] && remove_config=true
    fi

    if [[ "$remove_config" == true ]]; then
        rm_target "$config_dir" "configuration"
    elif [[ -d "$config_dir" ]]; then
        # Clean dangling/managed catalog symlinks in backends.d while preserving custom files.
        local backends_dir="$config_dir/backends.d"
        if [[ -d "$backends_dir" ]]; then
            local entry link_target
            for entry in "$backends_dir"/*.conf; do
                [[ -L "$entry" ]] || continue
                link_target=$(readlink "$entry" 2>/dev/null || true)
                if [[ "$link_target" == "$data_dir/catalog/"* || ( -n "$source_dir" && "$link_target" == "$source_dir/catalog/"* ) ]]; then
                    rm_target "$entry" "enrolled catalog symlink"
                fi
            done
            if [[ "$dry_run" != true ]]; then
                rmdir "$backends_dir" 2>/dev/null || true
            fi
        fi
        log "  [KEEP] Configuration preserved at $config_dir (pass --purge to remove)."
    fi

    # Remove bootstrap-managed source checkout last so self-invocation stays intact.
    if [[ -e "$data_dir/source" || -L "$data_dir/source" ]]; then
        rm_target "$data_dir/source" "managed source checkout"
    fi

    if [[ "$dry_run" != true && -d "$data_dir" ]]; then
        rmdir "$data_dir" 2>/dev/null || true
    fi

    if [[ -n "$source_dir" && "$source_dir" != "$data_dir/source" && -d "$source_dir" ]]; then
        log "  [KEEP] Source repository at $source_dir was preserved."
    fi

    log "Note: Your existing system snapshots (Snapper / Timeshift) were NOT modified."
    if [[ "$dry_run" == true ]]; then
        log "[DRY-RUN] No files were modified."
    else
        log "[OK] Checkpoint uninstalled."
    fi
}

main "$@"
