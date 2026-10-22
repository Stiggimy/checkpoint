#!/usr/bin/env bash
# ==============================================================================
# Checkpoint Module: Attention System & Retry Engine
# ==============================================================================

# --- ATTENTION SYSTEM ---
NOTIFICATION_ID=""
request_attention() {
    local msg="$1"
    echo -e "\n\e[5;31;43m ######################################################## \e[0m"
    echo -e "\e[1;31;43m # ATTENTION: USER INPUT REQUIRED! # \e[0m"
    echo -e "\e[5;31;43m ######################################################## \e[0m\n"
    if [[ "$USE_EMOJI" == true ]]; then
        echo -e "\e[1;33m"
        echo "  █████  ████████ ████████ ███████ ███    ██ ████████ ██  ██████  ███    ██ "
        echo " ██   ██    ██       ██    ██      ████   ██    ██    ██ ██    ██ ████   ██ "
        echo " ███████    ██       ██    █████   ██ ██  ██    ██    ██ ██    ██ ██ ██  ██ "
        echo " ██   ██    ██       ██    ██      ██  ██ ██    ██    ██ ██    ██ ██  ██ ██ "
        echo " ██   ██    ██       ██    ███████ ██   ████    ██    ██  ██████  ██   ████ "
        echo -e "\e[0m"
    else
        echo -e "${C_BOLD}${C_YELLOW}!!! ATTENTION REQUIRED !!!${C_RESET}"
    fi
    echo -e "\e[1;31m>>> REQUIRED ACTION: $msg <<<\e[0m\n"
    command -v notify-send >/dev/null 2>&1 && \
        NOTIFICATION_ID=$(notify-send -p "SNAPSHOT REQUIRED" "$msg" -u critical -i dialog-warning -a "checkpoint" 2>/dev/null || true)
    echo -e "\a"
}

close_attention() {
    if [[ -n "$NOTIFICATION_ID" ]] && command -v gdbus >/dev/null 2>&1; then
        gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.CloseNotification "$NOTIFICATION_ID" >/dev/null 2>&1
        NOTIFICATION_ID=""
    fi
}

# --- RETRY ENGINE ---
LAST_CMD_OUTPUT=""
run_with_retry() {
    local phase="$1"; local type="$2"; local cmd="$3"
    local attempts=0; local max_retries=$AUTO_RETRIES
    [[ "$INFINITE_RETRIES" == true ]] && max_retries=9999

    local tmp_log=""
    trap '[[ -n "$tmp_log" && -f "$tmp_log" ]] && rm -f "$tmp_log"; close_attention' INT TERM RETURN

    local prev_pipefail=false
    [[ -o pipefail ]] && prev_pipefail=true

    while true; do
        ui_debug "Attempt $((attempts + 1)): $cmd"
        set -o pipefail
        tmp_log=$(mktemp)
        eval "$cmd" 2>&1 | tee "$tmp_log"
        local exit_code=$?
        LAST_CMD_OUTPUT=$(<"$tmp_log")
        rm -f "$tmp_log"
        tmp_log=""
        [[ "$prev_pipefail" == false ]] && set +o pipefail

        [[ $exit_code -eq 0 ]] && return 0

        # Auto-Retry Logic
        if [[ $attempts -lt $max_retries ]]; then
            ((attempts++))
            ui_warn "$phase failed. Retrying in 3s ($attempts/$max_retries)..."
            sleep 3
            continue
        fi

        # Escalation
        request_attention "$phase failed after $attempts retries."
        echo -e "${C_RED}${C_BOLD}[FAIL]${C_RESET} Command: $cmd"

        if [[ ! -t 0 ]]; then
            close_attention
            if command -v notify-send >/dev/null 2>&1; then
                notify-send -u critical -a "checkpoint" -i dialog-error "Checkpoint Failed" "Snapshot operation '$phase' failed in unattended mode." 2>/dev/null || true
            fi
            ui_error "Non-interactive environment: $phase failed. Aborting."
            return 1
        fi

        local p="${C_BOLD}Action:${C_RESET} [${C_GREEN}R${C_RESET}]etry | [${C_YELLOW}S${C_RESET}]kip | [${C_RED}A${C_RESET}]bort: "
        local action
        while true; do
            echo -e -n "$p"
            if ! read -r -n 1 action; then
                echo ""
                close_attention
                return 1
            fi
            echo ""
            case "$action" in
                [Rr]) close_attention; attempts=0; break ;;
                [Ss]) close_attention; return 1 ;;
                [Aa]) close_attention; exit 1 ;;
                *) ui_warn "Invalid selection. Please enter R, S, or A." ;;
            esac
        done
    done
}
