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

    local prev_dev
    prev_dev=$(cat <<EOF
$(e 🚧)Features in Development (Upcoming)
──────────────────────────────────────
Upcoming user-facing features planned for future releases.

$(display_changelog "Unreleased" 2>/dev/null || true)
EOF
)
    export CFG_PREV_DEV="$prev_dev"

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
                    printf "%s\n" "$CFG_PREV_DEV" ;;
                *Limit*)
                    echo -e "🔟 Default Snapshot Limit\n─────────────────────────\nThe maximum number of normal system snapshots to keep.\n\nWhen a new backup is created and this limit is exceeded, Checkpoint automatically deletes the oldest normal backup to prevent your disk from filling up.\n\nImportant:\nProtected [KEEP] snapshots are NEVER counted toward this limit and are never auto-deleted.\n\nExample:\nLimit = 6. You have 6 backups. A 7th backup is taken; the 1st backup is safely pruned.\n\nDefault: 6" ;;
                *Always*Mark*KEEP*|*\[KEEP\]*)
                    echo -e "🔒 Always Mark as [KEEP]\n────────────────────────\nPermanently locks EVERY new snapshot created with the [KEEP] tag by default.\n\nWhy use this?\nGuarantees no backups are ever automatically deleted.\n\nWarning:\nBecause auto-cleanup will ignore them, your hard drive will eventually fill up unless you delete old backups manually via \"checkpoint -d\".\n\nDefault: false" ;;
                *Always*Create*)
                    echo -e "🆕 Always Create Snapshot\n─────────────────────────\nWhen ON, simply running \"checkpoint\" without flags will immediately create a new system snapshot.\n\nWhen OFF, running \"checkpoint\" without flags displays the interactive dashboard and backup list.\n\nDefault: true" ;;
                *Always*Run*Cleanup*|*Cleanup*)
                    echo -e "🧹 Always Run Cleanup\n─────────────────────\nWhen ON, running \"checkpoint\" without flags automatically prunes old unkept snapshots exceeding your limit.\n\nDefault: true" ;;
                *Snapshot*Backend*|*Backend*)
                    echo -e "🔌 Snapshot Backend Management\n──────────────────────────────\nManage snapshot drivers, select the active backend orchestrator, or create custom snapshot backends via the guided wizard.\n\n• auto: Auto-detects the best installed backend (Snapper, Timeshift BTRFS, or Timeshift RSYNC).\n• timeshift-btrfs: Timeshift BTRFS subvolume mode.\n• timeshift-rsync: Timeshift RSYNC hardlink mode.\n• snapper: Snapper BTRFS subvolume mode.\n• custom: User-defined snapshot drivers in backends.d/\n\nPress Enter to open the Backend Manager." ;;
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
                manage_backends_menu
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
                echo ""
                display_changelog "Unreleased"
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

# ==============================================================================
# Checkpoint Backend Management & Custom Backend Wizard
# ==============================================================================

