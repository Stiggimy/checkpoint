# Changelog

All notable changes to Checkpoint will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- **High Priority — Coordinated Root + Home Snapper Snapshots**: Optional snapshots of both `/` and `/home` during each checkpoint (including Advance `pre`/`post` pairs), with reliable cross-config ID pairing, joint listing and retention/deletion (`[KEEP]` included), explicit recovery from partial failures, and separate opt-in `/home` restoration. Preserve existing root-only snapshots and the Advance-facing snapshot ID/output contract.
- **Express & Comprehensive Wizard Overhaul**: Two-tier wizard architecture (Express vs Comprehensive) with maximum field auto-inference, ultra-plain non-technical guidance for manual fields, and graceful premature exit protection (Save Partial Draft, Discard, or Continue).
- **Full CLI Localization (i18n)**: Multi-language translation catalogs (`gettext`) for snapshot prompts, banners, and interactive menus.
- **Desktop Companion GUI**: Standalone graphical dashboard for visual snapshot management and one-click system rollbacks.

## [0.13.1] — 2026-11-23

### Added
- **Complete Short-Flag Parity**: Added short flag counterparts for every remaining CLI option and subcommand flag (`-r` for `--repair`, `-bk` for `--backend`, `-t` for `--type`, `-pi` for `--pre-id`, `-p` for `--porcelain`, `-L`/`-C`/`-u`/`-a` for changelog selectors, and `-p`/`-k`/`-n` for `uninstall`).

### Changed
- **Clearer README Examples**: Reorganized README documentation for plain-language clarity, pairing readable long flags with short shortcuts in Quick Start examples.

## [0.13.0] — 2026-11-23

