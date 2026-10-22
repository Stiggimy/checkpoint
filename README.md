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
- 🎨 **Visual Engine:** Supports configurable Emojis and Colors.

## Installation

### Automatic (Recommended)
Clone the repository and run the installation script:
```bash
./install.sh
```

The installer uses the XDG base directories for user data and configuration.

### Manual
1. Install `timeshift` or `snapper`.
2. Install `fzf` (for interactive menus).
3. Copy the `checkpoint` script to your `PATH` (e.g., `~/.local/bin/`).
4. Copy `lib/` to `$XDG_DATA_HOME/checkpoint/lib` (default `~/.local/share/checkpoint/lib`).
5. Copy `catalog/` to `$XDG_DATA_HOME/checkpoint/catalog` (default `~/.local/share/checkpoint/catalog`).
6. Copy `checkpoint.1` to `$XDG_DATA_HOME/man/man1/` (default `~/.local/share/man/man1/`).

### Arch Linux (PKGBUILD)

A VCS `PKGBUILD` is included. It builds `checkpoint-git` from the latest commit on `master`, so rebuilding the package picks up new changes:

```bash
git clone https://github.com/Stiggimy/checkpoint.git
cd checkpoint
makepkg -si
```

The package installs the binary to `/usr/bin/checkpoint`, libraries to `/usr/lib/checkpoint`, the catalog to `/usr/share/checkpoint/catalog`, and the manual to `/usr/share/man/man1`. It provides `checkpoint` and conflicts with a non-VCS `checkpoint` package.

`self-update` only works for a git checkout. Package-managed installs should be updated with the system package manager.

## XDG directories

Checkpoint follows the XDG Base Directory specification:

- Configuration: `$XDG_CONFIG_HOME/checkpoint` (default `~/.config/checkpoint`)
- Data, libraries, and catalog: `$XDG_DATA_HOME/checkpoint` (default `~/.local/share/checkpoint`)

Set `CHECKPOINT_CONFIG_DIR`, `CHECKPOINT_DATA_DIR`, or `CHECKPOINT_CATALOG_DIR` to override those locations. Existing installations are migrated from the old hardcoded paths when the destination does not already exist.

## Configuration

Checkpoint settings can be managed interactively via `checkpoint config` or by editing `$XDG_CONFIG_HOME/checkpoint/config` (default `~/.config/checkpoint/config`):

- `SNAPSHOT_BACKEND`: Snapshot engine to use (`auto`, `snapper`, `timeshift-btrfs`, `timeshift-rsync`).
- `DEFAULT_KEEP_LIMIT`: Number of unprotected normal snapshots to retain during rotation (Default: `6`).
- `ALWAYS_KEEP`: Automatically mark all newly created snapshots as protected `[KEEP]` (`true` or `false`).
- `ALWAYS_CREATE`: Automatically create a snapshot when invoked without flags (`true` or `false`).
- `ALWAYS_CLEANUP`: Automatically prune snapshots exceeding limit when invoked without flags (`true` or `false`).
- `AUTO_RETRIES`: Number of automatic retries before prompting the user (Default: `1`).
- `INFINITE_RETRIES`: Retry failed snapshot operations continuously (`true` or `false`).
- `SNAPSHOT_DEVICE`: Target partition or device UUID for snapshots.
- `USE_COLOR` / `USE_EMOJI`: Toggle color output and emojis (`true` or `false`).

Set `NO_COLOR` to disable ANSI colors for the current session without changing the configuration file.

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
| `-v, --verbose, --debug` | Enable detailed execution debug logs | `checkpoint -v` |
| `-V, --version` | Print version information and exit | `checkpoint -V` |
| `-h, --help` | Display command usage and options summary | `checkpoint -h` |
| **Subcommands** | | |
| `config` | Interactive settings and configuration wizard via `fzf` | `checkpoint config` |
| `self-update` | Pull latest updates from a local git checkout and reinstall | `checkpoint self-update` |

See `man checkpoint` for full documentation.