_get_backend_conf_val() {
    local file="$1"
    local key="$2"
    [[ ! -f "$file" ]] && return 1
    local val=""
    while IFS='=' read -r k v || [[ -n "$k" ]]; do
        [[ -z "$k" || "$k" == \#* ]] && continue
        k="${k#"${k%%[![:space:]]*}"}"; k="${k%"${k##*[![:space:]]}"}"
        if [[ "$k" == "$key" ]]; then
            v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
            if [[ "$v" == \"*\" && "$v" =~ ^\".*\"$ ]]; then
                v="${v#\"}"; v="${v%\"}"
            elif [[ "$v" == \'*\' && "$v" =~ ^\'.*\'$ ]]; then
                v="${v#\'}"; v="${v%\'}"
            fi
            val="$v"
            break
        fi
    done < "$file"
    echo "$val"
}

_render_backend_preview() {
    local conf="$1"
    if [[ ! -f "$conf" ]]; then
        echo "No configuration file found."
        return 1
    fi
    local b_id b_name b_emoji b_fmt b_boot b_pair b_req b_probe b_pri b_create b_list b_del b_parser
    b_id=$(_get_backend_conf_val "$conf" "BACKEND_ID")
    b_name=$(_get_backend_conf_val "$conf" "NAME")
    b_emoji=$(_get_backend_conf_val "$conf" "EMOJI")
    b_fmt=$(_get_backend_conf_val "$conf" "STORAGE_FORMAT")
    b_boot=$(_get_backend_conf_val "$conf" "CAP_BOOTABLE_SUBVOL")
    b_pair=$(_get_backend_conf_val "$conf" "CAP_PAIRED_PRE_POST")
    b_req=$(_get_backend_conf_val "$conf" "REQUIRES_CMD")
    b_probe=$(_get_backend_conf_val "$conf" "PROBE_ACTIVE_CMD")
    b_pri=$(_get_backend_conf_val "$conf" "PRIORITY")
    b_create=$(_get_backend_conf_val "$conf" "CREATE_CMD")
    b_list=$(_get_backend_conf_val "$conf" "LIST_CMD")
    b_del=$(_get_backend_conf_val "$conf" "DELETE_CMD")
    b_parser=$(_get_backend_conf_val "$conf" "LIST_PARSER")

    local req_status="N/A"
    if [[ -n "$b_req" ]]; then
        if command -v "$b_req" >/dev/null 2>&1; then
            req_status="Installed ($(command -v "$b_req"))"
        else
            req_status="Missing from PATH ($b_req)"
        fi
    fi

    local probe_status="N/A"
    if [[ -n "$b_probe" ]]; then
        if eval "$b_probe" >/dev/null 2>&1; then
            probe_status="Active / Verified"
        else
            probe_status="Inactive / Check Failed"
        fi
    fi

    echo -e "${b_emoji:-📸} ${b_name} (${b_id})"
    echo -e "──────────────────────────────────────────────"
    echo -e "Storage Format:      ${b_fmt:-custom}"
    echo -e "Required Binary:     ${b_req:-none} [${req_status}]"
    echo -e "Probe Status:        ${probe_status}"
    echo -e "Priority:            ${b_pri:-0}"
    echo -e "Bootable Subvolume:  ${b_boot:-false}"
    echo -e "Paired Pre/Post:     ${b_pair:-false}"
    echo -e "Config Location:     ${conf}"
    echo -e "──────────────────────────────────────────────"
    echo -e "Create Command:\n  ${b_create:-(none)}"
    echo -e "List Command:\n  ${b_list:-(none)}"
    echo -e "Delete Command:\n  ${b_del:-(none)}"
    [[ -n "$b_parser" ]] && echo -e "List Parser:\n  ${b_parser}"
}

_backend_wizard_advanced_menu() {
    while true; do
        local adv_opts=(
            "$(e 🚀)Bootable Subvolume Subsystem  [$b_bootable]"
            "$(e 🔄)Paired Pre/Post Tracking     [$b_paired]"
            "$(e 🔍)Active Probe Command         [${b_probe:-(none)}]"
            "$(e 🔢)Auto-Detection Priority      [$b_priority]"
            "$(e ⚡)Pre-Create Hook Command      [${b_pre_create:-(none)}]"
            "$(e 🆔)Extract ID Regex Pattern     [${b_extract_regex:-(none)}]"
            "$(e 📁)Subvolume Path Template      [${b_subvol_template:-(none)}]"
            "---"
            "$(e ↩️)Return to Review Screen"
        )
        local adv_choice
        adv_choice=$(printf "%s\n" "${adv_opts[@]}" | fzf --height 14 --reverse \
            --header "Advanced Backend Capabilities & Driver Hooks" \
            --preview 'case "{}" in
                *Bootable*)
                    echo -e "🚀 Bootable Subvolume\n──────────────────────\nFlag indicating whether this snapshot backend creates bootable filesystem snapshots capable of bootloader integration." ;;
                *Paired*)
                    echo -e "🔄 Paired Pre/Post Tracking\n───────────────────────────\nEnables Checkpoint/Advance paired rollback transaction hooks (taking matched pre-update and post-update snapshots)." ;;
                *Probe*)
                    echo -e "🔍 Active Probe Command\n───────────────────────\nCommand evaluated during auto-probe to test if the backend is configured on the host machine." ;;
                *Priority*)
                    echo -e "🔢 Auto-Detection Priority\n───────────────────────────\nInteger priority used by auto-mode when multiple backends are available. Higher numbers take precedence." ;;
                *Pre-Create*)
                    echo -e "⚡ Pre-Create Hook Command\n──────────────────────────\nCommand evaluated immediately before snapshot creation (e.g. unmounting stale mount points)." ;;
                *Extract*ID*)
                    echo -e "🆔 Extract ID Regex Pattern\n───────────────────────────\nRegular expression used to extract created snapshot ID from create command stdout/stderr." ;;
                *Subvolume*Path*)
                    echo -e "📁 Subvolume Path Template\n──────────────────────────\nFilesystem path template to snapshot subvolume (e.g. \"\${ROOT_SUBVOL}/.snapshots/\${SNAPSHOT_ID}/snapshot\")." ;;
                *) echo "Select an advanced setting to configure." ;;
            esac' --preview-window=right:55%:wrap)

        [[ -z "$adv_choice" || "$adv_choice" == *"Return"* ]] && break

        case "$adv_choice" in
            *"Bootable Subvolume"*)
                [[ "$b_bootable" == "true" ]] && b_bootable="false" || b_bootable="true" ;;
            *"Paired Pre/Post"*)
                [[ "$b_paired" == "true" ]] && b_paired="false" || b_paired="true" ;;
            *"Active Probe Command"*)
                echo -n "Enter Probe Command [current: ${b_probe:-none}, 'none' to clear]: "
                local n_pr; read -r n_pr; n_pr=$(trim "$n_pr")
                if [[ "$n_pr" == "none" || "$n_pr" == "-" ]]; then b_probe=""
                elif [[ -n "$n_pr" ]]; then b_probe="$n_pr"; fi ;;
            *"Auto-Detection Priority"*)
                echo -n "Enter Priority [current: $b_priority]: "
                local n_pri; read -r n_pri; n_pri=$(trim "$n_pri")
                [[ "$n_pri" =~ ^[0-9]+$ ]] && b_priority="$n_pri" ;;
            *"Pre-Create Hook"*)
                echo -n "Enter Pre-Create Command [current: ${b_pre_create:-none}, 'none' to clear]: "
                local n_pc; read -r n_pc; n_pc=$(trim "$n_pc")
                if [[ "$n_pc" == "none" || "$n_pc" == "-" ]]; then b_pre_create=""
                elif [[ -n "$n_pc" ]]; then b_pre_create="$n_pc"; fi ;;
            *"Extract ID Regex"*)
                echo -n "Enter Extract ID Regex [current: ${b_extract_regex:-none}, 'none' to clear]: "
                local n_rx; read -r n_rx; n_rx=$(trim "$n_rx")
                if [[ "$n_rx" == "none" || "$n_rx" == "-" ]]; then b_extract_regex=""
                elif [[ -n "$n_rx" ]]; then b_extract_regex="$n_rx"; fi ;;
            *"Subvolume Path Template"*)
                echo -n "Enter Subvolume Path Template [current: ${b_subvol_template:-none}, 'none' to clear]: "
                local n_tm; read -r n_tm; n_tm=$(trim "$n_tm")
                if [[ "$n_tm" == "none" || "$n_tm" == "-" ]]; then b_subvol_template=""
                elif [[ -n "$n_tm" ]]; then b_subvol_template="$n_tm"; fi ;;
        esac
    done
}

