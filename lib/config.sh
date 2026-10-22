#!/usr/bin/env bash
# ==============================================================================
# Checkpoint Module: Configuration Management
# ==============================================================================

# --- INTERNAL DEFAULTS ---
USE_COLOR=true; USE_EMOJI=true; DEFAULT_KEEP_LIMIT=6
ALWAYS_KEEP=false; ALWAYS_CLEANUP=true; ALWAYS_CREATE=true
VERBOSE=false; AUTO_RETRIES=1; INFINITE_RETRIES=false
SNAPSHOT_DEVICE=""
SNAPSHOT_BACKEND="auto"

# --- BOOTSTRAP ---
load_config() {
    [[ ! -f "$CONFIG_FILE" ]] && { mkdir -p "$(dirname "$CONFIG_FILE")"; save_config; return; }
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        [[ -z "$key" || "$key" == \#* ]] && continue
        key="${key#"${key%%[![:space:]]*}"}"; key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"; value="${value%"${value##*[![:space:]]}"}"
        key="${key%$'\r'}"; value="${value%$'\r'}"
        case "$key" in
            USE_COLOR) USE_COLOR="$value" ;;
            USE_EMOJI) USE_EMOJI="$value" ;;
            DEFAULT_KEEP_LIMIT) DEFAULT_KEEP_LIMIT="$value" ;;
            ALWAYS_KEEP) ALWAYS_KEEP="$value" ;;
            ALWAYS_CLEANUP) ALWAYS_CLEANUP="$value" ;;
            ALWAYS_CREATE) ALWAYS_CREATE="$value" ;;
            AUTO_RETRIES) AUTO_RETRIES="$value" ;;
            INFINITE_RETRIES) INFINITE_RETRIES="$value" ;;
            SNAPSHOT_DEVICE) SNAPSHOT_DEVICE="$value" ;;
            SNAPSHOT_BACKEND) SNAPSHOT_BACKEND="$value" ;;
        esac
    done < "$CONFIG_FILE"
}

save_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    local tmp_file="${CONFIG_FILE}.tmp.$$"
    cat <<EOF > "$tmp_file"
USE_COLOR=$USE_COLOR
USE_EMOJI=$USE_EMOJI
DEFAULT_KEEP_LIMIT=$DEFAULT_KEEP_LIMIT
ALWAYS_KEEP=$ALWAYS_KEEP
ALWAYS_CLEANUP=$ALWAYS_CLEANUP
ALWAYS_CREATE=$ALWAYS_CREATE
AUTO_RETRIES=$AUTO_RETRIES
INFINITE_RETRIES=$INFINITE_RETRIES
SNAPSHOT_DEVICE=$SNAPSHOT_DEVICE
SNAPSHOT_BACKEND=$SNAPSHOT_BACKEND
EOF
    mv "$tmp_file" "$CONFIG_FILE"
}
