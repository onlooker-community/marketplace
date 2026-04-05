# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Added cost tracking script for `Stop` events

### Changed
-

### Deprecated
-

### Removed
-

### Fixed
-

### Security
-

## [0.1.0] - 2026-04-05

### Added
- Initial Onlooker observability implementation.
- Skill and read-tracking hooks, with supporting scripts.
- Session tracking and validation utilities.

### Changed
- Updated `session-start-tracker.sh` to simplify command execution and use executable mode.
- Refactored repository metadata format in `plugin.json`.
- Updated `settings.json` agent configuration, then removed the `agent` field.

### Removed
- Deprecated custom metrics and event emission hooks.

### Fixed
- Normalized hook and settings behavior during startup/session tracking updates.
