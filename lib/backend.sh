#!/usr/bin/env bash
# ==============================================================================
# Checkpoint Module: Modular Snapshot Backends & Driver Engine
# ==============================================================================

: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"
export XDG_CONFIG_HOME XDG_DATA_HOME

CHECKPOINT_CONFIG_DIR="${CHECKPOINT_CONFIG_DIR:-$XDG_CONFIG_HOME/checkpoint}"
CHECKPOINT_DATA_DIR="${CHECKPOINT_DATA_DIR:-$XDG_DATA_HOME/checkpoint}"
BACKENDS_USER_DIR="$CHECKPOINT_CONFIG_DIR/backends.d"

# Resolves official catalog directory for backends
get_backends_catalog_dir() {
    if [[ -n "$CATALOG_DIR" && -d "$CATALOG_DIR" ]]; then
        echo "$CATALOG_DIR"
    elif [[ -n "$SOURCE_DIR" && -d "$SOURCE_DIR/catalog/backends" ]]; then
        echo "$SOURCE_DIR/catalog/backends"
    elif [[ -d "$CHECKPOINT_DATA_DIR/catalog/backends" ]]; then
        echo "$CHECKPOINT_DATA_DIR/catalog/backends"
    elif [[ -d "$HOME/.local/share/checkpoint/catalog/backends" ]]; then
        echo "$HOME/.local/share/checkpoint/catalog/backends"
    elif [[ -d "/usr/share/checkpoint/catalog/backends" ]]; then
        echo "/usr/share/checkpoint/catalog/backends"
    elif [[ -d "$HOME/.local/lib/checkpoint/catalog/backends" ]]; then
        echo "$HOME/.local/lib/checkpoint/catalog/backends"
    else
        echo ""
    fi
}

# Backend state variables
BACKEND_FILE=""
BACKEND_ID=""
BACKEND_NAME=""
BACKEND_EMOJI="📸"
BACKEND_STORAGE_FORMAT=""
BACKEND_CAP_BOOTABLE_SUBVOL=false
BACKEND_CAP_PAIRED_PRE_POST=false
BACKEND_REQUIRES_CMD=""
BACKEND_PROBE_ACTIVE_CMD=""
BACKEND_PRIORITY=10
BACKEND_CREATE_CMD=""
BACKEND_LIST_CMD=""
BACKEND_DELETE_CMD=""
BACKEND_LIST_PARSER=""
BACKEND_PRE_CREATE_CMD=""
BACKEND_EXTRACT_ID_REGEX=""
BACKEND_SUBVOL_PATH_TEMPLATE=""

