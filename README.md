# Checkpoint

**Universal System Snapshot Manager**

Checkpoint is a powerful snapshot management tool supporting Snapper and Timeshift (BTRFS and RSYNC). It is designed for maximum safety and efficiency in system state archival.

## Features

- 🔌 **Modular Pluggable Backends:** Pluggable backend architecture supporting **Snapper** (`snapper`), **Timeshift BTRFS** (`timeshift-btrfs`), and **Timeshift RSYNC** (`timeshift-rsync`) via declarative recipe plugins.
- 🤖 **Standardized `--porcelain` IPC Contract:** Emits strict `KEY="VALUE"` metadata blocks for universal coordination with [`advance`](https://github.com/Stiggimy/advance) and bootloader hooks.
- 🔒 **Infinite Retention [KEEP]:** Use the `-ks` flag to mark snapshots as protected. They will stay on your disk forever and won't count toward your rotation limit.
- 🧹 **Robust Cleanup:** An advanced counting algorithm that ensures you always have exactly $N$ fresh normal snapshots, regardless of how many protected ones you have.
- 🗑️ **Interactive Deletion:** Use `checkpoint -d` to browse and delete snapshots via an interactive `fzf` menu.
- ⚡ **Auto-Discovery & Probing:** Automatically selects the best available snapshot backend on your system or respects manual overrides.
- 🧙 **Custom Backend Wizard:** Guided step-by-step setup (`checkpoint backend`) to create, test, and manage custom snapshot drivers (ZFS, BTRFS, RSYNC, LVM, or custom scripts).
- 🔄 **Smart Self-Update Detector:** Background cached check against upstream tracking branch with interactive prompt, notification, or auto-update modes.
- 🎨 **Visual Engine:** Supports configurable Emojis and Colors.

## Installation

### Automatic (Recommended)
Clone the repository and run the installation script:
```bash
./install.sh
```

### Manual
1. Install `timeshift` or `snapper`.
2. Install `fzf` (for interactive menus).
3. Copy the `checkpoint` script to your `PATH` (e.g., `~/.local/bin/`).
4. Copy `checkpoint.1` to your man directory (e.g., `~/.local/share/man/man1/`).

## Configuration

Checkpoint settings can be managed interactively via `checkpoint config` or by editing `~/.config/checkpoint/config`:

- `SNAPSHOT_BACKEND`: Snapshot engine to use (`auto`, `snapper`, `timeshift-btrfs`, `timeshift-rsync`).
- `DEFAULT_KEEP_LIMIT`: Number of unprotected normal snapshots to retain during rotation (Default: `6`).
- `ALWAYS_KEEP`: Automatically mark all newly created snapshots as protected `[KEEP]` (`true` or `false`).
- `ALWAYS_CREATE`: Automatically create a snapshot when invoked without flags (`true` or `false`).
- `ALWAYS_CLEANUP`: Automatically prune snapshots exceeding limit when invoked without flags (`true` or `false`).
- `AUTO_RETRIES`: Number of automatic retries before prompting the user (Default: `1`).
- `INFINITE_RETRIES`: Retry failed snapshot operations continuously (`true` or `false`).
- `SNAPSHOT_DEVICE`: Target partition or device UUID for snapshots.
- `SELF_UPDATE_CHECK`: Automatic self-update detector mode (`prompt`, `notify`, `auto`, `off`; Default: `prompt`).
- `USE_COLOR` / `USE_EMOJI`: Toggle color output and emojis (`true` or `false`).

## Usage

### Common Examples

```bash
# Create a normal checkpoint
checkpoint

# Create a protected checkpoint with comment
checkpoint -ks -m "Undeletable state"

# List existing snapshots
checkpoint -l

# Interactive targeted deletion via fzf
checkpoint -d

# Targeted deletion by pattern
checkpoint -d "kernel"

# Open configuration menu
checkpoint config
```

### CLI Options Reference

| Option | Description | Example |
|---|---|---|
| **Actions** | | |
| `create` | Create a system snapshot (default action when invoked with no args) | `checkpoint create` |
| `-nc, --no-cleanup` | Create snapshot without running rotation cleanup | `checkpoint -nc` |
| `-cl, --cleanup-only` | Run snapshot cleanup logic only (keeping last $N$ normal snapshots) | `checkpoint -cl` |
| `-ch, --check` | Verify snapshot backend readiness and exit | `checkpoint -ch` |
| `-l, --list` | List existing snapshots in a formatted table | `checkpoint -l` |
| `-d, --delete [query]` | Interactive deletion menu via `fzf` or matching pattern | `checkpoint -d` |
| **Modifiers** | | |
| `-m, --comment <msg>` | Add a custom description to the snapshot | `checkpoint -m "Pre-upgrade"` |
| `-ks, --keep-snapshot` | Mark snapshot as protected `[KEEP]` (never auto-deleted) | `checkpoint -ks` |
| `-f, --force-delete` | Override protection and delete `[KEEP]` snapshots | `checkpoint -f -cl` |
| `-k, --keep <N>` | Temporarily override retention limit for this run | `checkpoint -k 10` |
| `-r, --rsync` | Force RSYNC snapshot mode | `checkpoint -r` |
| `-b, --btrfs` | Force BTRFS snapshot mode | `checkpoint -b` |
| `-sd, --snapshot-device <dev>` | Override backup device path or filesystem UUID | `checkpoint -sd /dev/sdb1` |
| `--backend <name>` | Select snapshot backend (`snapper`, `timeshift-btrfs`, `timeshift-rsync`) | `checkpoint --backend snapper` |
| `--type <type>` | Paired snapshot type (`single`, `pre`, `post`) | `checkpoint --type pre` |
| `--pre-id <id>` | Link post-snapshot to preceding pre-snapshot ID | `checkpoint --type post --pre-id 14` |
| `--porcelain` | Machine-readable `KEY="VALUE"` output for automated IPC | `checkpoint --porcelain` |
| `-c, --changelog [ver]` | View release notes or open interactive FZF version browser | `checkpoint -c` |
| `-U, --self-update, --selfupdate` | Pull latest updates from local git repository and reinstall | `checkpoint -U` |
| `-v, --verbose, --debug` | Enable detailed execution debug logs | `checkpoint -v` |
| `-V, --version` | Print version information and exit | `checkpoint -V` |
| `-h, --help` | Display command usage and options summary | `checkpoint -h` |
| **Subcommands** | | |
| `check` | Verify snapshot backend readiness and exit code | `checkpoint check` |
| `changelog [ver]` | View release notes or open interactive FZF version browser | `checkpoint changelog` |
| `config` | Interactive settings and configuration wizard via `fzf` | `checkpoint config` |
| `backend, backends` | Interactive backend management & custom snapshot driver wizard | `checkpoint backend` |
| `self-update, selfupdate` | Pull latest updates from local git repository and reinstall | `checkpoint self-update` / `checkpoint selfupdate` |

See `man checkpoint` for full documentation.

For upcoming features in development and full release history, see [CHANGELOG.md](CHANGELOG.md) (or run `checkpoint -c`).

