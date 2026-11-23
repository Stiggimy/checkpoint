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

# Recursively terminates a process and all its descendants
_terminate_proc_tree() {
    local pid="$1"
    local sig="${2:-TERM}"
    [[ -z "$pid" ]] && return 0
    local child
    for child in $(pgrep -P "$pid" 2>/dev/null); do
        _terminate_proc_tree "$child" "$sig"
    done
    kill "-$sig" "$pid" 2>/dev/null || true
}

run_with_retry() {
    local phase="$1"; local type="$2"; local cmd="$3"; local stall_timeout="${4:-${STALL_TIMEOUT:-0}}"
    local attempts=0; local max_retries=$AUTO_RETRIES
    [[ "$INFINITE_RETRIES" == true ]] && max_retries=9999

    [[ -n "$stall_timeout" && "$stall_timeout" != "0" ]] && stall_timeout=$(parse_duration "$stall_timeout")
    [[ ! "$stall_timeout" =~ ^[0-9]+$ ]] && stall_timeout=0

    local tmp_log="" tmp_pipe="" cmd_pid="" tee_pid=""
    _cleanup_retry_proc() {
        if [[ -n "$cmd_pid" ]]; then
            _terminate_proc_tree "$cmd_pid" TERM 2>/dev/null || true
        fi
        if [[ -n "$tee_pid" ]]; then
            kill -TERM "$tee_pid" 2>/dev/null || true
        fi
        [[ -n "$tmp_pipe" && -p "$tmp_pipe" ]] && rm -f "$tmp_pipe"
        [[ -n "$tmp_log" && -f "$tmp_log" ]] && rm -f "$tmp_log"
        close_attention
    }
    trap '_cleanup_retry_proc' INT TERM RETURN

    local prev_pipefail=false
    [[ -o pipefail ]] && prev_pipefail=true

    while true; do
        ui_debug "Attempt $((attempts + 1)): $cmd"
        local was_stalled=false
        local exit_code=0

        if [[ $stall_timeout -gt 0 ]]; then
            tmp_pipe=$(mktemp -u)
            mkfifo "$tmp_pipe"
            tmp_log=$(mktemp)

            tee "$tmp_log" < "$tmp_pipe" &
            tee_pid=$!

            eval "$cmd" > "$tmp_pipe" 2>&1 &
            cmd_pid=$!

            local last_size=0
            local last_time
            last_time=$(date +%s)

            while kill -0 "$cmd_pid" 2>/dev/null; do
                sleep 0.5
                local now
                now=$(date +%s)
                local cur_size
                cur_size=$(wc -c < "$tmp_log" 2>/dev/null || echo 0)
                if [[ "$cur_size" -ne "$last_size" ]]; then
                    last_size="$cur_size"
                    last_time="$now"
                else
                    local elapsed=$((now - last_time))
                    if [[ $elapsed -ge $stall_timeout ]]; then
                        request_attention "$phase appears stalled (no output for ${stall_timeout}s)."
                        if [[ ! -t 0 ]]; then
                            ui_warn "Stalled snapshot operation in non-interactive environment (${stall_timeout}s without output). Terminating..."
                            _terminate_proc_tree "$cmd_pid" TERM
                            local k
                            for ((k=0; k<30; k++)); do
                                kill -0 "$cmd_pid" 2>/dev/null || break
                                sleep 0.1
                            done
                            if kill -0 "$cmd_pid" 2>/dev/null; then
                                _terminate_proc_tree "$cmd_pid" KILL
                            fi
                            was_stalled=true
                            exit_code=124
                            break
                        fi

                        echo -e "\n${C_BOLD}${C_YELLOW}⚠️  Snapshot operation appears stalled${C_RESET}${C_YELLOW} (no output produced for ${stall_timeout}s).${C_RESET}"
                        echo -e "   ${C_CYAN}Command:${C_RESET} $cmd"
                        echo -e "\nWhat would you like to do?"
                        echo -e "  [${C_GREEN}W${C_RESET}] Wait       — Give it more time (extend timeout by ${stall_timeout}s)"
                        echo -e "  [${C_YELLOW}T${C_RESET}] Terminate  — Stop this stalled command and open the error recovery menu"
                        echo -e "  [${C_RED}A${C_RESET}] Abort      — Stop snapshot and exit right now\n"

                        local s_act=""
                        while true; do
                            echo -e -n "${C_BOLD}Choice [W/t/a]:${C_RESET} "
                            read -r -n 1 s_act
                            echo ""
                            case "$s_act" in
                                [Ww]|"")
                                    close_attention
                                    last_time=$(date +%s)
                                    ui_info "Extending timeout by ${stall_timeout}s..."
                                    break
                                    ;;
                                [Tt])
                                    close_attention
                                    ui_warn "Terminating stalled command..."
                                    _terminate_proc_tree "$cmd_pid" TERM
                                    local k
                                    for ((k=0; k<30; k++)); do
                                        kill -0 "$cmd_pid" 2>/dev/null || break
                                        sleep 0.1
                                    done
                                    if kill -0 "$cmd_pid" 2>/dev/null; then
                                        _terminate_proc_tree "$cmd_pid" KILL
                                    fi
                                    was_stalled=true
                                    exit_code=124
                                    break 2
                                    ;;
                                [Aa])
                                    close_attention
                                    _terminate_proc_tree "$cmd_pid" TERM
                                    sleep 0.5
                                    _terminate_proc_tree "$cmd_pid" KILL
                                    kill -TERM "$tee_pid" 2>/dev/null || true
                                    rm -f "$tmp_pipe" "$tmp_log"
                                    exit 1
                                    ;;
                                *)
                                    ui_warn "Invalid selection. Enter W (Wait), T (Terminate), or A (Abort)."
                                    ;;
                            esac
                        done
                    fi
                fi
            done

            if [[ "$was_stalled" == false ]]; then
                wait "$cmd_pid" 2>/dev/null
                exit_code=$?
            fi

            cmd_pid=""

            local tw
            for ((tw=0; tw<10; tw++)); do
                kill -0 "$tee_pid" 2>/dev/null || break
                sleep 0.05
            done
            kill -TERM "$tee_pid" 2>/dev/null || true
            wait "$tee_pid" 2>/dev/null || true
            tee_pid=""

            rm -f "$tmp_pipe"
            tmp_pipe=""
            LAST_CMD_OUTPUT=$(<"$tmp_log")
            rm -f "$tmp_log"
            tmp_log=""
        else
            set -o pipefail
            tmp_log=$(mktemp)
            eval "$cmd" 2>&1 | tee "$tmp_log"
            exit_code=$?
            LAST_CMD_OUTPUT=$(<"$tmp_log")
            rm -f "$tmp_log"
            tmp_log=""
            [[ "$prev_pipefail" == false ]] && set +o pipefail
        fi

        [[ $exit_code -eq 0 ]] && return 0

        # Skip auto-retries on interrupt or stall
        if [[ $exit_code -eq 130 || $exit_code -eq 124 ]]; then
            attempts=$max_retries
        fi

        # Auto-Retry Logic
        if [[ $attempts -lt $max_retries ]]; then
            ((attempts++))
            ui_warn "$phase failed. Retrying in 3s ($attempts/$max_retries)..."
            sleep 3
            continue
        fi

        # Escalation
        if [[ $exit_code -eq 130 ]]; then
            request_attention "$phase was interrupted (Ctrl+C)."
            echo -e "${C_YELLOW}${C_BOLD}[WARN]${C_RESET} Command was cancelled: $cmd"
        elif [[ $exit_code -eq 124 ]]; then
            request_attention "$phase stalled (inactivity timeout)."
            echo -e "${C_YELLOW}${C_BOLD}[STALL]${C_RESET} Command stalled and was terminated: $cmd"
        else
            request_attention "$phase failed after $attempts retries."
            echo -e "${C_RED}${C_BOLD}[FAIL]${C_RESET} Command: $cmd"
        fi

        if [[ ! -t 0 ]]; then
            close_attention
            if command -v notify-send >/dev/null 2>&1; then
                notify-send -u critical -a "checkpoint" -i dialog-error "Checkpoint Failed" "Snapshot operation '$phase' failed in unattended mode." 2>/dev/null || true
            fi
            ui_error "Non-interactive environment: $phase failed. Aborting."
            return 1
        fi

        local p="${C_BOLD}Action:${C_RESET} [${C_GREEN}R${C_RESET}]etry | [${C_CYAN}E${C_RESET}]dit | [${C_YELLOW}S${C_RESET}]kip | [${C_RED}A${C_RESET}]bort: "
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
                [Ee])
                    echo -e "${C_BOLD}Edit command below (Enter to run, Ctrl+C to cancel):${C_RESET}"
                    local custom_cmd=""
                    if read -e -r -i "$cmd" -p "> " custom_cmd; then
                        custom_cmd=$(trim "$custom_cmd")
                        if [[ -n "$custom_cmd" ]]; then
                            cmd="$custom_cmd"
                            close_attention
                            attempts=0
                            break
                        else
                            ui_warn "Command cannot be empty. Please enter a valid command or select another option."
                        fi
                    else
                        echo ""
                        ui_info "Edit cancelled."
                    fi ;;
                [Ss]) close_attention; return 1 ;;
                [Aa]) close_attention; exit 1 ;;
                *) ui_warn "Invalid selection. Please enter R, E, S, or A." ;;
            esac
        done
    done
}