probe_backend_conf() {
    local conf="$1"
    [[ ! -f "$conf" ]] && return 1

    local req="" probe_cmd=""
    while IFS='=' read -r key val || [[ -n "$key" ]]; do
        key="${key#"${key%%[![:space:]]*}"}"; key="${key%"${key##*[![:space:]]}"}"
        val="${val#"${val%%[![:space:]]*}"}"; val="${val%"${val##*[![:space:]]}"}"
        # Strip outer quotes if present
        if [[ "$val" == \"*\" && "$val" =~ ^\".*\"$ ]]; then
            val="${val#\"}"; val="${val%\"}"
        elif [[ "$val" == \'*\' && "$val" =~ ^\'.*\'$ ]]; then
            val="${val#\'}"; val="${val%\'}"
        fi
        case "$key" in
            REQUIRES_CMD) req="$val" ;;
            PROBE_ACTIVE_CMD) probe_cmd="$val" ;;
        esac
    done < "$conf"

    if [[ -n "$req" ]] && ! command -v "$req" >/dev/null 2>&1; then
        return 1
    fi

    if [[ -n "$probe_cmd" ]]; then
        if ! eval "$probe_cmd" >/dev/null 2>&1; then
            return 2
        fi
    fi

    return 0
}

resolve_active_backend() {
    local cat_dir
    cat_dir=$(get_backends_catalog_dir)

    # 1. Check explicitly configured SNAPSHOT_BACKEND
    if [[ -n "$SNAPSHOT_BACKEND" && "$SNAPSHOT_BACKEND" != "auto" ]]; then
        local user_conf="$BACKENDS_USER_DIR/${SNAPSHOT_BACKEND}.conf"
        if [[ -f "$user_conf" ]]; then echo "$user_conf"; return 0; fi
        if [[ -n "$cat_dir" && -f "$cat_dir/${SNAPSHOT_BACKEND}.conf" ]]; then
            echo "$cat_dir/${SNAPSHOT_BACKEND}.conf"; return 0
        fi
    fi

    # 3. Check for symlinked/enrolled backends in user config directory
    if [[ -d "$BACKENDS_USER_DIR" ]]; then
        local best_conf="" best_pri=-1
        for bconf in "$BACKENDS_USER_DIR"/*.conf; do
            [[ ! -f "$bconf" ]] && continue
            if probe_backend_conf "$bconf"; then
                local pri
                pri=$(grep '^PRIORITY=' "$bconf" 2>/dev/null | head -n 1 | cut -d'=' -f2)
                pri="${pri:-0}"
                if [[ $pri -gt $best_pri ]]; then
                    best_pri=$pri
                    best_conf="$bconf"
                fi
            fi
        done
        [[ -n "$best_conf" ]] && { echo "$best_conf"; return 0; }
    fi

    # 4. Auto-probe catalog backends by priority
    if [[ -n "$cat_dir" && -d "$cat_dir" ]]; then
        local best_conf="" best_pri=-1
        for bconf in "$cat_dir"/*.conf; do
            [[ ! -f "$bconf" ]] && continue
            if probe_backend_conf "$bconf"; then
                local pri
                pri=$(grep '^PRIORITY=' "$bconf" 2>/dev/null | head -n 1 | cut -d'=' -f2)
                pri="${pri:-0}"
                if [[ $pri -gt $best_pri ]]; then
                    best_pri=$pri
                    best_conf="$bconf"
                fi
            fi
        done
        [[ -n "$best_conf" ]] && { echo "$best_conf"; return 0; }
    fi

    echo ""
}

load_backend() {
    local bconf
    bconf=$(resolve_active_backend)
    BACKEND_FILE="$bconf"

    if [[ -z "$bconf" || ! -f "$bconf" ]]; then
        BACKEND_ID=""
        BACKEND_NAME=""
        BACKEND_EMOJI="📸"
        BACKEND_STORAGE_FORMAT=""
        BACKEND_CAP_BOOTABLE_SUBVOL=false
        BACKEND_CAP_PAIRED_PRE_POST=false
        BACKEND_REQUIRES_CMD=""
        BACKEND_PROBE_ACTIVE_CMD=""
        BACKEND_PRIORITY=10
        BACKEND_CREATE_CMD=""
        BACKEND_LIST_CMD=""
        BACKEND_DELETE_CMD=""
        BACKEND_LIST_PARSER=""
        BACKEND_PRE_CREATE_CMD=""
        BACKEND_EXTRACT_ID_REGEX=""
        BACKEND_SUBVOL_PATH_TEMPLATE=""
        return 0
    fi

    while IFS='=' read -r key val || [[ -n "$key" ]]; do
        [[ -z "$key" || "$key" == \#* ]] && continue
        key="${key#"${key%%[![:space:]]*}"}"; key="${key%"${key##*[![:space:]]}"}"
        val="${val#"${val%%[![:space:]]*}"}"; val="${val%"${val##*[![:space:]]}"}"
        # Strip outer quotes if present
        if [[ "$val" == \"*\" && "$val" =~ ^\".*\"$ ]]; then
            val="${val#\"}"; val="${val%\"}"
        elif [[ "$val" == \'*\' && "$val" =~ ^\'.*\'$ ]]; then
            val="${val#\'}"; val="${val%\'}"
        fi

        case "$key" in
            BACKEND_ID) BACKEND_ID="$val" ;;
            NAME) BACKEND_NAME="$val" ;;
            EMOJI) BACKEND_EMOJI="$val" ;;
            STORAGE_FORMAT) BACKEND_STORAGE_FORMAT="$val" ;;
            CAP_BOOTABLE_SUBVOL) BACKEND_CAP_BOOTABLE_SUBVOL="$val" ;;
            CAP_PAIRED_PRE_POST) BACKEND_CAP_PAIRED_PRE_POST="$val" ;;
            REQUIRES_CMD) BACKEND_REQUIRES_CMD="$val" ;;
            PROBE_ACTIVE_CMD) BACKEND_PROBE_ACTIVE_CMD="$val" ;;
            PRIORITY) BACKEND_PRIORITY="$val" ;;
            CREATE_CMD) BACKEND_CREATE_CMD="$val" ;;
            LIST_CMD) BACKEND_LIST_CMD="$val" ;;
            DELETE_CMD) BACKEND_DELETE_CMD="$val" ;;
            LIST_PARSER) BACKEND_LIST_PARSER="$val" ;;
            PRE_CREATE_CMD) BACKEND_PRE_CREATE_CMD="$val" ;;
            EXTRACT_ID_REGEX) BACKEND_EXTRACT_ID_REGEX="$val" ;;
            SUBVOL_PATH_TEMPLATE) BACKEND_SUBVOL_PATH_TEMPLATE="$val" ;;
        esac
    done < "$bconf"
}

find_backend_by_format() {
    local fmt="$1"
    local cat_dir
    cat_dir=$(get_backends_catalog_dir)
    local best_id="" best_pri=-1
    for bconf in "$BACKENDS_USER_DIR"/*.conf "$cat_dir"/*.conf; do
        [[ -f "$bconf" ]] || continue
        local s_fmt
        s_fmt=$(grep '^STORAGE_FORMAT=' "$bconf" 2>/dev/null | head -n 1 | cut -d'=' -f2)
        if [[ "$s_fmt" == "$fmt" ]]; then
            local pri
            pri=$(grep '^PRIORITY=' "$bconf" 2>/dev/null | head -n 1 | cut -d'=' -f2)
            pri="${pri:-0}"
            if [[ $pri -gt $best_pri ]]; then
                best_pri=$pri
                best_id=$(basename "$bconf" .conf)
            fi
        fi
    done
    echo "$best_id"
}

# Created snapshot ID output by backend_create
CREATED_SNAP_ID=""

backend_create_snapshot() {
    local snap_type="${1:-single}"   # single | pre | post
    local comment="${2:-Manual snapshot}"
    local pre_id="$3"
    CREATED_SNAP_ID=""

    local COMMENT="$comment"
    local SNAP_TYPE="$snap_type"
    local PRE_ID="$pre_id"

    # Evaluate declarative pre-create command if defined
    if [[ -n "$BACKEND_PRE_CREATE_CMD" ]]; then
        eval "$BACKEND_PRE_CREATE_CMD"
    fi

    local exec_cmd="$BACKEND_CREATE_CMD"
    if run_with_retry "Create Snapshot" "${BACKEND_ID:-backend}" "$exec_cmd"; then
        if [[ -n "$BACKEND_EXTRACT_ID_REGEX" ]]; then
            CREATED_SNAP_ID=$(echo "$LAST_CMD_OUTPUT" | grep -oE "$BACKEND_EXTRACT_ID_REGEX" | tail -n 1)
        fi
        if [[ -z "$CREATED_SNAP_ID" ]]; then
            CREATED_SNAP_ID=$(backend_list_snapshots | head -n 1 | awk '{print $1}')
        fi
        return 0
    else
        return 1
    fi
}

backend_list_snapshots() {
    local list_cmd="$BACKEND_LIST_CMD"
    local parser="$BACKEND_LIST_PARSER"

    if [[ -n "$list_cmd" && -n "$parser" ]]; then
        eval "$list_cmd 2>/dev/null" | eval "$parser" | sort -V -r
    else
        echo ""
    fi
}

backend_delete_snapshot() {
    local snap_id="$1"
    [[ -z "$snap_id" ]] && return 1

    local SNAPSHOT="$snap_id"
    local exec_cmd="$BACKEND_DELETE_CMD"
    exec_cmd="${exec_cmd//\$SNAPSHOT/$snap_id}"

    run_with_retry "Delete Snapshot" "${BACKEND_ID:-backend}" "$exec_cmd"
}

backend_porcelain_output() {
    local status="${1:-ok}"
    local snap_id="$2"
    local err_msg="$3"

    local fs_uuid=""
    fs_uuid=$(findmnt -no UUID / 2>/dev/null || echo "")

    local subvol_rel=""
    if [[ -n "$BACKEND_SUBVOL_PATH_TEMPLATE" && -n "$snap_id" ]]; then
        local ROOT_SUBVOL
        ROOT_SUBVOL=$(findmnt -no FSROOT / 2>/dev/null || echo "")
        [[ "$ROOT_SUBVOL" == "/" ]] && ROOT_SUBVOL=""
        local SNAPSHOT_ID="$snap_id"
        subvol_rel=$(eval echo "\"$BACKEND_SUBVOL_PATH_TEMPLATE\"")
    fi

    cat <<EOF
CHECKPOINT_STATUS="${status}"
CHECKPOINT_DRIVER="${BACKEND_ID}"
CHECKPOINT_FORMAT="${BACKEND_STORAGE_FORMAT}"
CHECKPOINT_BOOTABLE="${BACKEND_CAP_BOOTABLE_SUBVOL}"
CHECKPOINT_ID="${snap_id}"
CHECKPOINT_SUBVOL_REL="${subvol_rel}"
CHECKPOINT_FS_UUID="${fs_uuid}"
${err_msg:+CHECKPOINT_ERROR=\"${err_msg}\"}
EOF
}

save_custom_backend() {
    local b_id="$1"
    local b_name="$2"
    local b_emoji="${3:-📸}"
    local b_storage="${4:-custom}"
    local b_bootable="${5:-false}"
    local b_paired="${6:-false}"
    local b_requires="${7:-}"
    local b_probe="${8:-}"
    local b_priority="${9:-10}"
    local b_create="${10:-}"
    local b_list="${11:-}"
    local b_delete="${12:-}"
    local b_parser="${13:-}"
    local b_pre_create="${14:-}"
    local b_extract_regex="${15:-}"
    local b_subvol_template="${16:-}"
    local conf_file="${17:-}"

    if [[ -z "$conf_file" ]]; then
        conf_file="$BACKENDS_USER_DIR/${b_id}.conf"
    fi

    if [[ -L "$conf_file" ]]; then
        rm -f "$conf_file"
    fi

    mkdir -p "$(dirname "$conf_file")"
    cat <<EOF > "$conf_file"
SCHEMA_VERSION=2
BACKEND_ID=${b_id}
NAME="${b_name}"
EMOJI=${b_emoji}
STORAGE_FORMAT=${b_storage}
CAP_BOOTABLE_SUBVOL=${b_bootable}
CAP_PAIRED_PRE_POST=${b_paired}

REQUIRES_CMD=${b_requires}
PROBE_ACTIVE_CMD='${b_probe}'
PRIORITY=${b_priority}

CREATE_CMD='${b_create}'
PRE_CREATE_CMD='${b_pre_create}'
EXTRACT_ID_REGEX='${b_extract_regex}'
SUBVOL_PATH_TEMPLATE='${b_subvol_template}'
LIST_CMD='${b_list}'
DELETE_CMD='${b_delete}'

LIST_PARSER='${b_parser}'
EOF
}

delete_custom_backend() {
    local b_id="$1"
    local target="$BACKENDS_USER_DIR/${b_id}.conf"
    if [[ -f "$target" || -L "$target" ]]; then
        rm -f "$target"
        return 0
    fi
    return 1
}

duplicate_backend() {
    local src_conf="$1"
    local new_id="$2"
    local new_name="$3"
    [[ ! -f "$src_conf" ]] && return 1

    mkdir -p "$BACKENDS_USER_DIR"
    local dest_conf="$BACKENDS_USER_DIR/${new_id}.conf"
    cp "$src_conf" "$dest_conf"
    sed -i -E "s/^BACKEND_ID=.*/BACKEND_ID=${new_id}/" "$dest_conf"
    sed -i -E "s/^NAME=.*/NAME=\"${new_name}\"/" "$dest_conf"
}