backend_wizard() {
    local edit_conf="$1"
    local is_edit=false
    [[ -n "$edit_conf" && -f "$edit_conf" ]] && is_edit=true

    local b_id="" b_name="" b_emoji="📸" b_storage="btrfs"
    local b_bootable="false" b_paired="false" b_requires=""
    local b_probe="" b_priority="15" b_create="" b_list=""
    local b_delete="" b_parser="" b_pre_create="" b_extract_regex=""
    local b_subvol_template=""

    if [[ "$is_edit" == true ]]; then
        b_id=$(_get_backend_conf_val "$edit_conf" "BACKEND_ID")
        b_name=$(_get_backend_conf_val "$edit_conf" "NAME")
        b_emoji=$(_get_backend_conf_val "$edit_conf" "EMOJI")
        b_storage=$(_get_backend_conf_val "$edit_conf" "STORAGE_FORMAT")
        b_bootable=$(_get_backend_conf_val "$edit_conf" "CAP_BOOTABLE_SUBVOL")
        b_paired=$(_get_backend_conf_val "$edit_conf" "CAP_PAIRED_PRE_POST")
        b_requires=$(_get_backend_conf_val "$edit_conf" "REQUIRES_CMD")
        b_probe=$(_get_backend_conf_val "$edit_conf" "PROBE_ACTIVE_CMD")
        b_priority=$(_get_backend_conf_val "$edit_conf" "PRIORITY")
        b_create=$(_get_backend_conf_val "$edit_conf" "CREATE_CMD")
        b_list=$(_get_backend_conf_val "$edit_conf" "LIST_CMD")
        b_delete=$(_get_backend_conf_val "$edit_conf" "DELETE_CMD")
        b_parser=$(_get_backend_conf_val "$edit_conf" "LIST_PARSER")
        b_pre_create=$(_get_backend_conf_val "$edit_conf" "PRE_CREATE_CMD")
        b_extract_regex=$(_get_backend_conf_val "$edit_conf" "EXTRACT_ID_REGEX")
        b_subvol_template=$(_get_backend_conf_val "$edit_conf" "SUBVOL_PATH_TEMPLATE")
    else
        ui_info "Add New Snapshot Backend Wizard"
        echo -e "${C_DIM}Follow the guided steps below to configure your custom snapshot backend.${C_RESET}"
        echo -e "${C_DIM}Press Enter on empty prompts to cancel at any time.${C_RESET}\n"

        # Step 1: Backend ID
        while true; do
            echo -e "${C_BOLD}Step 1: Backend Identifier (ID)${C_RESET}"
            echo "Enter a unique identifier (lowercase slug, e.g. 'zfs-root', 'btrfs-snapshots', 'my-rsync')."
            echo -n "Backend ID: "
            read -r b_id
            b_id=$(trim "$b_id")
            if [[ -z "$b_id" ]]; then
                ui_info "Wizard cancelled."
                return 1
            fi
            if [[ ! "$b_id" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                ui_error "Backend ID may only contain alphanumeric characters, hyphens, and underscores."
                continue
            fi
            b_id="${b_id,,}"
            local c_dir
            c_dir=$(get_backends_catalog_dir)
            if [[ -f "$BACKENDS_USER_DIR/${b_id}.conf" || (-n "$c_dir" && -f "$c_dir/${b_id}.conf") ]]; then
                ui_error "Backend ID '${b_id}' already exists. Please choose a different identifier."
                continue
            fi
            break
        done

        # Step 1b: Display Name
        echo -e "\n${C_BOLD}Step 1b: Display Name${C_RESET}"
        echo "Enter a human-readable display name for this backend (e.g. 'ZFS Root Pool', 'Custom BTRFS')."
        echo -n "Display Name [Enter for '${b_id}']: "
        read -r b_name
        b_name=$(trim "$b_name")
        [[ -z "$b_name" ]] && b_name="${b_id}"

        # Step 2: Create Snapshot Command (Mandatory)
        echo -e "\n${C_BOLD}Step 2: Create Snapshot Command (Mandatory)${C_RESET}"
        echo "Enter the command Checkpoint executes to create a snapshot."
        echo "Supported placeholders: \$COMMENT (snapshot note/tag), \$SNAP_TYPE, \$PRE_ID"
        echo "Example: sudo zfs snapshot pool/root@\$COMMENT"
        echo -n "Create Command: "
        read -r b_create
        b_create=$(trim "$b_create")
        if [[ -z "$b_create" ]]; then
            ui_info "Create command is required. Wizard cancelled."
            return 1
        fi

        local auto_bin
        auto_bin=$(_infer_required_binary "$b_create")
        b_requires="$auto_bin"

        local wiz_modes=(
            "$(e 🧙)Guided Walkthrough           — Configure binary check, storage format, listing/deletion step-by-step"
            "$(e ⚡)Quick Setup (Skip to Review)   — Use smart defaults & jump straight to Review & Save"
        )
        local w_choice
        w_choice=$(printf "%s\n" "${wiz_modes[@]}" | fzf --height 8 --reverse \
            --header "Select Setup Mode for '$b_name'" \
            --preview 'case "{}" in
                *Guided*)
                    echo -e "Guided Walkthrough\n──────────────────\nStep-by-step interactive setup:\n• Step 3: Required binary check\n• Step 4: Storage format & capabilities\n• Step 5: Snapshot listing and deletion commands\n• Step 6: Active probe test and priority" ;;
                *Quick*)
                    echo -e "Quick Setup with Smart Defaults\n────────────────────────────────\nSkips directly to Review & Save using:\n• Inferred Binary: ${auto_bin:-(none)}\n• Storage Format: custom\n• Bootable Subvolume: false\n• Priority: 15\n\nYou can customize or fill in remaining commands in Review & Save before saving." ;;
            esac' --preview-window=right:55%:wrap)

        [[ -z "$w_choice" ]] && { ui_info "Wizard cancelled."; return 1; }

        if [[ "$w_choice" == *"Guided"* ]]; then
            # Step 3: Binary Check
            echo -e "\n${C_BOLD}Step 3: Smart Binary Check (REQUIRES_CMD)${C_RESET}"
            echo "Checkpoint checks for this binary in PATH to verify the snapshot tool is installed."
            if [[ -n "$auto_bin" ]]; then
                local path_status="not found in PATH"
                command -v "$auto_bin" >/dev/null 2>&1 && path_status="found in PATH"
                echo -e "Inferred binary: ${C_GREEN}${auto_bin}${C_RESET} (${path_status})"
                echo -n "Enter required binary [Enter for '${auto_bin}', 'none' to clear, 'skip' to skip to Review]: "
                local input_req
                read -r input_req
                input_req=$(trim "$input_req")
                if [[ "$input_req" == "skip" || "$input_req" == "s" ]]; then
                    : # keep defaults
                elif [[ "$input_req" == "none" || "$input_req" == "-" ]]; then
                    b_requires=""
                elif [[ -n "$input_req" ]]; then
                    b_requires="$input_req"
                fi
            else
                echo -n "Enter required binary (leave blank for none, 'skip' to skip to Review): "
                local input_req
                read -r input_req
                input_req=$(trim "$input_req")
                [[ "$input_req" != "skip" && "$input_req" != "s" ]] && b_requires="$input_req"
            fi

            # Step 4: Storage Format & Capabilities
            echo -e "\n${C_BOLD}Step 4: Storage Format${C_RESET}"
            local fmt_choices=(
                "btrfs    — BTRFS subvolume copy-on-write snapshotting"
                "zfs      — ZFS dataset snapshotting"
                "rsync    — File-based hardlink rsync snapshotting"
                "lvm      — LVM thin-pool volume snapshotting"
                "custom   — Generic or custom snapshot mechanism"
            )
            local sel_fmt
            sel_fmt=$(printf "%s\n" "${fmt_choices[@]}" | fzf --height 8 --reverse \
                --header "Select Storage Format for '$b_name'")
            case "$sel_fmt" in
                *zfs*)    b_storage="zfs" ;;
                *rsync*)  b_storage="rsync" ;;
                *lvm*)    b_storage="lvm" ;;
                *custom*) b_storage="custom" ;;
                *)        b_storage="btrfs" ;;
            esac

            echo -n "Is this snapshot format directly bootable as a root subvolume (e.g. GRUB/systemd-boot)? [y/N]: "
            local input_boot
            read -r input_boot
            [[ "${input_boot,,}" == "y" || "${input_boot,,}" == "yes" ]] && b_bootable="true"

            echo -n "Does this backend support paired pre/post snapshot tracking? [y/N]: "
            local input_pair
            read -r input_pair
            [[ "${input_pair,,}" == "y" || "${input_pair,,}" == "yes" ]] && b_paired="true"

            # Step 5: Listing & Deletion
            echo -e "\n${C_BOLD}Step 5: Snapshot Listing & Deletion Commands${C_RESET}"
            echo "Enter command to list existing snapshots (e.g. 'sudo zfs list -t snapshot', 'sudo btrfs subvolume list /'):"
            echo -n "List Command [Enter to skip]: "
            read -r b_list
            b_list=$(trim "$b_list")

            if [[ -n "$b_list" ]]; then
                echo "Enter awk/sed parser pipeline producing 'ID | DESCRIPTION' lines [Enter for raw list]: "
                read -r b_parser
                b_parser=$(trim "$b_parser")
            fi

            echo "Enter command to delete a snapshot (use '\$SNAPSHOT' for target ID, e.g. 'sudo zfs destroy \"\$SNAPSHOT\"'):"
            echo -n "Delete Command [Enter to skip]: "
            read -r b_delete
            b_delete=$(trim "$b_delete")

            # Step 6: Active Probe & Priority
            echo -e "\n${C_BOLD}Step 6: Active Probe Command & Priority${C_RESET}"
            echo "Enter an optional shell command that exits 0 only when this backend is ready on this machine."
            echo "Example: command -v zfs >/dev/null 2>&1 && zpool status >/dev/null 2>&1"
            echo -n "Probe Active Command [Enter to skip]: "
            read -r b_probe
            b_probe=$(trim "$b_probe")

            echo -n "Auto-detection Priority (higher numbers take precedence, default: 15): "
            local input_pri
            read -r input_pri
            input_pri=$(trim "$input_pri")
            [[ "$input_pri" =~ ^[0-9]+$ ]] && b_priority="$input_pri"
        fi
    fi

    # Review & Save Screen
    local last_r_idx=0
    while true; do
        local r_opts=(
            "--- BASIC IDENTIFICATION ---"
            "$(e 🆔)[1] Backend ID:            $b_id"
            "$(e 🏷️)[2] Display Name:          $b_name"
            "$(e 📸)[3] Terminal Emoji:        $b_emoji"
            "--- DRIVER SPECIFICATION ---"
            "$(e 💾)[4] Storage Format:        $b_storage"
            "$(e ⚙️)[5] Required Binary:       ${b_requires:-(none)}"
            "$(e ➕)[6] Create Command:        ${b_create:-(none)}"
            "$(e 📋)[7] List Command:          ${b_list:-(none)}"
            "$(e 🗑️)[8] Delete Command:        ${b_delete:-(none)}"
            "$(e 🔍)[9] List Parser Pipeline:  ${b_parser:-(none)}"
            "--- ADVANCED PROPERTIES ---"
            "$(e 🛠️)[A] Advanced Capabilities & Templates..."
            "---"
            "$(e 💾)Save Custom Backend"
            "$(e 🚀)Save and Set as Active Backend"
            "$(e ❌)Cancel / Discard"
        )

        local r_bind=()
        [[ $last_r_idx -gt 0 ]] && r_bind=(--bind "start:pos($((last_r_idx + 1)))")

        local r_choice
        r_choice=$(printf "%s\n" "${r_opts[@]}" | fzf --height 20 --reverse "${r_bind[@]}" \
            --header "Review & Configure Snapshot Backend: $b_name ($b_id)" \
            --preview 'case "{}" in
                *Backend*ID*)
                    echo -e "🆔 Backend Identifier\n──────────────────────\nUnique configuration slug (used for config filename ~/.config/checkpoint/backends.d/<id>.conf).\n\nCurrent: '"$b_id"'" ;;
                *Display*Name*)
                    echo -e "🏷️ Display Name\n───────────────\nHuman-readable label shown in menus and dashboards.\n\nCurrent: '"$b_name"'" ;;
                *Terminal*Emoji*)
                    echo -e "📸 Terminal Emoji\n─────────────────\nVisual icon prefix used for this backend in interactive CLI outputs.\n\nCurrent: '"$b_emoji"'" ;;
                *Storage*Format*)
                    echo -e "💾 Storage Format\n─────────────────\nFilesystem snapshot engine type (btrfs, zfs, rsync, lvm, custom).\n\nCurrent: '"$b_storage"'" ;;
                *Required*Binary*)
                    echo -e "⚙️ Required Binary (REQUIRES_CMD)\n────────────────────────────────\nExecutable that must exist in PATH before this backend can run.\n\nCurrent: '"${b_requires:-(none)}"'" ;;
                *Create*Command*)
                    echo -e "➕ Create Snapshot Command\n──────────────────────────\nCommand executed to take a new snapshot.\nPlaceholders: \$COMMENT, \$SNAP_TYPE, \$PRE_ID\n\nCurrent:\n'"$b_create"'" ;;
                *List*Command*)
                    echo -e "📋 List Snapshots Command\n─────────────────────────\nCommand executed to output snapshot history.\n\nCurrent:\n'"${b_list:-(none)}"'" ;;
                *Delete*Command*)
                    echo -e "🗑️ Delete Snapshot Command\n─────────────────────────\nCommand executed to delete an old snapshot.\nPlaceholder: \$SNAPSHOT\n\nCurrent:\n'"${b_delete:-(none)}"'" ;;
                *List*Parser*)
                    echo -e "🔍 List Parser Pipeline\n───────────────────────\nAwk or shell pipeline that converts list command output to \"ID | DESCRIPTION\" lines.\n\nCurrent:\n'"${b_parser:-(none)}"'" ;;
                *Advanced*Capabilities*)
                    echo -e "🛠️ Advanced Capabilities & Hooks\n────────────────────────────────\nConfigure subvolume templates, regex ID extractors, pre-create commands, bootable subvolume flags, and probe commands." ;;
                *Save*and*Set*Active*)
                    echo -e "🚀 Save and Activate\n────────────────────\nWrites the backend configuration to backends.d/<id>.conf and immediately sets SNAPSHOT_BACKEND=\"'"$b_id"'\"." ;;
                *Save*Custom*Backend*)
                    echo -e "💾 Save Backend\n──────────────\nWrites the backend configuration to backends.d/<id>.conf without switching active driver." ;;
                *Cancel*)
                    echo -e "❌ Cancel\n─────────\nDiscards all changes and returns to the backend manager." ;;
                *) echo -e "Select a field to modify it." ;;
            esac' --preview-window=right:55%:wrap)

        [[ -z "$r_choice" ]] && r_choice="Cancel / Discard"

        local idx=0
        for item in "${r_opts[@]}"; do
            if [[ "$item" == "$r_choice" ]]; then last_r_idx=$idx; break; fi
            ((idx++))
        done

        case "$r_choice" in
            *"[1] Backend ID"*)
                echo -n "Enter Backend ID [current: $b_id]: "
                local n_id; read -r n_id; n_id=$(trim "$n_id")
                if [[ -n "$n_id" && "$n_id" =~ ^[a-zA-Z0-9_-]+$ ]]; then b_id="${n_id,,}"; fi ;;
            *"[2] Display Name"*)
                echo -n "Enter Display Name [current: $b_name]: "
                local n_name; read -r n_name; n_name=$(trim "$n_name")
                [[ -n "$n_name" ]] && b_name="$n_name" ;;
            *"[3] Terminal Emoji"*)
                echo -n "Enter Terminal Emoji [current: $b_emoji]: "
                local n_em; read -r n_em; n_em=$(trim "$n_em")
                [[ -n "$n_em" ]] && b_emoji="$n_em" ;;
            *"[4] Storage Format"*)
                local sf_opt=("btrfs" "zfs" "rsync" "lvm" "custom")
                local sf_c
                sf_c=$(printf "%s\n" "${sf_opt[@]}" | fzf --height 8 --reverse --header "Select Storage Format (Current: $b_storage)")
                [[ -n "$sf_c" ]] && b_storage="$sf_c" ;;
            *"[5] Required Binary"*)
                echo -n "Enter Required Binary in PATH [current: ${b_requires:-none}, 'none' to clear]: "
                local n_req; read -r n_req; n_req=$(trim "$n_req")
                if [[ "$n_req" == "none" || "$n_req" == "-" ]]; then b_requires=""
                elif [[ -n "$n_req" ]]; then b_requires="$n_req"; fi ;;
            *"[6] Create Command"*)
                echo -n "Enter Create Command [current: $b_create]: "
                local n_cr; read -r n_cr; n_cr=$(trim "$n_cr")
                [[ -n "$n_cr" ]] && b_create="$n_cr" ;;
            *"[7] List Command"*)
                echo -n "Enter List Command [current: ${b_list:-none}, 'none' to clear]: "
                local n_ls; read -r n_ls; n_ls=$(trim "$n_ls")
                if [[ "$n_ls" == "none" || "$n_ls" == "-" ]]; then b_list=""
                elif [[ -n "$n_ls" ]]; then b_list="$n_ls"; fi ;;
            *"[8] Delete Command"*)
                echo -n "Enter Delete Command [current: ${b_delete:-none}, 'none' to clear]: "
                local n_dl; read -r n_dl; n_dl=$(trim "$n_dl")
                if [[ "$n_dl" == "none" || "$n_dl" == "-" ]]; then b_delete=""
                elif [[ -n "$n_dl" ]]; then b_delete="$n_dl"; fi ;;
            *"[9] List Parser Pipeline"*)
                echo -n "Enter List Parser Pipeline [current: ${b_parser:-none}, 'none' to clear]: "
                local n_ps; read -r n_ps; n_ps=$(trim "$n_ps")
                if [[ "$n_ps" == "none" || "$n_ps" == "-" ]]; then b_parser=""
                elif [[ -n "$n_ps" ]]; then b_parser="$n_ps"; fi ;;
            *"[A] Advanced Capabilities"*)
                _backend_wizard_advanced_menu
                ;;
            *"Save Custom Backend"*)
                save_custom_backend "$b_id" "$b_name" "$b_emoji" "$b_storage" "$b_bootable" "$b_paired" "$b_requires" "$b_probe" "$b_priority" "$b_create" "$b_list" "$b_delete" "$b_parser" "$b_pre_create" "$b_extract_regex" "$b_subvol_template"
                ui_ok "Custom backend '$b_name' ($b_id) saved."
                break ;;
            *"Save and Set as Active Backend"*)
                save_custom_backend "$b_id" "$b_name" "$b_emoji" "$b_storage" "$b_bootable" "$b_paired" "$b_requires" "$b_probe" "$b_priority" "$b_create" "$b_list" "$b_delete" "$b_parser" "$b_pre_create" "$b_extract_regex" "$b_subvol_template"
                SNAPSHOT_BACKEND="$b_id"
                save_config
                ui_ok "Custom backend '$b_name' ($b_id) saved and set as active backend."
                break ;;
            *"Cancel"*)
                ui_info "Backend wizard cancelled."
                break ;;
        esac
    done
}

