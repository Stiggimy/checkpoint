# Changelog

All notable changes to Checkpoint will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- **Full CLI Localization (i18n)**: Multi-language translation catalogs (`gettext`) for snapshot prompts, banners, and interactive menus.
- **Desktop Companion GUI**: Standalone graphical dashboard for visual snapshot management and one-click system rollbacks.

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
