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
        target_ver=$(grep -E '^## \[' "$changelog" 2>/dev/null | head -n 1 | sed -E 's/^## \[([^]]+)\].*/\1/')
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
            if (substr($0, 1, length(prefix)) == prefix && rest ~ /^[[:space:]]*\]/) {
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
            if [[ "$is_first" == true ]]; then
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
                    if (substr($0, 1, length(prefix)) == prefix && (char1 == "]" || char1 == " " || char1 == "-")) {
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
        echo -e "${C_BOLD}Usage:${C_RESET} checkpoint changelog [VERSION|--latest|all|current]"
        echo -e "       checkpoint -c, --changelog [VERSION|--latest|all|current]"
        echo ""
        echo "Display release notes and version history."
        echo ""
        echo "Arguments:"
        echo "  [VERSION]       Display release notes for a specific version (e.g., 0.9.34 or v0.9.34)."
        echo "  --latest        Display release notes for the latest release."
        echo "  current         Display release notes for the currently running version."
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