manage_backends_menu() {
    if ! ensure_fzf; then return 1; fi

    while true; do
        local cat_dir
        cat_dir=$(get_backends_catalog_dir)
        local cur_backend="$SNAPSHOT_BACKEND"
        local active_file
        active_file=$(resolve_active_backend)
        local active_driver="None"
        [[ -n "$active_file" ]] && active_driver=$(basename "$active_file" .conf)

        local opt=(
            "--- ACTIVE DRIVER SETTING ---"
            "$(e ⚡)Active Backend Selection    [$cur_backend] (Active: $active_driver)"
            "--- WIZARD ACTIONS ---"
            "$(e ➕)Add Custom Backend (Wizard)  [Create New Driver]"
        )

        local user_confs=()
        if [[ -d "$BACKENDS_USER_DIR" ]]; then
            for f in "$BACKENDS_USER_DIR"/*.conf; do
                [[ -f "$f" ]] && user_confs+=("$f")
            done
        fi

        if [[ ${#user_confs[@]} -gt 0 ]]; then
            opt+=("--- USER CUSTOM BACKENDS (backends.d/) ---")
            for f in "${user_confs[@]}"; do
                local u_id u_name u_fmt
                u_id=$(basename "$f" .conf)
                u_name=$(_get_backend_conf_val "$f" "NAME")
                u_fmt=$(_get_backend_conf_val "$f" "STORAGE_FORMAT")
                opt+=("$(e 🛠️)${u_name:-$u_id}  [$u_id | $u_fmt]")
            done
        fi

        local cat_confs=()
        if [[ -n "$cat_dir" && -d "$cat_dir" ]]; then
            for f in "$cat_dir"/*.conf; do
                [[ -f "$f" ]] && cat_confs+=("$f")
            done
        fi

        if [[ ${#cat_confs[@]} -gt 0 ]]; then
            opt+=("--- OFFICIAL CATALOG BACKENDS ---")
            for f in "${cat_confs[@]}"; do
                local c_id c_name
                c_id=$(basename "$f" .conf)
                c_name=$(_get_backend_conf_val "$f" "NAME")
                local p_label="Inactive"
                if probe_backend_conf "$f"; then
                    p_label="Available"
                fi
                opt+=("$(e 📦)${c_name:-$c_id}  [$c_id | $p_label]")
            done
        fi

        opt+=(
            "---"
            "$(e ↩️)Return to Main Menu"
        )

        local choice
        choice=$(printf "%s\n" "${opt[@]}" | fzf --height 20 --reverse \
            --header "--- Checkpoint Backend Management (Active: $cur_backend -> $active_driver) ---" \
            --preview 'case "{}" in
                *Active*Backend*Selection*)
                    echo -e "⚡ Active Backend Selection\n──────────────────────────\nCurrently configured: '"$cur_backend"'\nCurrently resolved:   '"$active_driver"'\n\nSelect to change active backend driver between \"auto\" and installed backends." ;;
                *Add*Custom*Backend*)
                    echo -e "➕ Custom Backend Wizard\n────────────────────────\nLaunch guided step-by-step wizard to create, configure, and register a new custom snapshot driver (ZFS, BTRFS, RSYNC, LVM, or custom scripts)." ;;
                *\[*\|*)
                    sel_id=$(echo "{}" | grep -oE "\[[^|]+ \|" | sed -E "s/\[([a-zA-Z0-9_-]+) \|/\1/")
                    user_conf="'"$BACKENDS_USER_DIR"'/${sel_id}.conf"
                    cat_conf="'"$cat_dir"'/${sel_id}.conf"
                    if [[ -f "$user_conf" ]]; then
                        _render_backend_preview "$user_conf"
                    elif [[ -f "$cat_conf" ]]; then
                        _render_backend_preview "$cat_conf"
                    else
                        echo "Backend details for: ${sel_id}"
                    fi
                    ;;
                *Return*)
                    echo -e "↩️ Return to settings dashboard." ;;
                *) echo "Select an option to view details or manage." ;;
            esac' --preview-window=right:55%:wrap)

        [[ -z "$choice" || "$choice" == *"Return"* ]] && break

        case "$choice" in
            *"Active Backend Selection"*)
                local b_all=("auto")
                local b_desc=("Auto-probe the best available installed driver")
                if [[ -d "$BACKENDS_USER_DIR" ]]; then
                    for f in "$BACKENDS_USER_DIR"/*.conf; do
                        [[ -f "$f" ]] || continue
                        local bid; bid=$(basename "$f" .conf)
                        b_all+=("$bid")
                        b_desc+=("Custom: $(_get_backend_conf_val "$f" "NAME")")
                    done
                fi
                if [[ -n "$cat_dir" && -d "$cat_dir" ]]; then
                    for f in "$cat_dir"/*.conf; do
                        [[ -f "$f" ]] || continue
                        local bid; bid=$(basename "$f" .conf)
                        if [[ " ${b_all[*]} " != *" $bid "* ]]; then
                            b_all+=("$bid")
                            b_desc+=("Catalog: $(_get_backend_conf_val "$f" "NAME")")
                        fi
                    done
                fi

                local b_menu_items=()
                for i in "${!b_all[@]}"; do
                    local mark=" "
                    [[ "${b_all[$i]}" == "$SNAPSHOT_BACKEND" ]] && mark="✔"
                    b_menu_items+=("$mark ${b_all[$i]} — ${b_desc[$i]}")
                done

                local sel_b
                sel_b=$(printf "%s\n" "${b_menu_items[@]}" | fzf --height 12 --reverse \
                    --header "Select Active Snapshot Backend (Current: $SNAPSHOT_BACKEND)")
                if [[ -n "$sel_b" ]]; then
                    local picked
                    picked=$(echo "$sel_b" | awk '{print $2}')
                    if [[ -n "$picked" ]]; then
                        SNAPSHOT_BACKEND="$picked"
                        ui_ok "Active backend set to: $SNAPSHOT_BACKEND"
                    fi
                fi
                ;;
            *"Add Custom Backend"*)
                backend_wizard
                ;;
            *"["*"|"*)
                local target_id
                target_id=$(echo "$choice" | grep -oE "\[[^|]+ \|" | sed -E "s/\[([a-zA-Z0-9_-]+) \|/\1/")
                local u_target="$BACKENDS_USER_DIR/${target_id}.conf"
                local c_target="$cat_dir/${target_id}.conf"

                if [[ -f "$u_target" ]]; then
                    local actions=(
                        "$(e ⚡)Set as Active Backend"
                        "$(e ✏️)Edit Backend (Open Wizard)"
                        "$(e 📋)Duplicate Backend"
                        "$(e 🗑️)Delete Custom Backend"
                        "$(e ↩️)Cancel"
                    )
                    local act
                    act=$(printf "%s\n" "${actions[@]}" | fzf --height 8 --reverse --header "Manage Custom Backend: $target_id")
                    case "$act" in
                        *"Set as Active"*)
                            SNAPSHOT_BACKEND="$target_id"
                            ui_ok "Active backend set to '$target_id'." ;;
                        *"Edit Backend"*)
                            backend_wizard "$u_target" ;;
                        *"Duplicate"*)
                            echo -n "Enter new Backend ID for copy: "
                            local dup_id; read -r dup_id; dup_id=$(trim "$dup_id")
                            if [[ -n "$dup_id" ]]; then
                                echo -n "Enter display name for copy: "
                                local dup_name; read -r dup_name; dup_name=$(trim "$dup_name")
                                duplicate_backend "$u_target" "$dup_id" "${dup_name:-$dup_id}"
                                ui_ok "Duplicated to '$dup_id'."
                            fi ;;
                        *"Delete"*)
                            echo -n "Are you sure you want to delete custom backend '$target_id'? [y/N]: "
                            local confirm; read -r confirm
                            if [[ "${confirm,,}" == "y" || "${confirm,,}" == "yes" ]]; then
                                delete_custom_backend "$target_id"
                                [[ "$SNAPSHOT_BACKEND" == "$target_id" ]] && SNAPSHOT_BACKEND="auto"
                                ui_ok "Deleted custom backend '$target_id'."
                            fi ;;
                    esac
                elif [[ -f "$c_target" ]]; then
                    local actions=(
                        "$(e ⚡)Set as Active Backend"
                        "$(e 📋)Duplicate & Customize (Copy to User Backends)"
                        "$(e ↩️)Cancel"
                    )
                    local act
                    act=$(printf "%s\n" "${actions[@]}" | fzf --height 8 --reverse --header "Catalog Backend: $target_id")
                    case "$act" in
                        *"Set as Active"*)
                            SNAPSHOT_BACKEND="$target_id"
                            ui_ok "Active backend set to '$target_id'." ;;
                        *"Duplicate & Customize"*)
                            echo -n "Enter custom Backend ID [Enter for '${target_id}-custom']: "
                            local dup_id; read -r dup_id; dup_id=$(trim "$dup_id")
                            [[ -z "$dup_id" ]] && dup_id="${target_id}-custom"
                            echo -n "Enter display name [Enter for 'Custom $(_get_backend_conf_val "$c_target" "NAME")']: "
                            local dup_name; read -r dup_name; dup_name=$(trim "$dup_name")
                            [[ -z "$dup_name" ]] && dup_name="Custom $(_get_backend_conf_val "$c_target" "NAME")"
                            duplicate_backend "$c_target" "$dup_id" "$dup_name"
                            ui_ok "Created custom backend '$dup_id'. You can now edit its commands."
                            backend_wizard "$BACKENDS_USER_DIR/${dup_id}.conf"
                            ;;
                    esac
                fi
                ;;
        esac
    done
}
