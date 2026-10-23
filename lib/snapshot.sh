#!/usr/bin/env bash
# ==============================================================================
# Checkpoint Module: Snapshot Engine & CLI Dispatcher
# ==============================================================================

ensure_menu_loaded() {
    if ! declare -f manage_config >/dev/null 2>&1; then
        if [[ -f "$LIB_DIR/menu.sh" ]]; then
            source "$LIB_DIR/menu.sh"
        else
            ui_error "Menu library not found at $LIB_DIR/menu.sh"
            exit 1
        fi
    fi
}

self_update() {
    detect_source_dir
    if [[ ! -d "$SOURCE_DIR" ]]; then ui_error "Source repo not found."; return 1; fi
    if [[ ! -x "$SOURCE_DIR/install.sh" ]]; then
        ui_error "No installer found in $SOURCE_DIR."
        ui_info "This copy of Checkpoint was installed by a package manager; update it with your system package manager instead."
        return 1
    fi
    if declare -f check_connectivity >/dev/null 2>&1; then
        if ! check_connectivity; then
            ui_error "No active internet connection. Cannot perform self-update."
            return 1
        fi
    fi

    local old_ver="$VERSION"
    local old_commit
    old_commit=$(git -C "$SOURCE_DIR" rev-parse HEAD 2>/dev/null || true)
    (
        cd "$SOURCE_DIR" || exit 1
        if git remote | grep -qx 'origin'; then
            local orig_url
            orig_url=$(git remote get-url origin 2>/dev/null || true)
            if [[ (-d ".agents" || -d ".gemini") && "$orig_url" =~ ^(.*github\.com[:/][^/]+/checkpoint)(\.git)?$ ]]; then
                local base_url="${BASH_REMATCH[1]}"
                git remote get-url public >/dev/null 2>&1 || git remote add public "${base_url}.git" 2>/dev/null || true
                git remote set-url origin "${base_url}-dev.git"
                git fetch origin --prune >/dev/null 2>&1 || true
            fi
            ui_info "Checking for updates..."
            local branch
            branch=$(git branch --show-current 2>/dev/null)
            branch=${branch:-master}
            local pull_out
            if ! pull_out=$(git -c advice.diverging=false pull --ff-only origin "$branch" 2>&1); then
                local clean_err
                clean_err=$(echo "$pull_out" | grep -vE '^[[:space:]]*hint:' | tail -n 2 | paste -sd '; ' -)
                ui_error "Pull failed: ${clean_err:-unknown git error}. Aborting self-update."
                exit 1
            fi
            if ! git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
                git branch --set-upstream-to="origin/$branch" "$branch" >/dev/null 2>&1 || true
            fi
        else
            ui_info "Local source only."
        fi
        local cur_commit
        cur_commit=$(git rev-parse HEAD 2>/dev/null || true)
        if [[ -n "$old_commit" && "$old_commit" == "$cur_commit" ]]; then
            exit 10
        fi
        ./install.sh --quiet
    )
    local sub_code=$?
    if [[ $sub_code -eq 10 ]]; then
        ui_ok "Checkpoint is already up to date (v$VERSION)."
        rm -f "${CHECKPOINT_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/checkpoint}/self_update.cache"
        return 0
    elif [[ $sub_code -ne 0 ]]; then
        return 1
    fi

    local new_commit
    new_commit=$(git -C "$SOURCE_DIR" rev-parse HEAD 2>/dev/null || true)
    local new_ver
    new_ver=$(grep '^VERSION=' "$SOURCE_DIR/checkpoint" 2>/dev/null | head -n 1 | cut -d'"' -f2)
    new_ver="${new_ver:-$VERSION}"

    if [[ "$old_ver" != "$new_ver" || ("$old_commit" != "$new_commit" && -n "$old_commit") ]]; then
        echo ""
        ui_ok "Checkpoint updated successfully to v$new_ver!"
        echo ""
        ui_info "${C_BOLD}What's New in v$new_ver:${C_RESET}"
        display_changelog "$new_ver" || display_changelog "latest"
        echo ""
    fi
    rm -f "${CHECKPOINT_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/checkpoint}/self_update.cache"
}

