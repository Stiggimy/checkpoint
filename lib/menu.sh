#!/usr/bin/env bash
# ==============================================================================
# Checkpoint Module: Interactive Settings & FZF Configuration Wizard
# ==============================================================================

manage_config() {
    if ! ensure_fzf; then return 1; fi
    local init_emoji=$USE_EMOJI; local init_color=$USE_COLOR; local init_limit=$DEFAULT_KEEP_LIMIT
    local init_keep=$ALWAYS_KEEP; local init_create=$ALWAYS_CREATE; local init_cleanup=$ALWAYS_CLEANUP
    local init_retries=$AUTO_RETRIES; local init_inf=$INFINITE_RETRIES
    local init_device=$SNAPSHOT_DEVICE
    local init_backend=$SNAPSHOT_BACKEND
    local init_self_update_check=$SELF_UPDATE_CHECK
    local last_idx=0
    local prev_changelog
    prev_changelog=$(cat <<EOF
$(e 📜)View Changelog / What's New
──────────────────────────────
Browse version release notes and update history.

Select this item to open the interactive version browser.

$(display_changelog "latest" 2>/dev/null || true)
EOF
)
    export CFG_PREV_CHANGELOG="$prev_changelog"

    while true; do
        local s_em="[OFF]"; [[ "$USE_EMOJI" == true ]] && s_em="[ON ]"
        local s_col="[OFF]"; [[ "$USE_COLOR" == true ]] && s_col="[ON ]"
        local s_lim="[$DEFAULT_KEEP_LIMIT]"
        local s_keep="[OFF]"; [[ "$ALWAYS_KEEP" == true ]] && s_keep="[ON ]"
        local s_create="[OFF]"; [[ "$ALWAYS_CREATE" == true ]] && s_create="[ON ]"
        local s_clean="[OFF]"; [[ "$ALWAYS_CLEANUP" == true ]] && s_clean="[ON ]"
        local s_backend="[$SNAPSHOT_BACKEND]"
        local s_dev="[${SNAPSHOT_DEVICE:-default}]"
        local s_ret="[$AUTO_RETRIES]"
        local s_inf="[OFF]"; [[ "$INFINITE_RETRIES" == true ]] && s_inf="[ON ]"
        local s_upd="[${SELF_UPDATE_CHECK^^}]"

        local opt=(
            "--- RETENTION & PROTECTION ---"
            "$(e 🔟)Default Snapshot Limit      $s_lim"
            "$(e 🔒)Always Mark as [KEEP]       $s_keep"
            "--- SNAPSHOT ENGINE & TARGET ---"
            "$(e 🆕)Always Create Snapshot      $s_create"
            "$(e 🧹)Always Run Cleanup          $s_clean"
            "$(e 🔌)Snapshot Backend            $s_backend"
            "$(e 💾)Target Backup Device        $s_dev"
            "--- ERROR HANDLING ---"
            "$(e 🔟)Auto-Retries Limit          $s_ret"
            "$(e ♾️)Infinite Retries Mode       $s_inf"
            "$(e 🔄)Self-Update Check           $s_upd"
            "--- VISUAL STYLING ---"
            "$(e 🎨)Terminal Icons / Emojis     $s_em"
            "$(e 🌈)ANSI Syntax Colors          $s_col"
            "--- INFORMATION ---"
            "$(e 📜)View Changelog / What's New"
            "$(e 🚧)Features in Development     [Preview]"
            "---"
            "$(e ✅)Save and Return"
            "$(e ❌)Discard and Exit"
        )
        
        local bind_args=()
        [[ $last_idx -gt 0 ]] && bind_args=(--bind "start:pos($((last_idx + 1)))")

        local choice
        choice=$(printf "%s\n" "${opt[@]}" | fzf --height 20 --reverse "${bind_args[@]}" \
            --header "--- Checkpoint Configuration ---" \
            --preview 'case "{}" in 
                *Changelog*|*What*New*)
                    printf "%s\n" "$CFG_PREV_CHANGELOG"
                    ;;
                *Features*in*Development*)
                    echo -e "🚧 Features in Development (Coming Soon)\n─────────────────────────────────────────\nUpcoming features currently planned and in active development:\n\n• 🧙 Interactive Backend Wizard\n  Guided walkthrough to add and configure custom snapshot backends.\n\n• 🌐 Full CLI Localization & i18n\n  Translation catalogs for multi-language CLI strings.\n\n• 🖥️ Modern Companion GUI\n  Visual dashboard for snapshot browsing and one-click restores." ;;
                *Limit*)
                    echo -e "🔟 Default Snapshot Limit\n─────────────────────────\nThe maximum number of normal system snapshots to keep.\n\nWhen a new backup is created and this limit is exceeded, Checkpoint automatically deletes the oldest normal backup to prevent your disk from filling up.\n\nImportant:\nProtected [KEEP] snapshots are NEVER counted toward this limit and are never auto-deleted.\n\nExample:\nLimit = 6. You have 6 backups. A 7th backup is taken; the 1st backup is safely pruned.\n\nDefault: 6" ;;
                *Always*Mark*KEEP*|*\[KEEP\]*)
                    echo -e "🔒 Always Mark as [KEEP]\n────────────────────────\nPermanently locks EVERY new snapshot created with the [KEEP] tag by default.\n\nWhy use this?\nGuarantees no backups are ever automatically deleted.\n\nWarning:\nBecause auto-cleanup will ignore them, your hard drive will eventually fill up unless you delete old backups manually via \"checkpoint -d\".\n\nDefault: false" ;;
                *Always*Create*)
                    echo -e "🆕 Always Create Snapshot\n─────────────────────────\nWhen ON, simply running \"checkpoint\" without flags will immediately create a new system snapshot.\n\nWhen OFF, running \"checkpoint\" without flags displays the interactive dashboard and backup list.\n\nDefault: true" ;;
                *Always*Run*Cleanup*|*Cleanup*)
                    echo -e "🧹 Always Run Cleanup\n─────────────────────\nWhen ON, running \"checkpoint\" without flags automatically prunes old unkept snapshots exceeding your limit.\n\nDefault: true" ;;
                *Snapshot*Backend*|*Backend*)
                    echo -e "🔌 Snapshot Backend Driver\n──────────────────────────\nThe snapshot orchestrator used to create and manage system snapshots:\n\n• auto: Auto-detects the best installed backend (Snapper, Timeshift BTRFS, or Timeshift RSYNC).\n• timeshift-btrfs: Timeshift BTRFS subvolume mode.\n• timeshift-rsync: Timeshift RSYNC hardlink mode.\n• snapper: Snapper BTRFS subvolume mode.\n\nDefault: auto" ;;
                *Backup*Device*|*Device*)
                    echo -e "💾 Target Backup Device\n───────────────────────\nOverride the partition or external drive used to store snapshots (e.g. /dev/sdb1 or UUID).\n\nLeave blank/default to use your primary system partition or Timeshift default drive." ;;
                *Auto-Retries*)
                    echo -e "🔟 Auto-Retries Limit\n─────────────────────\nNumber of times failed snapshot operations will be silently retried before prompting the user.\n\nDefault: 1" ;;
                *Infinite*)
                    echo -e "♾️ Infinite Retries Mode\n────────────────────────\nIf enabled, snapshot commands loop endlessly until success (useful for unattended backup jobs on flaky hardware).\n\nDefault: false" ;;
                *Self-Update*)
                    echo -e "🔄 Self-Update Check\n────────────────────\nControls how Checkpoint checks for new versions and commits from GitHub.\n\nModes:\n• prompt: Interactive banner asking [Y/n/a/d] when updates are found (Default)\n• notify: Non-intrusive notification banner only (never pauses CLI)\n• auto: Silently and automatically update Checkpoint before running tasks\n• off: Disable automatic update checks entirely\n\nDefault: prompt" ;;
                *Icons*|*Emojis*)
                    echo -e "🎨 Terminal Icons / Emojis\n──────────────────────────\nDisplay graphical icons (🎨, 🔒, ✅, ⚠️). Disable if your terminal font shows empty boxes or question marks.\n\nDefault: true" ;;
                *Colors*)
                    echo -e "🌈 ANSI Syntax Colors\n─────────────────────\nColor-codes commands, statuses, and headers for clarity.\n\nDefault: true" ;;
                *Save*)
                    echo -e "💾 Save and Return\n──────────────────\nApply all changes to ~/.config/checkpoint/config permanently." ;;
                *Discard*)
                    echo -e "❌ Discard and Exit\n───────────────────\nClose the menu and discard all changes made during this session." ;;
                ---*)
                    echo -e "Section Header\nSelect a setting below to see detailed explanations and examples." ;;
                *) echo -e "Select an option to see details and examples." ;;
            esac' --preview-window=right:55%:wrap)
        
        [[ -z "$choice" ]] && choice="Discard and Exit"

        local idx=0
        for item in "${opt[@]}"; do
            if [[ "$item" == "$choice" ]]; then last_idx=$idx; break; fi
            ((idx++))
        done

        case "$choice" in
            *"Default Snapshot Limit"*)
                local input_limit
                read -p "Enter new limit (number, current: $DEFAULT_KEEP_LIMIT): " input_limit
                input_limit=$(trim "$input_limit")
                [[ "$input_limit" =~ ^[0-9]+$ ]] && DEFAULT_KEEP_LIMIT="$input_limit" ;;
            *"Always Mark as [KEEP]"*) [[ "$ALWAYS_KEEP" == true ]] && ALWAYS_KEEP=false || ALWAYS_KEEP=true ;;
            *"Always Create Snapshot"*) [[ "$ALWAYS_CREATE" == true ]] && ALWAYS_CREATE=false || ALWAYS_CREATE=true ;;
            *"Always Run Cleanup"*) [[ "$ALWAYS_CLEANUP" == true ]] && ALWAYS_CLEANUP=false || ALWAYS_CLEANUP=true ;;
            *"Snapshot Backend"*)
                local b_list=("auto")
                local c_dir
                c_dir=$(get_backends_catalog_dir)
                for f in "$c_dir"/*.conf "$BACKENDS_USER_DIR"/*.conf; do
                    [[ -f "$f" ]] || continue
                    local b_id
                    b_id=$(basename "$f" .conf)
                    if [[ " ${b_list[*]} " != *" $b_id "* ]]; then
                        b_list+=("$b_id")
                    fi
                done
                local cur_idx=0
                for i in "${!b_list[@]}"; do
                    if [[ "${b_list[$i]}" == "$SNAPSHOT_BACKEND" ]]; then
                        cur_idx=$i
                        break
                    fi
                done
                local next_idx=$(((cur_idx + 1) % ${#b_list[@]}))
                SNAPSHOT_BACKEND="${b_list[$next_idx]}"
                ;;
            *"Target Backup Device"*) 
                local input_dev
                echo -n "Enter target backup device (e.g. /dev/sdb1 or UUID, or leave blank to clear, current: ${SNAPSHOT_DEVICE:-default}): "
                read -r input_dev
                SNAPSHOT_DEVICE=$(trim "$input_dev")
                ;;
            *"Auto-Retries Limit"*)
                local input_retries
                read -p "Enter retry limit (0 for always ask, current: $AUTO_RETRIES): " input_retries
                input_retries=$(trim "$input_retries")
                [[ "$input_retries" =~ ^[0-9]+$ ]] && AUTO_RETRIES="$input_retries" ;;
            *"Infinite Retries Mode"*) [[ "$INFINITE_RETRIES" == true ]] && INFINITE_RETRIES=false || INFINITE_RETRIES=true ;;
            *"Self-Update Check"*)
                local modes=(
                    "$(e 💬)prompt  — Interactive banner: ask [Y/n/a/d] when update is available (Default)"
                    "$(e 🔔)notify  — Notification banner only (never pauses execution)"
                    "$(e ⚡)auto    — Automatically update before running tasks"
                    "$(e 🚫)off     — Disable automatic self-update checks"
                )
                local m_choice
                m_choice=$(printf "%s\n" "${modes[@]}" | fzf --height 10 --reverse \
                    --header "Select Self-Update Check Mode (Current: $SELF_UPDATE_CHECK)")
                case "$m_choice" in
                    *prompt*) SELF_UPDATE_CHECK="prompt" ;;
                    *notify*) SELF_UPDATE_CHECK="notify" ;;
                    *auto*)   SELF_UPDATE_CHECK="auto" ;;
                    *off*)    SELF_UPDATE_CHECK="off" ;;
                esac
                ;;
            *"Terminal Icons / Emojis"*) [[ "$USE_EMOJI" == true ]] && USE_EMOJI=false || USE_EMOJI=true ;;
            *"ANSI Syntax Colors"*) [[ "$USE_COLOR" == true ]] && USE_COLOR=false || USE_COLOR=true; setup_colors ;;
            *"View Changelog"*|*"What's New"*)
                browse_changelog_interactive
                local r=$?
                if [[ $r -eq 2 ]]; then
                    echo ""
                    read -rp "Press Enter to return to settings menu..." _dummy
                fi
                ;;
            *"Features in Development"*)
                echo -e "\n${C_BOLD}${C_YELLOW}$(e 🚧)Features in Development (Coming Soon)${C_RESET}"
                echo "─────────────────────────────────────────"
                echo "• $(e 🧙)Interactive Backend Wizard"
                echo "  Guided walkthrough to add and configure custom snapshot backends."
                echo ""
                echo "• $(e 🌐)Full CLI Localization & i18n"
                echo "  Translation catalogs for multi-language CLI strings."
                echo ""
                echo "• $(e 🖥️)Modern Companion GUI"
                echo "  Visual dashboard for snapshot browsing and one-click restores."
                echo ""
                read -rp "Press Enter to return to settings menu..." _dummy
                ;;
            *"Save and Return"*) save_config; ui_ok "Configuration updated."; break ;;
            *"Discard and Exit"*)
                USE_EMOJI=$init_emoji; USE_COLOR=$init_color; DEFAULT_KEEP_LIMIT=$init_limit
                ALWAYS_KEEP=$init_keep; ALWAYS_CREATE=$init_create; ALWAYS_CLEANUP=$init_cleanup
                AUTO_RETRIES=$init_retries; INFINITE_RETRIES=$init_inf
                SNAPSHOT_DEVICE=$init_device
                SNAPSHOT_BACKEND=$init_backend
                SELF_UPDATE_CHECK=$init_self_update_check
                ui_info "Changes discarded."; break ;;
            *) continue ;;
        esac
    done
}
