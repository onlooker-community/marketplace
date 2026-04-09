# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0](https://github.com/onlooker-community/marketplace/compare/onlooker-v0.4.0...onlooker-v0.5.0) (2026-04-09)


### Features

* Add Onlooker observability plugin with initial hooks and metrics analysis ([27ab7f4](https://github.com/onlooker-community/marketplace/commit/27ab7f4ab5a8e4d9b3c7f119b6bac078c7b9b48e))
* read input data from standard input in cost-tracker hook ([dae9378](https://github.com/onlooker-community/marketplace/commit/dae93785ffb660116ebe12719d5b4b8e679b994b))
* replace Python scripts with Bash scripts for archivist extraction and injection, and add shared utilities ([e1c2491](https://github.com/onlooker-community/marketplace/commit/e1c24917a9be6339e1d29c26d7ccf79ebff132de))

## [0.4.0](https://github.com/onlooker-community/marketplace/compare/onlooker-v0.3.0...onlooker-v0.4.0) (2026-04-09)


### Features

* read input data from standard input in cost-tracker hook ([dae9378](https://github.com/onlooker-community/marketplace/commit/dae93785ffb660116ebe12719d5b4b8e679b994b))

## [0.3.0](https://github.com/onlooker-community/marketplace/compare/onlooker-v0.2.0...onlooker-v0.3.0) (2026-04-09)


### Features

* replace Python scripts with Bash scripts for archivist extraction and injection, and add shared utilities ([e1c2491](https://github.com/onlooker-community/marketplace/commit/e1c24917a9be6339e1d29c26d7ccf79ebff132de))

## [0.2.0](https://github.com/onlooker-community/marketplace/compare/onlooker-v0.1.0...onlooker-v0.2.0) (2026-04-09)


### Features

* Add Onlooker observability plugin with initial hooks and metrics analysis ([27ab7f4](https://github.com/onlooker-community/marketplace/commit/27ab7f4ab5a8e4d9b3c7f119b6bac078c7b9b48e))

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