ensure_sudo() {
    if ! sudo -n true 2>/dev/null; then
        [[ "$PORCELAIN" != true ]] && request_attention "Sudo required."
    fi
    sudo -v || { [[ "$PORCELAIN" != true ]] && close_attention; exit 1; }
    [[ "$PORCELAIN" != true ]] && close_attention
}

run_checkpoint() {
    load_config
    setup_colors

    if [[ "$1" == "check" || "$1" == "--check" || "$1" == "-ch" ]]; then
        load_backend
        local is_porcelain=false
        [[ "$2" == "--porcelain" || "$3" == "--porcelain" ]] && is_porcelain=true
        if [[ -n "$BACKEND_ID" ]]; then
            local missing_bin=""
            if [[ -n "$BACKEND_REQUIRES_CMD" ]] && ! command -v "$BACKEND_REQUIRES_CMD" >/dev/null 2>&1; then
                missing_bin="$BACKEND_REQUIRES_CMD"
            fi
            if [[ -z "$missing_bin" ]]; then
                if [[ "$is_porcelain" == true ]]; then
                    backend_porcelain_output "ok" "" ""
                else
                    ui_ok "Active snapshot backend: ${BACKEND_NAME:-$BACKEND_ID} ($BACKEND_ID)"
                fi
                return 0
            fi
        fi
        if [[ "$is_porcelain" == true ]]; then
            backend_porcelain_output "error" "" "No snapshot backend configured or installed."
        else
            ui_warn "No snapshot backend configured or installed."
        fi
        return 1
    fi

    if [[ "$1" == "changelog" ]]; then
        show_changelog "$2"
        return $?
    fi
    if [[ "$1" == "config" ]]; then
        ensure_menu_loaded
        manage_config
        return 0
    fi
    if [[ "$1" == "backend" || "$1" == "backends" ]]; then
        ensure_menu_loaded
        manage_backends_menu
        return 0
    fi
    if [[ "$1" == "self-update" || "$1" == "selfupdate" ]]; then
        self_update
        return $?
    fi

    local DO_CREATE=${ALWAYS_CREATE:-true}
    local DO_CLEANUP=${ALWAYS_CLEANUP:-true}
    local TEMP_LIMIT=${DEFAULT_KEEP_LIMIT:-6}
    local COMMENT="Manual snapshot"
    local PROTECT=${ALWAYS_KEEP:-false}
    local FORCE_DELETE=false
    local SPEC_DELETE=false
    local LIST_ONLY=false
    local DELETE_PATTERN=""
    local PORCELAIN=false
    local SNAP_TYPE="single"
    local PRE_ID=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            create) DO_CREATE=true; shift ;;
            --porcelain) PORCELAIN=true; shift ;;
            --type)
                if [[ -n "$2" && "$2" != -* ]]; then
                    SNAP_TYPE="$2"; shift 2
                else
                    ui_error "Flag --type requires an argument (single|pre|post)."; exit 1
                fi ;;
            --pre-id)
                if [[ -n "$2" && "$2" != -* ]]; then
                    PRE_ID="$2"; shift 2
                else
                    ui_error "Flag $1 requires an ID."; exit 1
                fi ;;
            --backend)
                if [[ -n "$2" && "$2" != -* ]]; then
                    SNAPSHOT_BACKEND="$2"; shift 2
                else
                    ui_error "Flag $1 requires a backend name."; exit 1
                fi ;;
            -nc|--no-cleanup) DO_CLEANUP=false; shift ;;
            -cl|--cleanup-only) DO_CREATE=false; DO_CLEANUP=true; shift ;;
            -l|--list) LIST_ONLY=true; DO_CREATE=false; DO_CLEANUP=false; shift ;;
            -m|--comment)
                if [[ -n "$2" && "$2" != -* ]]; then
                    COMMENT="$2"; shift 2
                    while [[ -n "$1" && "$1" != -* ]]; do COMMENT+=" $1"; shift; done
                    DO_CREATE=true
                else
                    ui_error "Flag -m requires a string."; exit 1
                fi ;;
            -ks|--keep-snapshot) PROTECT=true; shift ;;
            -f|--force-delete) FORCE_DELETE=true; shift ;;
            -k|--keep)
                if [[ "$2" =~ ^[0-9]+$ ]]; then
                    TEMP_LIMIT="$2"; shift 2
                else
                    ui_error "Flag -k requires a number."; exit 1
                fi ;;
            -d|--delete)
                SPEC_DELETE=true; DO_CREATE=false; DO_CLEANUP=false
                if [[ -n "$2" && "$2" != -* ]]; then
                    DELETE_PATTERN="$2"; shift 2
                else
                    shift
                fi ;;
            -r|--rsync)
                local r_id
                r_id=$(find_backend_by_format "rsync")
                SNAPSHOT_BACKEND="${r_id:-timeshift-rsync}"
                shift ;;
            -b|--btrfs)
                local b_id
                b_id=$(find_backend_by_format "btrfs")
                SNAPSHOT_BACKEND="${b_id:-timeshift-btrfs}"
                shift ;;
            -sd|--snapshot-device)
                if [[ -n "$2" && "$2" != -* ]]; then
                    SNAPSHOT_DEVICE="$2"; shift 2
                else
                    ui_error "Flag -sd requires a device."; exit 1
                fi ;;
            -v|--verbose|--debug) VERBOSE=true; shift ;;
            -V|--version) echo "Checkpoint v$VERSION${BUILD:+ (build $BUILD)}"; exit 0 ;;
            -U|--self-update|--selfupdate)
                self_update
                exit $? ;;
            -c=*|--changelog=*)
                show_changelog "${1#*=}"; exit $? ;;
            -c|--changelog)
                if [[ "$2" =~ ^(--latest|--all|all|current|--current|-h|--help|-V|--version)$ || ( -n "$2" && "$2" != -* ) ]]; then
                    show_changelog "$2"; exit $?
                else
                    show_changelog; exit $?
                fi ;;
            -ch|--check)
                run_checkpoint check "${@:2}"
                exit $? ;;
            -h|--help)
                echo -e "${C_YELLOW}${C_BOLD}Checkpoint v$VERSION${BUILD:+ (build $BUILD)}${C_RESET}"
                echo -e "Usage: ${C_GREEN}checkpoint [OPTIONS] [SUBCOMMAND]${C_RESET}"
                echo ""
                echo -e "${C_BOLD}Snapshot Actions:${C_RESET}"
                echo -e "  $(e 📸)${C_CYAN}create${C_RESET}                     Create snapshot (default action)."
                echo -e "  $(e 🔍)${C_CYAN}-ch, --check${C_RESET}               Verify snapshot backend readiness."
                echo -e "  $(e 🆕)${C_CYAN}-nc, --no-cleanup${C_RESET}          Create snapshot without running cleanup."
                echo -e "  $(e 🧹)${C_CYAN}-cl, --cleanup-only${C_RESET}        Run cleanup logic only (keeping last $DEFAULT_KEEP_LIMIT)."
                echo -e "  $(e 📋)${C_CYAN}-l,  --list${C_RESET}                List existing snapshots in a clean table."
                echo -e "  $(e 🗑️)${C_CYAN}-d,  --delete [query]${C_RESET}      Targeted deletion: Opens a menu or matches a pattern."
                echo ""
                echo -e "${C_BOLD}Modifiers:${C_RESET}"
                echo -e "  $(e 💬)${C_PURP}-m,  --comment <msg>${C_RESET}          Add a custom description to the snapshot."
                echo -e "  $(e 🔒)${C_PURP}-ks, --keep-snapshot${C_RESET}          Mark as [KEEP] (won't be auto-deleted)."
                echo -e "  $(e 🔥)${C_PURP}-f,  --force-delete${C_RESET}           Override protection and delete [KEEP] snapshots."
                echo -e "  $(e 🔟)${C_PURP}-k,  --keep <N>${C_RESET}               Temporary retention override limit."
                echo -e "  $(e ⏱️)${C_PURP}-r,  --rsync${C_RESET}                  Force RSYNC snapshot mode."
                echo -e "  $(e ⚡)${C_PURP}-b,  --btrfs${C_RESET}                  Force BTRFS snapshot mode."
                echo -e "  $(e 💾)${C_PURP}-sd, --snapshot-device <dev>${C_RESET}  Override backup device path/UUID."
                echo -e "  $(e 🔌)${C_PURP}--backend <name>${C_RESET}              Select snapshot backend (e.g. snapper, timeshift-btrfs)."
                echo -e "  $(e 🏷️)${C_PURP}--type <type>${C_RESET}                 Snapshot type for paired backends (single, pre, post)."
                echo -e "  $(e 🔗)${C_PURP}--pre-id <id>${C_RESET}                 Link post-snapshot to pre-snapshot ID."
                echo -e "  $(e 🤖)${C_PURP}--porcelain${C_RESET}                   Machine-readable KEY=VALUE output for external IPC."
                echo ""
                echo -e "${C_BOLD}General:${C_RESET}"
                echo -e "  $(e 🔄)${C_PURP}-U, --self-update, --selfupdate${C_RESET}  Update Checkpoint from local git repository."
                echo -e "  $(e 📜)${C_PURP}-c,   --changelog [ver]${C_RESET}          View release notes or open FZF browser."
                echo -e "  $(e ℹ️)${C_PURP}-V,   --version${C_RESET}                  Print version information and exit."
                echo -e "  $(e 🔍)${C_PURP}-v,   --verbose, --debug${C_RESET}         Enable detailed execution logs."
                echo -e "  $(e ❓)${C_PURP}-h,   --help${C_RESET}                     Display command usage and options."
                echo ""
                echo -e "${C_BOLD}Subcommands:${C_RESET}"
                echo -e "  $(e 🔍)${C_GREEN}check${C_RESET}                      Verify snapshot backend readiness."
                echo -e "  $(e ⚙️)${C_GREEN}config${C_RESET}                     Interactive settings menu."
                echo -e "  $(e 🔌)${C_GREEN}backend, backends${C_RESET}          Interactive backend management and custom wizard."
                echo -e "  $(e 📜)${C_GREEN}changelog [version]${C_RESET}        View changelog or open interactive release notes browser."
                echo -e "  $(e 🔄)${C_GREEN}self-update, selfupdate${C_RESET}    Update script from local git repository."
                return 0 ;;
            *) ui_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    load_backend
    if [[ "$PORCELAIN" == true ]]; then
        USE_COLOR=false
        USE_EMOJI=false
        setup_colors
    fi

    if [[ "$PORCELAIN" == false ]]; then
        check_for_tool_updates "$@"
    fi

    [[ "$PROTECT" == true ]] && COMMENT="$COMMENT [KEEP]"

    if [[ -z "$BACKEND_REQUIRES_CMD" ]] || ! command -v "$BACKEND_REQUIRES_CMD" >/dev/null 2>&1; then
        local missing_bin="${BACKEND_REQUIRES_CMD:-unknown}"
        local b_label="${BACKEND_NAME:-None configured}"
        if [[ -z "$BACKEND_ID" ]]; then
            if [[ "$PORCELAIN" == true ]]; then
                backend_porcelain_output "error" "" "No snapshot backend configured or installed."
                exit 1
            else
                ui_error "No snapshot backend configured or installed. Install Timeshift or Snapper to enable snapshots."
                exit 1
            fi
        fi
        if [[ "$PORCELAIN" == true ]]; then
            backend_porcelain_output "error" "" "Required binary '$missing_bin' for backend '${BACKEND_ID:-unknown}' is missing."
            exit 1
        else
            ui_error "Snapshot backend binary '$missing_bin' ($b_label) is missing."
            exit 1
        fi
    fi

    if [[ "$SPEC_DELETE" == false && "$LIST_ONLY" == false ]]; then
        ensure_sudo
    fi

    if [[ "$LIST_ONLY" == true ]]; then
        ensure_sudo

        local SNAPS
        SNAPS=$(backend_list_snapshots)
        if [[ "$PORCELAIN" == true ]]; then
            [[ -n "$SNAPS" ]] && echo -e "$SNAPS"
            exit 0
        fi

        echo -e "\n$(e 📋)${C_CYAN}${C_BOLD}[Snapshots: $BACKEND_NAME]${C_RESET}"
        if [[ -z "$SNAPS" ]]; then
            ui_info "No snapshots found for backend $BACKEND_NAME."
            exit 0
        fi
        echo -e "${C_BOLD}  $(printf '%-22s' 'SNAPSHOT ID')  ${C_BLUE}│${C_RESET}${C_BOLD}  DESCRIPTION${C_RESET}"
        echo -e "  $(printf '─%.0s' {1..22})──${C_BLUE}┼${C_RESET}────────────────────────────────────────"
        while IFS='|' read -r s_id s_desc; do
            s_id=$(trim "$s_id")
            s_desc=$(trim "$s_desc")
            [[ -z "$s_id" ]] && continue
            local tag_color="$C_RESET"
            [[ "$s_desc" == *"[KEEP]"* ]] && tag_color="$C_PURP"
            printf "  ${C_YELLOW}%-22s${C_RESET}  ${C_BLUE}│${C_RESET}  ${tag_color}%s${C_RESET}\n" "$s_id" "$s_desc"
        done <<< "$SNAPS"
        echo ""
        exit 0
    fi

    if [[ "$SPEC_DELETE" == true ]]; then
        echo -e "\n$(e 🗑️)${C_CYAN}${C_BOLD}[Phase: Targeted Deletion ($BACKEND_NAME)]${C_RESET}"
        local SNAPS=""
        ensure_sudo
        ui_debug "Listing snapshots..."
        SNAPS=$(backend_list_snapshots)
        [[ -z "$SNAPS" ]] && { ui_info "No snapshots found."; exit 0; }

        local FORMATTED_SNAPS=""
        local COLOR_SNAPS=""
        while IFS='|' read -r s_id s_desc; do
            s_id=$(trim "$s_id")
            s_desc=$(trim "$s_desc")
            [[ -z "$s_id" ]] && continue

            local plain_row
            plain_row=$(printf "%-22s  |  %s" "$s_id" "$s_desc")
            if [[ -z "$FORMATTED_SNAPS" ]]; then
                FORMATTED_SNAPS="$plain_row"
            else
                FORMATTED_SNAPS+=$'\n'"$plain_row"
            fi

            local tag_color="$C_RESET"
            [[ "$s_desc" == *"[KEEP]"* ]] && tag_color="$C_PURP"
            local color_row
            color_row=$(printf "${C_YELLOW}%-22s${C_RESET}  ${C_BLUE}|${C_RESET}  ${tag_color}%s${C_RESET}" "$s_id" "$s_desc")
            if [[ -z "$COLOR_SNAPS" ]]; then
                COLOR_SNAPS="$color_row"
            else
                COLOR_SNAPS+=$'\n'"$color_row"
            fi
        done <<< "$SNAPS"

        local TARGET=""
        if [[ -z "$DELETE_PATTERN" ]]; then
            if ! ensure_fzf; then
                ui_error "fzf is required for interactive selection. Provide a pattern: checkpoint -d <pattern>"
                exit 1
            fi
            if [[ ! -t 0 ]]; then
                ui_error "Interactive deletion menu requires a terminal. Provide a pattern: checkpoint -d <pattern>"
                exit 1
            fi
            local del_prompt="Delete > "
            [[ "$USE_EMOJI" == true ]] && del_prompt="🗑️  Delete > "
            if [[ "$USE_COLOR" == true ]]; then
                TARGET=$(echo -e "$COLOR_SNAPS" | fzf --ansi --height 45% --reverse --header "Select snapshot to delete (ESC to cancel)" --prompt "$del_prompt")
            else
                TARGET=$(echo -e "$FORMATTED_SNAPS" | fzf --height 45% --reverse --header "Select snapshot to delete (ESC to cancel)" --prompt "$del_prompt")
            fi
        else
            TARGET=$(echo -e "$FORMATTED_SNAPS" | grep -i "$DELETE_PATTERN" | head -n 1)
        fi

        if [[ -z "$TARGET" ]]; then
            if [[ -n "$DELETE_PATTERN" ]]; then
                ui_info "No snapshots matched '$DELETE_PATTERN'."
            else
                ui_info "Cancelled."
            fi
            exit 0
        fi
        
        # Clean ANSI escapes if color was used
        local TARGET_CLEAN
        TARGET_CLEAN=$(echo "$TARGET" | sed -E "s/\x1B\[[0-9;]*[a-zA-Z]//g")
        local T_NAME
        T_NAME=$(echo "$TARGET_CLEAN" | cut -d'|' -f1 | tr -d ' ')
        local T_COMM
        T_COMM=$(echo "$TARGET_CLEAN" | cut -d'|' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ "$T_COMM" == *"[KEEP]"* && "$FORCE_DELETE" != "true" ]]; then
            ui_error "Snapshot protected ([KEEP]). Use -f/--force-delete to override."
            exit 1
        fi
        
        echo -e "\n${C_BOLD}Targeted Deletion${C_RESET}\n──────────────────────────────────────────────────"
        echo -e "  Backend:     ${C_CYAN}${BACKEND_NAME}${C_RESET}"
        echo -e "  Snapshot ID: ${C_YELLOW}${T_NAME}${C_RESET}"
        echo -e "  Description: ${C_CYAN}${T_COMM}${C_RESET}"
        if [[ "$T_COMM" == *"[KEEP]"* ]]; then
            echo -e "  Protection:  ${C_PURP}Protected [KEEP] (Force Override Active)${C_RESET}"
        fi
        echo -e "──────────────────────────────────────────────────"
        local q_i="$(e ❓)"
        [[ "$USE_EMOJI" == false ]] && q_i="${C_BOLD}${C_YELLOW}[CONFIRM]${C_RESET} "
        echo -n -e "${q_i}${C_BOLD}${C_RED}Permanently delete snapshot '${T_NAME}'? [y/N] ${C_RESET}"
        read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then 
            backend_delete_snapshot "$T_NAME" && ui_ok "Snapshot '${T_NAME}' deleted successfully."
        else
            ui_info "Deletion aborted."
        fi
        exit 0
    fi
 
    if [[ "$DO_CREATE" == true ]]; then
        if [[ "$PORCELAIN" != true ]]; then
            echo -e "\n$(e 📸)${C_CYAN}${C_BOLD}[Phase: Create Snapshot ($BACKEND_NAME)]${C_RESET}"
            ui_info "Creating snapshot..."
        fi
        if backend_create_snapshot "$SNAP_TYPE" "$COMMENT" "$PRE_ID"; then
            if [[ "$PORCELAIN" == true ]]; then
                backend_porcelain_output "ok" "$CREATED_SNAP_ID" ""
            else
                ui_ok "Snapshot created: ${CREATED_SNAP_ID:-done}"
            fi
        else
            if [[ "$PORCELAIN" == true ]]; then
                backend_porcelain_output "error" "" "Failed to create snapshot with backend $BACKEND_ID"
            fi
            exit 1
        fi
    fi
 
    if [[ "$DO_CLEANUP" == true ]]; then
        if [[ "$PORCELAIN" != true ]]; then
            echo -e "\n$(e 🧹)${C_CYAN}${C_BOLD}[Phase: Cleanup ($BACKEND_NAME)]${C_RESET}"
            ui_info "Cleaning up (Limit: $TEMP_LIMIT normal)..."
        fi
        local RAW
        RAW=$(backend_list_snapshots)
        local ALL=()
        mapfile -t ALL <<< "$RAW"
        local COUNT=0
        local DEL=0
        local SKIPPED=0
        for LINE in "${ALL[@]}"; do
            [[ -z "$LINE" ]] && continue
            local S_NAME="${LINE%%|*}"
            local S_COMM="${LINE#*|}"
            S_NAME=$(trim "$S_NAME")
            S_COMM=$(trim "$S_COMM")
            if [[ "$S_COMM" == *"[KEEP]"* && "$FORCE_DELETE" != "true" ]]; then
                ((SKIPPED++))
                continue
            fi
            ((COUNT++))
            if [[ $COUNT -gt $TEMP_LIMIT ]]; then
                [[ "$PORCELAIN" != true ]] && echo -e "$(e 🗑️)${C_RED}Deleting:${C_RESET} ${C_YELLOW}$S_NAME${C_RESET}"
                backend_delete_snapshot "$S_NAME" && ((DEL++))
            fi
        done
        if [[ "$PORCELAIN" != true ]]; then
            [[ $SKIPPED -gt 0 ]] && ui_info "Skipped $SKIPPED protected [KEEP] snapshots."
            ui_ok "Cleanup finished. ${C_GREEN}$DEL${C_RESET} deleted."
        fi
    fi
    [[ "$PORCELAIN" != true ]] && ui_ok "Tasks completed."
    return 0
}
