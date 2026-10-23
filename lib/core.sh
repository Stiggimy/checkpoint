#!/usr/bin/env bash
# ==============================================================================
# Checkpoint Module: Core & UI Helpers
# ==============================================================================

# Pure-bash trim: strips leading and trailing whitespace without subprocesses
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

_infer_required_binary() {
    local cmd="$1"
    local -a words
    read -r -a words <<< "$cmd"
    local bin=""
    local i
    for ((i=0; i<${#words[@]}; i++)); do
        local w="${words[$i]}"
        # Skip yes | prefix if present (including args like yes y | or yes "y" |)
        if [[ "$w" == "yes" ]]; then
            local p_idx=-1
            local j
            for ((j=i+1; j<${#words[@]} && j<=i+4; j++)); do
                if [[ "${words[$j]}" == "|" ]]; then
                    p_idx=$j
                    break
                fi
            done
            if [[ $p_idx -ge 0 ]]; then
                i=$p_idx
                continue
            fi
        fi
        # Strip path and quotes to identify wrapper basename
        local base_w="${w##*/}"
        base_w="${base_w%.exe}"
        base_w="${base_w//[\"\'\`]/}"
        # Skip privilege escalation, environment, and process wrappers
        if [[ "$base_w" =~ ^(sudo|doas|pkexec|env|nice|ionice|nohup|eatmydata)$ ]]; then
            continue
        fi
        # Skip environment variable assignments (e.g. FOO=bar)
        if [[ "$w" =~ ^[A-Za-z_][A-Za-z0-9_]*=.*$ ]]; then
            continue
        fi
        # Skip standalone option terminator --
        if [[ "$w" == "--" ]]; then
            continue
        fi
        # Skip wrapper flags (both short and long, e.g. -E, -u root, --user=root, --preserve-env)
        if [[ "$w" =~ ^--?[a-zA-Z0-9_-]+(=.*)?$ ]]; then
            if [[ "$w" =~ ^(-[ugphaCnc]|--(user|group|prompt|directory|class|priority))$ && $((i+1)) -lt ${#words[@]} ]]; then
                ((i++))
            fi
            continue
        fi
        # Strip path, optional .exe suffix, and any residual quotes
        bin="${w##*/}"
        bin="${bin%.exe}"
        bin="${bin//[\"\'\`]/}"
        break
    done
    echo "$bin"
}

setup_colors() {
    if [[ "$USE_COLOR" == true ]]; then
        C_RED='\033[0;31m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'
        C_BLUE='\033[0;34m'; C_PURP='\033[0;35m'; C_CYAN='\033[0;36m'
        C_BOLD='\033[1m'; C_DIM='\033[2m'; C_RESET='\033[0m'
    else
        C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_PURP=''; C_CYAN=''; C_BOLD=''; C_DIM=''; C_RESET=''
    fi
}
setup_colors

# UI Engine
ui_info() { local i="${C_CYAN}[INFO]${C_RESET} "; [[ "$USE_EMOJI" == true ]] && i="ℹ️ "; echo -e "${i}$1"; }
ui_ok()   { local i="${C_GREEN}[OK]${C_RESET} "; [[ "$USE_EMOJI" == true ]] && i="✅ "; echo -e "${i}$1"; }
ui_warn() { local i="${C_YELLOW}[WARN]${C_RESET} "; [[ "$USE_EMOJI" == true ]] && i="⚠️ "; echo -e "${i}$1"; }
ui_error(){ local i="${C_RED}[ERROR]${C_RESET} "; [[ "$USE_EMOJI" == true ]] && i="❌ "; echo -e "${i}$1"; }
ui_debug(){ [[ "$VERBOSE" == true ]] && echo -e "${C_PURP}[DEBUG]${C_RESET} $1"; }
e() { [[ "$USE_EMOJI" == true ]] && echo -n "$1 "; }

# --- Changelog & Release Notes Engine ---

get_changelog_path() {
    if [[ -n "${SOURCE_DIR:-}" && -f "$SOURCE_DIR/CHANGELOG.md" ]]; then
        echo "$SOURCE_DIR/CHANGELOG.md"
    elif [[ -f "$HOME/.local/share/checkpoint/CHANGELOG.md" ]]; then
        echo "$HOME/.local/share/checkpoint/CHANGELOG.md"
    elif [[ -f "/usr/share/checkpoint/CHANGELOG.md" ]]; then
        echo "/usr/share/checkpoint/CHANGELOG.md"
    else
        local d
        d="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
        if [[ -f "$d/CHANGELOG.md" ]]; then
            echo "$d/CHANGELOG.md"
        fi
    fi
}

extract_changelog_section() {
    local target_ver="${1:-latest}"
    local changelog="${2:-$(get_changelog_path)}"
    [[ -z "$changelog" || ! -f "$changelog" ]] && return 1

    if [[ "$target_ver" == "latest" || "$target_ver" == "--latest" || -z "$target_ver" ]]; then
        target_ver=$(grep -E '^## \[[0-9]' "$changelog" 2>/dev/null | head -n 1 | sed -E 's/^## \[([^]]+)\].*/\1/')
        if [[ -z "$target_ver" ]]; then
            target_ver=$(grep -E '^## \[' "$changelog" 2>/dev/null | head -n 1 | sed -E 's/^## \[([^]]+)\].*/\1/')
        fi
    elif [[ "$target_ver" == "unreleased" || "$target_ver" == "Unreleased" || "$target_ver" == "--unreleased" || "$target_ver" == "upcoming" ]]; then
        target_ver="Unreleased"
    elif [[ "$target_ver" == "current" || "$target_ver" == "--current" ]]; then
        target_ver="${VERSION:-}"
        if [[ -z "$target_ver" && -n "${SOURCE_DIR:-}" && -f "$SOURCE_DIR/checkpoint" ]]; then
            target_ver=$(grep '^VERSION=' "$SOURCE_DIR/checkpoint" 2>/dev/null | head -n 1 | cut -d'"' -f2)
        fi
    fi
    target_ver="${target_ver#[vV]}"
    target_ver="${target_ver#[}"
    target_ver="${target_ver%]}"
    target_ver="${target_ver#[vV]}"
    target_ver="${target_ver#[}"
    target_ver="${target_ver%]}"

    awk -v target="$target_ver" '
        BEGIN { in_ver = 0 }
        $0 ~ /^## \[/ {
            if (in_ver) exit
            prefix = "## [" target
            rest = substr($0, length(prefix) + 1)
            if (tolower(substr($0, 1, length(prefix))) == tolower(prefix) && rest ~ /^[[:space:]]*\]/) {
                in_ver = 1
                print
                next
            }
        }
        in_ver { print }
    ' "$changelog"
}

format_changelog_markdown() {
    local use_col="${USE_COLOR:-true}"
    if [[ ! -t 1 && "${FORCE_COLOR:-false}" != true && -z "${FZF_PREVIEW_LINES:-}" && -z "${FZF_PREVIEW_COLUMNS:-}" ]]; then
        use_col=false
    fi
    if [[ "$use_col" == true ]]; then
        awk '
            BEGIN {
                C_YELLOW = "\033[1;33m"
                C_GREEN  = "\033[1;32m"
                C_CYAN   = "\033[1;36m"
                C_PURP   = "\033[1;35m"
                C_BLUE   = "\033[1;34m"
                C_RED    = "\033[1;31m"
                C_BOLD   = "\033[1m"
                C_DIM    = "\033[2m"
                C_RESET  = "\033[0m"
            }
            /^## \[/ {
                print C_YELLOW $0 C_RESET
                next
            }
            /^### Added/ {
                print C_GREEN $0 C_RESET
                next
            }
            /^### Changed/ {
                print C_CYAN $0 C_RESET
                next
            }
            /^### Fixed/ {
                print C_PURP $0 C_RESET
                next
            }
            /^### (Removed|Deprecated)/ {
                print C_RED $0 C_RESET
                next
            }
            /^### / {
                print C_BLUE $0 C_RESET
                next
            }
            /^- \*\*/ {
                line = $0
                sub(/^- \*\*/, "  " C_BOLD "• ", line)
                if (!sub(/\*\*:/, ":" C_RESET, line)) {
                    sub(/\*\*/, C_RESET, line)
                }
                print line
                next
            }
            /^- / {
                line = $0
                sub(/^- /, "  " C_DIM "• " C_RESET, line)
                print line
                next
            }
            { print }
        '
    else
        cat
    fi
}

display_changelog() {
    local target_ver="${1:-latest}"
    local changelog
    changelog=$(get_changelog_path)
    if [[ -z "$changelog" || ! -f "$changelog" ]]; then
        ui_error "Changelog not found."
        return 1
    fi

    if [[ "$target_ver" == "all" || "$target_ver" == "--all" ]]; then
        awk '/^## \[/ { found = 1 } found { print }' "$changelog" | format_changelog_markdown
        return 0
    fi

    local content
    content=$(extract_changelog_section "$target_ver" "$changelog")
    if [[ -z "$content" ]]; then
        ui_error "Version '$target_ver' not found in changelog."
        return 1
    fi
    echo "$content" | format_changelog_markdown
}

browse_changelog_interactive() {
    local changelog
    changelog=$(get_changelog_path)
    if [[ -z "$changelog" || ! -f "$changelog" ]]; then
        ui_error "Changelog not found."
        return 1
    fi

    local lines=()
    local is_first=true
    while IFS= read -r line; do
        if [[ "$line" =~ ^##\ \[([^]]+)\]([[:space:]]*[-—–][[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2}))? ]]; then
            local ver="${BASH_REMATCH[1]}"
            local dt="${BASH_REMATCH[3]:-}"
            local tag=""
            if [[ "${ver,,}" == "unreleased" ]]; then
                dt="(upcoming)"
                tag=" 🚧 in development"
            elif [[ "$is_first" == true ]]; then
                tag=" ★ latest"
                is_first=false
            fi
            lines+=("$(printf "%-10s  %-12s %s" "$ver" "$dt" "$tag")")
        fi
    done < "$changelog"

    if [[ ${#lines[@]} -eq 0 ]]; then
        ui_warn "No version sections found in changelog."
        return 0
    fi

    local choice
    choice=$(
        export CL_FILE="$changelog"
        printf "%s\n" "${lines[@]}" | fzf --ansi --reverse --height=85% \
            --header "--- Checkpoint Release Notes Browser (Enter to view, ESC to exit) ---" \
            --preview 'awk -v target="{1}" '\''
                BEGIN {
                    in_ver = 0
                    C_YELLOW = "\033[1;33m"; C_GREEN = "\033[1;32m"; C_CYAN = "\033[1;36m"
                    C_PURP = "\033[1;35m"; C_BLUE = "\033[1;34m"; C_RED = "\033[1;31m"
                    C_BOLD = "\033[1m"; C_DIM = "\033[2m"; C_RESET = "\033[0m"
                }
                $0 ~ /^## \[/ {
                    if (in_ver) exit
                    prefix = "## [" target
                    rest = substr($0, length(prefix) + 1)
                    char1 = substr(rest, 1, 1)
                    if (tolower(substr($0, 1, length(prefix))) == tolower(prefix) && (char1 == "]" || char1 == " " || char1 == "-")) {
                        in_ver = 1
                        print C_YELLOW $0 C_RESET
                        next
                    }
                }
                !in_ver { next }
                /^### Added/    { print C_GREEN $0 C_RESET; next }
                /^### Changed/  { print C_CYAN $0 C_RESET; next }
                /^### Fixed/    { print C_PURP $0 C_RESET; next }
                /^### (Removed|Deprecated)/ { print C_RED $0 C_RESET; next }
                /^### /         { print C_BLUE $0 C_RESET; next }
                /^- \*\*/ {
                    line = $0
                    sub(/^- \*\*/, "  " C_BOLD "• ", line)
                    sub(/\*\*:/, ":" C_RESET, line)
                    sub(/\*\*/, C_RESET, line)
                    print line
                    next
                }
                /^- / {
                    line = $0
                    sub(/^- /, "  " C_DIM "• " C_RESET, line)
                    print line
                    next
                }
                { print }
            '\'' "$CL_FILE"' \
            --preview-window=right:65%:wrap
    )
    local sel_ver="${choice%% *}"
    if [[ -n "$sel_ver" ]]; then
        echo ""
        display_changelog "$sel_ver"
        return 2
    fi
    return 0
}

show_changelog() {
    local req_ver="$1"
    if [[ "$req_ver" == "-h" || "$req_ver" == "--help" ]]; then
        echo -e "${C_BOLD}Usage:${C_RESET} checkpoint changelog [VERSION|--latest|all|current|unreleased]"
        echo -e "       checkpoint -c, --changelog [VERSION|--latest|all|current|unreleased]"
        echo ""
        echo "Display release notes and version history."
        echo ""
        echo "Arguments:"
        echo "  [VERSION]       Display release notes for a specific version (e.g., 0.9.34 or v0.9.34)."
        echo "  --latest        Display release notes for the latest release."
        echo "  current         Display release notes for the currently running version."
        echo "  unreleased      Display upcoming features currently in development."
        echo "  all, --all      Display complete formatted changelog history."
        echo "  -h, --help      Display this help message."
        echo "  -V, --version   Display version information."
        echo ""
        echo "When run in an interactive terminal with 'fzf' available and no version specified,"
        echo "an interactive version browser will open with real-time preview."
        return 0
    fi
    if [[ "$req_ver" == "-V" || "$req_ver" == "--version" ]]; then
        echo "Checkpoint v$VERSION${BUILD:+ (build $BUILD)}"
        return 0
    fi

    if [[ -n "$req_ver" ]]; then
        display_changelog "$req_ver"
        return $?
    fi

    if [[ -t 0 && -t 1 ]] && command -v fzf >/dev/null 2>&1; then
        browse_changelog_interactive
        local res=$?
        [[ $res -eq 2 ]] && return 0
        return $res
    fi

    display_changelog "latest"
    return $?
}

# --- Interactive Dependency Auto-Installer ---
ensure_fzf() {
    command -v fzf >/dev/null 2>&1 && return 0
    if [[ -x "$HOME/.local/bin/fzf" ]]; then
        [[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && PATH="$HOME/.local/bin:$PATH"
        return 0
    elif [[ -x "$HOME/.fzf/bin/fzf" ]]; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$HOME/.fzf/bin/fzf" "$HOME/.local/bin/fzf"
        [[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && PATH="$HOME/.local/bin:$PATH"
        return 0
    fi

    ui_info "fzf is required for interactive menus. Installing automatically..."

    local installed=false
    local cat_dir=""
    for cand in "$HOME/.local/share/advance/catalog" "$HOME/.local/share/checkpoint/catalog" "/usr/share/advance/catalog" "${SOURCE_DIR:-}/catalog" "${SOURCE_DIR:-}/../advance/catalog"; do
        if [[ -d "$cand" ]]; then cat_dir="$cand"; break; fi
    done

    local -a conf_dirs=()
    [[ -n "$cat_dir" && -d "$cat_dir" ]] && conf_dirs+=("$cat_dir")

    for dir in "${conf_dirs[@]}"; do
        while IFS= read -r conf; do
            [[ ! -f "$conf" ]] && continue
            local req probe_cmd inst_cmd
            req=$(grep '^REQUIRES_CMD=' "$conf" 2>/dev/null | head -1 | cut -d'=' -f2-)
            probe_cmd=$(grep '^PROBE_ACTIVE_CMD=' "$conf" 2>/dev/null | head -1 | cut -d'=' -f2-)
            inst_cmd=$(grep '^INSTALL_CMD=' "$conf" 2>/dev/null | head -1 | cut -d'=' -f2-)

            if [[ -n "$inst_cmd" && -n "$req" ]] && command -v "$req" >/dev/null 2>&1; then
                if [[ -z "$probe_cmd" ]] || eval "$probe_cmd" >/dev/null 2>&1; then
                    # Avoid non-interactive password prompt hangs
                    if [[ "$inst_cmd" == *sudo* ]] && ! sudo -n true 2>/dev/null && [ ! -t 0 ]; then
                        continue
                    fi
                    ui_info "Installing fzf via $req ($inst_cmd fzf)..."
                    if eval "$inst_cmd fzf"; then
                        installed=true
                        break 2
                    fi
                fi
            fi
        done < <(find "$dir" -type f -name "*.conf" 2>/dev/null | sort)
    done

    # Fallback to user-level binary installer if package manager failed or unavailable
    if ! command -v fzf >/dev/null 2>&1; then
        local fzf_dir="$HOME/.fzf"
        if command -v git >/dev/null 2>&1; then
            ui_info "Attempting user-level fzf installation via official repository..."
            if [[ ! -d "$fzf_dir" ]]; then
                git clone --depth 1 https://github.com/junegunn/fzf.git "$fzf_dir" >/dev/null 2>&1 || true
            fi
            if [[ -x "$fzf_dir/install" ]]; then
                "$fzf_dir/install" --bin >/dev/null 2>&1 || true
                if [[ -x "$fzf_dir/bin/fzf" ]]; then
                    mkdir -p "$HOME/.local/bin"
                    ln -sf "$fzf_dir/bin/fzf" "$HOME/.local/bin/fzf"
                    [[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && PATH="$HOME/.local/bin:$PATH"
                fi
            fi
        fi
    fi

    if command -v fzf >/dev/null 2>&1; then
        ui_ok "fzf installed successfully!"
        return 0
    else
        ui_error "Failed to install fzf automatically. Please install fzf manually."
        return 1
    fi
}

# ==============================================================================
# --- Smart Self-Update Detector ---
# ==============================================================================

_refresh_self_update_cache() {
    (
        local s_dir="${SOURCE_DIR:-}"
        [[ -z "$s_dir" || ! -d "$s_dir/.git" ]] && exit 0
        git -C "$s_dir" remote 2>/dev/null | grep -qx 'origin' || exit 0

        local branch
        branch=$(git -C "$s_dir" branch --show-current 2>/dev/null)
        branch=${branch:-master}

        if command -v timeout >/dev/null 2>&1; then
            timeout 3s git -C "$s_dir" fetch -q origin "$branch" 2>/dev/null || exit 0
        else
            git -C "$s_dir" fetch -q origin "$branch" 2>/dev/null || exit 0
        fi

        local local_head remote_head behind
        local_head=$(git -C "$s_dir" rev-parse HEAD 2>/dev/null)
        remote_head=$(git -C "$s_dir" rev-parse "origin/$branch" 2>/dev/null)
        behind=$(git -C "$s_dir" rev-list --count "HEAD..origin/$branch" 2>/dev/null || echo 0)

        local remote_content remote_ver remote_build
        remote_content=$(git -C "$s_dir" show "origin/$branch:checkpoint" 2>/dev/null || true)
        remote_ver=$(echo "$remote_content" | grep '^VERSION=' 2>/dev/null | head -n 1 | cut -d'"' -f2)
        remote_build=$(echo "$remote_content" | grep '^BUILD=' 2>/dev/null | head -n 1 | cut -d'"' -f2)

        local c_file="${CHECKPOINT_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/checkpoint}/self_update.cache"
        local cur_skipped=""
        if [[ -f "$c_file" ]]; then
            cur_skipped=$(grep '^SKIPPED_HEAD=' "$c_file" 2>/dev/null | head -n 1 | cut -d'=' -f2-)
        fi

        local now
        now=$(date +%s)
        mkdir -p "$(dirname "$c_file")" 2>/dev/null
        local tmp_file="${c_file}.tmp.$$"
        {
            echo "LAST_CHECK=$now"
            echo "LOCAL_HEAD=$local_head"
            echo "REMOTE_HEAD=$remote_head"
            echo "COMMITS_BEHIND=$behind"
            echo "REMOTE_VER=$remote_ver"
            echo "REMOTE_BUILD=$remote_build"
            echo "SKIPPED_HEAD=$cur_skipped"
        } > "$tmp_file" && mv -f "$tmp_file" "$c_file" 2>/dev/null
    ) >/dev/null 2>&1 &
}

check_for_tool_updates() {
    [[ "${SELF_UPDATE_CHECK:-prompt}" == "off" || "${SELF_UPDATE_CHECK:-prompt}" == "false" ]] && return 0
    [[ "${PORCELAIN:-false}" == true ]] && return 0
    [[ -n "${ADVANCE_SELF_UPDATED:-}" || -n "${CHECKPOINT_SELF_UPDATED:-}" ]] && return 0

    if declare -f detect_source_dir >/dev/null 2>&1; then
        detect_source_dir
    fi
    [[ -z "${SOURCE_DIR:-}" || ! -d "$SOURCE_DIR/.git" || ! -x "$SOURCE_DIR/install.sh" ]] && return 0

    local cache_file="${CHECKPOINT_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/checkpoint}/self_update.cache"
    local LAST_CHECK=0
    local LOCAL_HEAD=""
    local REMOTE_HEAD=""
    local COMMITS_BEHIND=0
    local REMOTE_VER=""
    local REMOTE_BUILD=""
    local SKIPPED_HEAD=""

    if [[ -f "$cache_file" ]]; then
        while IFS='=' read -r key val || [[ -n "$key" ]]; do
            key="${key#"${key%%[![:space:]]*}"}"; key="${key%"${key##*[![:space:]]}"}"
            val="${val#"${val%%[![:space:]]*}"}"; val="${val%"${val##*[![:space:]]}"}"
            key="${key%$'\r'}"; val="${val%$'\r'}"
            case "$key" in
                LAST_CHECK) LAST_CHECK="$val" ;;
                LOCAL_HEAD) LOCAL_HEAD="$val" ;;
                REMOTE_HEAD) REMOTE_HEAD="$val" ;;
                COMMITS_BEHIND) COMMITS_BEHIND="$val" ;;
                REMOTE_VER) REMOTE_VER="$val" ;;
                REMOTE_BUILD) REMOTE_BUILD="$val" ;;
                SKIPPED_HEAD) SKIPPED_HEAD="$val" ;;
            esac
        done < "$cache_file"
    fi

    local cur_head now
    cur_head=$(git -C "$SOURCE_DIR" rev-parse HEAD 2>/dev/null)
    now=$(date +%s)

    if [[ -n "$LOCAL_HEAD" && "$LOCAL_HEAD" != "$cur_head" ]]; then
        COMMITS_BEHIND=0
    fi

    if [[ ! -f "$cache_file" || $((now - ${LAST_CHECK:-0})) -ge 21600 ]]; then
        (_refresh_self_update_cache &)
    fi

    if [[ ${COMMITS_BEHIND:-0} -gt 0 && -n "$REMOTE_HEAD" && "${SKIPPED_HEAD:-}" != "$REMOTE_HEAD" ]]; then
        local ver_info="v${REMOTE_VER:-$VERSION}${REMOTE_BUILD:+ (build $REMOTE_BUILD)}, ${COMMITS_BEHIND} commit(s) ahead"
        if [[ "${SELF_UPDATE_CHECK:-prompt}" == "notify" || ! -t 0 || ! -t 1 ]]; then
            ui_info "${C_BOLD}${C_YELLOW}New version of Checkpoint available ($ver_info)!${C_RESET} Run '${C_GREEN}checkpoint -U${C_RESET}' to update."
        elif [[ "${SELF_UPDATE_CHECK:-prompt}" == "auto" ]]; then
            ui_info "New version of Checkpoint available ($ver_info). Auto-updating..."
            if declare -f ensure_menu_loaded >/dev/null 2>&1; then ensure_menu_loaded; fi
            if self_update; then
                rm -f "$cache_file"
                export CHECKPOINT_SELF_UPDATED=1
                exec "$0" "$@"
            fi
        else
            echo ""
            ui_info "${C_BOLD}${C_YELLOW}A new version of Checkpoint is available!${C_RESET} ${C_CYAN}($ver_info)${C_RESET}"
            echo -e "  [${C_GREEN}Y${C_RESET}] Update now   [${C_CYAN}N${C_RESET}] Skip this version   [${C_PURP}A${C_RESET}] Always auto-update   [${C_RED}D${C_RESET}] Disable checks"
            echo -n -e "${C_BOLD}Choice [Y/n/a/d]: ${C_RESET}"
            local u_choice=""
            read -r -n 1 u_choice
            echo ""
            case "$u_choice" in
                ""|[Yy])
                    if declare -f ensure_menu_loaded >/dev/null 2>&1; then ensure_menu_loaded; fi
                    if self_update; then
                        rm -f "$cache_file"
                        export CHECKPOINT_SELF_UPDATED=1
                        exec "$0" "$@"
                    fi
                    ;;
                [Aa])
                    SELF_UPDATE_CHECK="auto"
                    save_config
                    ui_ok "Self-update mode set to: Auto-Update."
                    if declare -f ensure_menu_loaded >/dev/null 2>&1; then ensure_menu_loaded; fi
                    if self_update; then
                        rm -f "$cache_file"
                        export CHECKPOINT_SELF_UPDATED=1
                        exec "$0" "$@"
                    fi
                    ;;
                [Dd])
                    SELF_UPDATE_CHECK="off"
                    save_config
                    ui_info "Automatic update checks disabled. Re-enable anytime in 'checkpoint config'."
                    ;;
                [Nn]|*)
                    mkdir -p "$(dirname "$cache_file")" 2>/dev/null
                    local tmp_f="${cache_file}.tmp.$$"
                    {
                        echo "LAST_CHECK=$now"
                        echo "LOCAL_HEAD=${LOCAL_HEAD:-$cur_head}"
                        echo "REMOTE_HEAD=$REMOTE_HEAD"
                        echo "COMMITS_BEHIND=$COMMITS_BEHIND"
                        echo "REMOTE_VER=$REMOTE_VER"
                        echo "REMOTE_BUILD=$REMOTE_BUILD"
                        echo "SKIPPED_HEAD=$REMOTE_HEAD"
                    } > "$tmp_f" && mv -f "$tmp_f" "$cache_file" 2>/dev/null
                    ui_info "Skipping update for now."
                    ;;
            esac
        fi
    fi
    return 0
}