### Added
- **Smart Stalled-Operation Timeout & Watchdog Supervisor (`STALL_TIMEOUT`)**: Added output activity watchdog monitoring to snapshot creation and deletion operations. If a snapshot command hangs (e.g. subvolume locks or unhandled driver freezes) with no output produced for the configured duration (`STALL_TIMEOUT`), Checkpoint alerts the user with an audible bell and provides an interactive prompt: `[W]ait` (extend timeout), `[T]erminate` (cleanly kill process tree and open retry/edit escalation menu), or `[A]bort`.
- **Watchdog Configuration Setting**: Added interactive configuration for `STALL_TIMEOUT` in `checkpoint config` under Error Handling.
- **Standalone Zero-Dependency Public Installer (`bootstrap.sh`) & Tarball Self-Update**: Added a one-line standalone public installer and self-update path that require only `bash`, `tar`, and `curl` or `wget` (no `git` or `gh` needed), while preserving Git-based fast-forward updates for `.git` checkouts. Supports fresh installation into XDG data directories, dangling symlink recovery, and safe repair of interrupted installs.
- **Clean Uninstaller (`uninstall.sh` / `checkpoint uninstall`)**: Added a dedicated per-user uninstaller supporting `--dry-run`, `--keep-config`, `--purge`, and `-y`/`--yes`, while preserving existing Snapper/Timeshift snapshots and custom backend recipes by default.
- **Self-Update Locking, Auto-Repair & `--repair`**: Added `flock` concurrency locking to self-update and background checks, automatic detection and repair of missing symlinks or man pages, diverged-branch recovery guidance, and an explicit `checkpoint self-update --repair` flag.
- **XDG-Aware Installer & Zsh PATH Setup**: Updated `install.sh` and `checkpoint` entrypoint to honor `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, and `CHECKPOINT_DATA_DIR`, back up real files before symlinking, and configure `~/.local/bin` in `~/.zshrc` as well as `~/.bashrc`.

### Fixed
- **Incomplete Self-Update Installation Recovery**: Remember a failed installation after a successful Git pull and retry it on the next self-update, instead of incorrectly treating the update as complete.
- **Self-Update Cancellation and Local Work Protection**: Ctrl+C stops Git and its helper processes promptly. Self-update refuses detached HEADs, missing origin, and invalid Git checkouts before pulling; failures retain their exit status. Interactive runs offer automatic stashing when uncommitted tracked changes exist, while non-interactive runs refuse safely.
- **Self-Update Connectivity and Authentication Errors**: Public HTTPS installations automatically bypass local credential helpers so stalled helpers (such as GitHub CLI) cannot block updates; private checkouts retain configured HTTPS/SSH authentication with clear recovery guidance and bounded timeouts.
- **Self-Update Source Preservation**: Self-update keeps the configured origin unchanged and shows the source checkout and origin branch before pulling.

## [0.12.1] — 2026-11-03

### Fixed
- **Changelog Browser Preview Pane**: Resolved an issue where release notes failed to render in the right-hand preview pane of the interactive release notes browser (`checkpoint changelog` and configuration menu) due to literal single-quote wrapping in AWK target variable passing.

## [0.12.0] — 2026-11-03

### Added
- **Interactive Command Editor on Retry (`[E]dit`)**: Added an `[E]dit` option to the failure escalation prompt (`[R]etry | [E]dit | [S]kip | [A]bort`), pre-populating an interactive Readline prompt with the failing snapshot command so users can customize flags on the fly before retrying.
- **Arch Linux Packaging (`PKGBUILD`)**: Added VCS `PKGBUILD`, `.SRCINFO`, and `checkpoint-git.install` for system-wide Arch Linux installation (`makepkg -si`) in lockstep with Advance.

## [0.11.5] — 2026-11-02

### Fixed
- **Snapper D-Bus Lock Contention**: Added `--no-dbus` to the official Snapper driver recipe (`CREATE_CMD`, `LIST_CMD`, and `DELETE_CMD`), operating directly via the library/filesystem layer. This resolves `Config is in use` errors during post-update snapshot deletion and avoids background comparison latency.

## [0.11.4] — 2026-10-27

### Fixed
- **Snapper Cleanup in UTF-8 Locales**: Fixed empty snapshot lists and skipped cleanup caused by Unicode table separators. Snapshot descriptions containing `|` now retain their full text, including `[KEEP]` protection tags.

## [0.11.2] — 2026-10-24

### Fixed
- **Backend Selection Parser**: Resolved an issue in the interactive backend manager where unselected items had leading spaces causing field splitting to select an em-dash (`—`) instead of the chosen backend ID.
- **Backend Configuration Persistence**: Added immediate configuration saving (`save_config`) when activating backends in the backend manager (`checkpoint backend` or via settings), preventing changes from being discarded on exit.
- **Snapper Probe Privilege Independence**: Relaxed Snapper's `PROBE_ACTIVE_CMD` to check `/etc/snapper/configs/root` existence without requiring active sudo authentication, allowing Snapper to be properly detected as Available in unprivileged configuration menus and `auto` mode.
- **Catalog Symlink Auto-Resolution**: Prevented enrolled catalog symlinks in `~/.config/checkpoint/backends.d/` from shadowing higher-priority catalog backends during automatic driver resolution.

## [0.11.1] — 2026-10-23

### Added
- **Official Licensing (GNU GPLv3)**: Formally licensed the project under the GNU General Public License v3.0, adding official `LICENSE` file, and standard GNU copyright & warranty disclaimer notices to `--version` and source headers.
- **Dynamic CLI Help Layout Engine**: Implemented `print_help_entry` to dynamically calculate column spacing, wrap long option descriptions to terminal width, and align continuation lines.

### Fixed
- **CLI Help Formatting**: Replaced manual column padding in `checkpoint -h` with dynamic formatting that adapts to terminal width and emoji display settings.

## [0.11.0] — 2026-10-23

### Added
- **Interactive Custom Backend Wizard**: Added guided step-by-step setup (`checkpoint backend` or via `checkpoint config`) with both *Guided Walkthrough* and *Quick Setup*, smart binary inference (`REQUIRES_CMD`), storage format selection, listing/deletion configuration, and full Review & Edit screen.
- **Backend Driver Management Subsystem**: Added interactive management for snapshot backends, allowing switching active drivers, duplicating official catalog backends to custom recipes in `~/.config/checkpoint/backends.d/`, and in-place editing or deletion.

## [0.10.1] — 2026-10-23

### Fixed
- **CLI Help Menu Alignment**: Added dedicated `General:` section and aligned modifier and general option descriptions in `checkpoint -h` for uniform terminal presentation.

## [0.10.0] — 2026-10-23

### Added
- **Smart Self-Update Detector**: Added an asynchronous, non-blocking background update detector that queries upstream git tracking branches with a 6-hour cache, atomic cache storage, and customizable response behavior via `SELF_UPDATE_CHECK` (`prompt`, `notify`, `auto`, `off`).
- **Interactive Self-Update Prompt**: Added interactive prompt (`[Y/n/a/d]`) when new updates are detected, with one-touch immediate update and transparent re-execution of the original command, version skipping, and automatic mode switching.
- **Self-Update Preferences Hub**: Added dedicated `Self-Update Check` selector in `checkpoint config` (under *Error Handling*) with live mode previews and real-time FZF selector.
- **Self-Update Command Expansion (`selfupdate`, `-U`)**: Added `selfupdate` alongside `self-update`, along with `-U`, `--self-update`, and `--selfupdate` CLI flags for quick updates across option parsing, help text, man pages, and documentation.

## [0.9.35] — 2026-10-23

### Added
- **Backend Readiness Prober (`checkpoint check` / `-ch`)**: Added `check` subcommand and `-ch` / `--check` flags for instant pre-flight verification of snapshot backend readiness and CLI/porcelain IPC status.
- **Changelog Short Flag (`-c`)**: Added `-c` short flag for `--changelog` across CLI option parsing, help text, and documentation for quick access to formatted release notes and the interactive FZF browser.
- **XDG Base Directory Support**: Paths now respect `XDG_CONFIG_HOME` and `XDG_DATA_HOME` with declarative fallback.
- **Automatic `fzf` Dependency Installation**: Automatically installs `fzf` during `install.sh` and upon opening interactive menus (`checkpoint config`, `checkpoint -d`) using catalog package manager templates or official release fallback.
- **In-App Changelog Browser & Release Notes**: Added `checkpoint changelog` subcommand, `--changelog` flag, interactive FZF release notes browser in `checkpoint config`, and automatic "What's New" highlights after `checkpoint self-update`.

### Changed
- **FZF Menu & Preview Performance**: Cached static changelog preview buffers in `checkpoint config` and replaced full script re-invocations in the interactive changelog browser with direct `awk` section rendering.
- **Packaged Install Guard & Fast-Forward Self-Update**: `checkpoint self-update` now detects system-wide package installations, enforces `--ff-only` pulls, and aligns legacy repository remote URLs automatically.

### Fixed
- **Headless & WSL Notification Fallback**: Silenced stderr output from `notify-send` when the desktop DBus notification daemon is unavailable.

## [0.9.34] — 2026-10-21

### Added
- **Declarative Backend Catalog Engine**: Migrated snapshot backend drivers and detection rules to declarative catalog configuration files (`catalog/backends/*.conf`).
- **Tabular Snapshot Listing**: Added `checkpoint -l` / `--list` providing clean, formatted tabular summaries of snapshot IDs, dates, and descriptions.
- **Targeted Deletion Browser**: Added `checkpoint -d` interactive deletion browser and pattern matching for single and batch snapshot removals.
- **In-App Changelog Browser**: Added `checkpoint changelog` subcommand, `--changelog` flag, and interactive version browser in `checkpoint config`.

### Changed
- **Direct Terminal Input Handling**: Streamlined privilege escalation handling so interactive password input displays cleanly without terminal deadlocks or output buffering delays.
- **Hardened Self-Update Engine**: Explicitly pulls the current upstream tracking branch and cleanly aborts if network or pull errors occur.
- **Porcelain IPC Output Quoting**: Escaped quotes within porcelain machine-readable messages to guarantee strict key-value parsing contracts for caller applications.

### Fixed
- **Version-Aware Snapshot Pruning**: Switched snapshot age sorting to numerical version sorting (`sort -V -r`), ensuring snapshot IDs with multi-digit numbers are pruned in strict chronological order without data loss.
- **Settings Menu Escape Handling**: Fixed case-sensitivity matching in the interactive settings menu so pressing ESC exits reliably without looping.
- **Snapshot ANSI Output Formatting**: Resolved variable expansion in snapshot deletion lists, ensuring color highlights render correctly in terminal dialogs.

## [0.9.33] — 2026-10-20

### Added
- **Cross-Platform Shipping Support**: Integrated with native `ship.ps1` and `ship.sh` pipelines for lockstep version bumping and pre-flight validation.

## [0.9.25] — 2026-10-20

### Added
- **Unified Snapshot Backend Configuration**: Consolidated backend selection and snapshot device options in configuration files.
- **Dynamic Snapshot Retention Limits**: Supported configurable keep limits with runtime overrides via `-k` / `--keep`.

## [0.9.1] — 2026-10-15

### Added
- **Modular Multi-File Architecture**: Decomposed snapshot operations into modular libraries (`backend.sh`, `snapshot.sh`, `menu.sh`, `core.sh`, `config.sh`).
- **Paired Transactional Snapshots**: Supported `--type single|pre|post` and `--pre-id` linking for coordinated safety snapshots with Advance.
- **Multi-Backend Support**: Added drivers for Snapper BTRFS, Timeshift BTRFS, and Timeshift RSYNC backends.
