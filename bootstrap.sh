#!/usr/bin/env bash
# Standalone public installer. Keep this usable without a working Checkpoint CLI, git, or gh.
set -eu

die() {
    echo "checkpoint: $*" >&2
    exit 1
}

parse_timeout_secs() {
    local raw="${1:-${SELF_UPDATE_TIMEOUT:-30s}}"
    if [[ "$raw" =~ ^([0-9]+)(\.[0-9]+)?([smh]?)$ ]]; then
        local num="${BASH_REMATCH[1]}" frac="${BASH_REMATCH[2]}" unit="${BASH_REMATCH[3]}"
        case "$unit" in
            m) num=$((num * 60)) ;;
            h) num=$((num * 3600)) ;;
        esac
        if [[ "$num" -lt 1 && -n "$frac" ]]; then num=1; fi
        [[ "$num" -lt 1 ]] && num=30
        echo "$num"
    else
        echo 30
    fi
}

download_file() {
    local url="$1" dest="$2"
    local secs
    secs=$(parse_timeout_secs "${SELF_UPDATE_TIMEOUT:-30s}")
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 15 --max-time "$secs" "$url" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        if [[ "$url" == file://* ]]; then
            local src_path="${url#file://}"
            [[ -f "$src_path" ]] || die "Archive not found: $src_path"
            cp -f -- "$src_path" "$dest"
        else
            wget -q --timeout="$secs" -O "$dest" "$url"
        fi
    else
        die "Either curl or wget is required to install Checkpoint."
    fi
}

network_git() {
    local -a cmd=(
        env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true SSH_ASKPASS=/bin/true
        SSH_ASKPASS_REQUIRE=never
        "GIT_SSH_COMMAND=${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=15}"
    )
    if command -v timeout >/dev/null 2>&1; then
        cmd+=(timeout -k 2s "${SELF_UPDATE_TIMEOUT:-30s}")
    fi
    "${cmd[@]}" git -c credential.helper= "$@"
}

install_tarball() {
    local archive_url="$1" raw_url="$2" checkout="$3" data_dir="$4"
    command -v tar >/dev/null 2>&1 || die "tar is required to install Checkpoint."
    (
        local staging extracted
        staging=$(mktemp -d "$data_dir/.install.XXXXXXXX")
        trap 'rm -rf -- "$staging"' EXIT
        download_file "$archive_url" "$staging/archive.tar.gz"
        mkdir -p "$staging/extract"
        tar -xzf "$staging/archive.tar.gz" -C "$staging/extract"
        extracted=$(find "$staging/extract" -mindepth 1 -maxdepth 1 -type d | head -n 1)
        [[ -n "$extracted" && -f "$extracted/checkpoint" && -f "$extracted/install.sh" ]] ||
            die "Downloaded archive does not contain a valid Checkpoint distribution."
        {
            echo "CHANNEL=public"
            echo "METHOD=tarball"
            echo "ARCHIVE_URL=$archive_url"
            echo "RAW_SCRIPT_URL=$raw_url"
        } > "$extracted/.install-channel"
        chmod +x "$extracted/checkpoint" "$extracted/install.sh"
        [[ -f "$extracted/uninstall.sh" ]] && chmod +x "$extracted/uninstall.sh"
        [[ -f "$extracted/bootstrap.sh" ]] && chmod +x "$extracted/bootstrap.sh"

        if [[ -e "$checkout" || -L "$checkout" ]]; then
            mv -- "$checkout" "$staging/prev"
            if ! mv -T -- "$extracted" "$checkout"; then
                mv -- "$staging/prev" "$checkout" 2>/dev/null || true
                die "Failed to update $checkout; previous files were restored."
            fi
        else
            mv -T -- "$extracted" "$checkout"
        fi
    )
}

usage() {
    cat <<'EOF'
Usage: bootstrap.sh [OPTIONS]

Install, update, or repair a per-user Checkpoint installation from the public repository.
Requires only bash, tar, and curl or wget (no git or gh required).

Options:
  -q, --quiet   Pass --quiet to install.sh
  -h, --help    Display this help and exit
EOF
}

main() {
    local quiet=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -q|--quiet) quiet=true; shift ;;
            -h|--help) usage; return 0 ;;
            *) die "Unknown option: $1 (run with --help for usage)" ;;
        esac
    done

    local git_url=https://github.com/Stiggimy/checkpoint.git
    local archive_url="${CHECKPOINT_ARCHIVE_URL:-https://github.com/Stiggimy/checkpoint/archive/refs/heads/master.tar.gz}"
    local raw_url="${CHECKPOINT_RAW_SCRIPT_URL:-https://raw.githubusercontent.com/Stiggimy/checkpoint/master/checkpoint}"
    local data_dir="${CHECKPOINT_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/checkpoint}"
    local checkout="$data_dir/source" launcher="$HOME/.local/bin/checkpoint"
    local active target origin revision mode=""

    if [[ -L "$launcher" && ! -e "$launcher" ]]; then
        [[ "$quiet" == true ]] || echo "checkpoint: replacing broken launcher symlink at $launcher..."
        rm -f -- "$launcher"
    fi

    if [[ -L "$launcher" && -e "$launcher" ]]; then
        target=$(readlink -f "$launcher")
        checkout=$(dirname "$target")
        if [[ "$target" == "$checkout/checkpoint" && -e "$checkout/.git" ]]; then
            mode="git"
        elif [[ "$target" == "$checkout/checkpoint" && -f "$checkout/.install-channel" ]]; then
            mode="tarball"
        else
            die "Existing launcher at $launcher points outside a Checkpoint installation."
        fi
    elif [[ -e "$launcher" ]] || active=$(type -P checkpoint 2>/dev/null || true); then
        if [[ -e "$launcher" || -n "${active:-}" ]]; then
            die "Found an existing installation at ${active:-$launcher}. Use its original installation method."
        fi
    fi

    mkdir -p "$data_dir"
    if command -v flock >/dev/null 2>&1; then
        exec 9>"$data_dir/bootstrap.lock"
        flock -n 9 || die "Another Checkpoint installation is in progress."
    fi

    if [[ -z "$mode" ]]; then
        if [[ -e "$checkout/.git" ]]; then
            mode="git"
        else
            mode="tarball"
        fi
    fi

    if [[ "$mode" == "tarball" ]]; then
        if [[ -f "$checkout/.install-channel" ]] && ! grep -qx 'CHANNEL=public' "$checkout/.install-channel" 2>/dev/null; then
            die "Channel in $checkout/.install-channel is outside the public Checkpoint repository."
        fi
        install_tarball "$archive_url" "$raw_url" "$checkout" "$data_dir"
    else
        command -v git >/dev/null 2>&1 || die "Git is required to update the existing Git checkout at $checkout."
        [[ -e "$checkout/.git" ]] || die "Expected a Git checkout at $checkout."
        origin=$(git -C "$checkout" config --get remote.origin.url) || die "Missing origin in $checkout."
        case "${origin%.git}" in
            https://github.com/Stiggimy/checkpoint|git@github.com:Stiggimy/checkpoint|ssh://git@github.com/Stiggimy/checkpoint) ;;
            *) die "Origin in $checkout is outside the public Checkpoint repository. Check your update channel." ;;
        esac
        [[ "$(git -C "$checkout" branch --show-current)" == master ]] ||
            die "Switch $checkout to master before running the public installer (git -C \"$checkout\" checkout master)."
        git -C "$checkout" diff --quiet HEAD -- ||
            die "Save tracked changes in $checkout before updating (git -C \"$checkout\" stash push -m \"before update\")."
        network_git -C "$checkout" fetch --progress "$git_url" refs/heads/master:refs/remotes/origin/master
        revision=$(git -C "$checkout" rev-parse refs/remotes/origin/master)
        git -C "$checkout" merge-base --is-ancestor HEAD "$revision" ||
            die "Local commits in $checkout need review before updating (git -C \"$checkout\" log --oneline origin/master..HEAD)."
        git -C "$checkout" merge --ff-only --no-overwrite-ignore "$revision"
    fi

    if [[ "$quiet" == true ]]; then
        "$checkout/install.sh" --quiet
    else
        "$checkout/install.sh"
    fi
    "$launcher" --version >/dev/null
}

main "$@"
