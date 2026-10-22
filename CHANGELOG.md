# Changelog

All notable changes to Checkpoint will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.35] — 2026-10-22

### Added
- **In-App Changelog Browser & Release Notes**: Added `checkpoint changelog` subcommand, `--changelog` flag, interactive FZF release notes browser in `checkpoint config`, and automatic "What's New" highlights after `checkpoint self-update`.

### Changed
- **FZF Menu & Preview Performance**: Cached static changelog preview buffers in `checkpoint config` and replaced full script re-invocations in the interactive changelog browser with direct `awk` section rendering.

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
