# Checkpoint

**Simple, safe system snapshots for Linux.**

Checkpoint creates, protects, lists, and cleans up system snapshots using **Snapper** or **Timeshift** (BTRFS and RSYNC). Use it on its own anytime before risky changes, or let [`advance`](https://github.com/Stiggimy/advance) run it automatically before and after system updates.

---

## Installation

### Quick Install (Recommended)

Install Checkpoint in one command (requires only `bash`, `tar`, and `curl` or `wget` — no `git` or `gh` needed):

```bash
curl -fsSL https://raw.githubusercontent.com/Stiggimy/checkpoint/master/bootstrap.sh | bash
```

<details>
<summary><strong>Other install methods (Inspect script first, Manual Git clone, Arch Linux PKGBUILD)</strong></summary>

#### Download and inspect before running
```bash
curl -fsSL --max-time 30 https://raw.githubusercontent.com/Stiggimy/checkpoint/master/bootstrap.sh -o checkpoint-bootstrap.sh && bash checkpoint-bootstrap.sh
```

#### Manual Git install
```bash
git clone https://github.com/Stiggimy/checkpoint.git
cd checkpoint
./install.sh
```

#### Arch Linux (PKGBUILD)
Build and install system-wide (`checkpoint-git`, tracking `master`):
```bash
git clone https://github.com/Stiggimy/checkpoint.git
cd checkpoint
makepkg -si
```
This installs the binary to `/usr/bin/checkpoint`, libraries to `/usr/lib/checkpoint`, the catalog to `/usr/share/checkpoint/catalog`, and the manual to `/usr/share/man/man1`.

</details>

---

## Quick Start & Examples

> **Tip:** Every flag has both a readable long form and a fast short shortcut (shown in parentheses below) once you are comfortable with the commands.

```bash
# Take a quick snapshot (and clean up old ones past your limit)
checkpoint

# Take a snapshot with a custom description (short: -m)
checkpoint --comment "Before GPU driver update"

# Take a protected snapshot that auto-cleanup will never delete (short: -ks -m)
checkpoint --keep-snapshot --comment "Clean working system"

# List existing snapshots (short: -l)
checkpoint --list

# Search and delete snapshots interactively (requires fzf) (short: -d)
checkpoint --delete

# Delete snapshots matching a keyword (short: -d)
checkpoint --delete "kernel"

# Run cleanup only, keeping your last N normal snapshots + all [KEEP] ones (short: -cl)
checkpoint --cleanup-only
checkpoint --keep 10 --cleanup-only  # Temporarily keep 10 normal snapshots (short: -k 10 -cl)

# Check if your snapshot backend is ready (short: -ch)
checkpoint check

# Open the interactive settings menu or backend manager
checkpoint config
checkpoint backend
```

---

## What Checkpoint Does

- 🔌 **Works with Snapper & Timeshift:** Automatically detects and uses the best snapshot tool on your system (`snapper`, `timeshift-btrfs`, or `timeshift-rsync`), or lets you add custom drivers (ZFS, LVM, custom scripts).
- 🔒 **Protected snapshots (`[KEEP]`):** Mark snapshots you never want to lose with `-ks`. Cleanup skips them permanently and does **not** count them against your normal snapshot limit.
- 🧹 **Smart rotation cleanup:** Ensures you always keep your newest `N` normal snapshots (default: `6`), regardless of how many `[KEEP]` snapshots you save.
- 🗑️ **Interactive deletion:** Browse, preview, and delete snapshots from an interactive `fzf` menu (`checkpoint -d`) or match by text.
- 🔁 **Error recovery & freeze detection:** If a snapshot command fails or freezes silently, Checkpoint alerts you and lets you `[R]etry`, `[E]dit` the command on the fly, `[W]ait`, `[S]kip`, or `[A]bort`.
- 🤖 **Pairs seamlessly with Advance:** Coordinates paired before-and-after snapshots automatically when running `advance`.

---

## Updating & Uninstalling

### Updating
```bash
checkpoint --self-update          # Update Checkpoint to the latest version (short: -U)
checkpoint self-update --repair   # Repair symlinks, libraries, or manual pages (short: -r)
```
Public installations update using only `curl`/`wget` and `tar` — no `git` or `gh` needed.

### Uninstalling
```bash
checkpoint uninstall              # Remove Checkpoint cleanly (prompts before touching config)
checkpoint uninstall --dry-run    # Preview what would be removed (short: -n)
checkpoint uninstall --keep-config # Keep ~/.config/checkpoint without prompting (short: -k)
checkpoint uninstall --purge      # Also remove ~/.config/checkpoint (short: -p)
checkpoint uninstall --yes        # Skip confirmation prompts (short: -y)
```
**Your existing Snapper or Timeshift snapshots are never touched** during uninstallation.

*(If you installed Checkpoint via your distro's package manager such as `makepkg -si`, update or remove it with your package manager instead, e.g. `sudo pacman -R checkpoint-git`.)*

---

## Complete Command Reference

| Option | Description | Example |
|---|---|---|
| **Actions** | | |
| `create` | Create a system snapshot (default when invoked with no arguments) | `checkpoint create` |
| `-nc, --no-cleanup` | Create a snapshot without running rotation cleanup | `checkpoint -nc` |
| `-cl, --cleanup-only` | Run cleanup only (keeps your last `N` normal snapshots) | `checkpoint -cl` |
| `-ch, --check` | Check if a snapshot backend is ready and exit | `checkpoint -ch` |
| `-l, --list` | List existing snapshots in a clean table | `checkpoint -l` |
| `-d, --delete [query]` | Interactive deletion menu (`fzf`) or delete by matching text | `checkpoint -d` |
| **Modifiers** | | |
| `-m, --comment <msg>` | Add a custom description to the snapshot | `checkpoint -m "Pre-upgrade"` |
| `-ks, --keep-snapshot` | Protect snapshot from auto-cleanup by tagging it `[KEEP]` | `checkpoint -ks` |
| `-f, --force-delete` | Allow deleting `[KEEP]` snapshots during cleanup or deletion | `checkpoint -f -cl` |
| `-k, --keep <N>` | Temporarily override how many normal snapshots to keep | `checkpoint -k 10` |
| `-r, --rsync` | Use an RSYNC-based backend for this run | `checkpoint -r` |
| `-b, --btrfs` | Use a BTRFS-based backend for this run | `checkpoint -b` |
| `-sd, --snapshot-device <dev>` | Override the target backup partition or filesystem UUID | `checkpoint -sd /dev/sdb1` |
| `-bk, --backend <name>` | Select a specific backend (`snapper`, `timeshift-btrfs`, `timeshift-rsync`) | `checkpoint -bk snapper` |
| `-t, --type <type>` | Snapshot phase for paired backups (`single`, `pre`, or `post`) | `checkpoint -t pre` |
| `-pi, --pre-id <id>` | Link a `post` snapshot to its matching `pre` snapshot ID | `checkpoint -t post -pi 14` |
| `-p, --porcelain` | Machine-readable `KEY="VALUE"` output for scripts and Advance | `checkpoint -p` |
| **General** | | |
| `-c, --changelog [ver\|-L\|-C\|-u\|-a]` | View release notes, browser, or latest (`-L`), current (`-C`), upcoming (`-u`), all (`-a`) | `checkpoint -c` |
| `-U, --self-update, --selfupdate` | Update Checkpoint and reinstall (add `-r`/`--repair` to repair install) | `checkpoint -U` |
| `-v, --verbose, --debug` | Enable detailed debug output | `checkpoint -v` |
| `-V, --version` | Print version and build number, then exit | `checkpoint -V` |
| `-h, --help` | Display command usage and options summary | `checkpoint -h` |
| **Subcommands** | | |
| `check` | Check snapshot backend readiness and exit status | `checkpoint check` |
| `changelog [ver\|-L\|-C\|-u\|-a]` | View release notes or open the interactive release browser | `checkpoint changelog` |
| `config` | Open the interactive settings menu (`fzf`) | `checkpoint config` |
| `backend, backends` | Open the backend manager and guided custom driver wizard | `checkpoint backend` |
| `self-update, selfupdate [-r\|--repair]` | Update Checkpoint and reinstall (supports `-r`/`--repair`) | `checkpoint self-update` |
| `uninstall [-p\|-k\|-n\|-y\|-q]` | Remove per-user Checkpoint installation (`--purge`, `--keep-config`, `--dry-run`, `--yes`, `--quiet`) | `checkpoint uninstall` |

---

## Configuration

The easiest way to configure Checkpoint is interactively via `checkpoint config`. Settings are saved in `~/.config/checkpoint/config`:

| Setting | Purpose | Default |
|---|---|---|
| `SNAPSHOT_BACKEND` | Engine to use (`auto`, `snapper`, `timeshift-btrfs`, `timeshift-rsync`, or custom ID) | `auto` |
| `DEFAULT_KEEP_LIMIT` | Number of normal snapshots to keep during cleanup | `6` |
| `ALWAYS_KEEP` | Automatically tag every new snapshot with `[KEEP]` (`true`/`false`) | `false` |
| `ALWAYS_CREATE` | Create a snapshot when `checkpoint` is run with no arguments (`true`/`false`) | `true` |
| `ALWAYS_CLEANUP` | Run rotation cleanup automatically after creating a snapshot (`true`/`false`) | `true` |
| `AUTO_RETRIES` | Automatic retries before showing the failure prompt | `1` |
| `STALL_TIMEOUT` | Freeze-detection timeout in seconds (`0` = disabled) | `0` |
| `INFINITE_RETRIES` | Keep retrying failed operations automatically (`true`/`false`) | `false` |
| `SNAPSHOT_DEVICE` | Target partition or device UUID for snapshots | *(empty)* |
| `SELF_UPDATE_CHECK` | Background update check mode (`prompt`, `notify`, `auto`, `off`) | `prompt` |
| `USE_COLOR` / `USE_EMOJI` | Enable colored output and icons (`true`/`false`) | `true` |

---

## Advanced & Customization

### Custom Snapshot Backends

All snapshot tools are defined in declarative `.conf` recipes under `catalog/backends/` or `~/.config/checkpoint/backends.d/*.conf`. You can build, duplicate, test, or edit drivers interactively with `checkpoint backend`, or write a `.conf` file directly:

```ini
SCHEMA_VERSION=2
BACKEND_ID=zfs-root
NAME="ZFS Root Dataset"
EMOJI=📸
STORAGE_FORMAT=zfs
CAP_BOOTABLE_SUBVOL=true
CAP_PAIRED_PRE_POST=false

REQUIRES_CMD=zfs
PROBE_ACTIVE_CMD="command -v zfs >/dev/null 2>&1 && zpool status >/dev/null 2>&1"
PRIORITY=15

CREATE_CMD='sudo zfs snapshot rpool/ROOT/arch@$COMMENT'
LIST_CMD='sudo zfs list -t snapshot -o name,creation -H'
DELETE_CMD='sudo zfs destroy "$SNAPSHOT"'
LIST_PARSER='awk "{ print \$1 \" | \" \$2 }"'
```

#### Available Placeholders
- `$COMMENT`: Snapshot note, description, or automatic timestamp tag.
- `$SNAP_TYPE`: Snapshot phase for paired transactions (`single`, `pre`, or `post`).
- `$PRE_ID`: Preceding pre-update snapshot ID (for linking `post` snapshots).
- `$SNAPSHOT`: Snapshot ID passed to `DELETE_CMD`.

<details>
<summary><strong>Technical Details (Snapper Behavior, Scripting IPC, XDG & Updater Internals)</strong></summary>

#### Official Snapper Driver Details
The built-in `snapper.conf` driver manages the `root` config using `--no-dbus` (avoiding `Config is in use` daemon lock contention and background comparison delays) and ASCII table borders for locale-independent parsing. Snapshot `0` and active/default snapshots (`-`, `+`, `*`) are always excluded from cleanup, and descriptions containing `|` preserve `[KEEP]` protection. If you copied `catalog/backends/snapper.conf` into a custom recipe earlier, sync `CREATE_CMD`, `LIST_CMD`, and `DELETE_CMD` from the catalog to pick up these behaviors.

#### Machine-Readable Output (`--porcelain`)
Passing `--porcelain` emits strict `KEY="VALUE"` metadata blocks on stdout (`STATUS="SUCCESS"`, `SNAPSHOT_ID="123"`, `BACKEND="snapper"`) for reliable integration with scripts and `advance`.

#### XDG Directories
Checkpoint respects `XDG_CONFIG_HOME` / `CHECKPOINT_CONFIG_DIR` (`~/.config/checkpoint`), `XDG_DATA_HOME` / `CHECKPOINT_DATA_DIR` (`~/.local/share/checkpoint`), and `XDG_CACHE_HOME` / `CHECKPOINT_CACHE_DIR` (`~/.cache/checkpoint`). Set `NO_COLOR=1` to disable ANSI colors.

#### Self-Update Internals
- **Per-user public installs (`bootstrap.sh`):** Update by downloading the `master.tar.gz` archive over HTTPS with `curl` or `wget` and extracting with `tar` (no `git` or `gh` required).
- **Git checkouts (`.git` present):** Pull the current branch from `origin` with `--ff-only` without rewriting remotes. Public HTTPS clones automatically bypass local credential helpers (`-c credential.helper=`); private clones use configured HTTPS credentials or non-interactive SSH (`BatchMode=yes`). Uncommitted tracked changes trigger an interactive auto-stash prompt in terminals (or refuse safely non-interactively).
- **Reliability guards:** Runs are serialized with `flock`, downloads/fetches default to a 30-second timeout (`SELF_UPDATE_TIMEOUT=120s` for slow connections), Ctrl+C stops helper processes cleanly, and interrupted installations are retried automatically on the next run.

</details>

---

## Documentation & License

- Full manual: `man checkpoint`
- Release history & upcoming features: [CHANGELOG.md](CHANGELOG.md) or `checkpoint -c`
- Licensed under the GNU General Public License v3.0 (GPLv3) — see [LICENSE](LICENSE)
