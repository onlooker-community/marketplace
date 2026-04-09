# Changelog

## [0.3.0](https://github.com/onlooker-community/marketplace/compare/oracle-v0.2.0...oracle-v0.3.0) (2026-04-09)


### Features

* **oracle:** rename command from oracle:oracle to oracle:calibrate ([b91143b](https://github.com/onlooker-community/marketplace/commit/b91143b1c07257626df7ea1b3eb282543882f694))

## [0.2.0](https://github.com/onlooker-community/marketplace/compare/oracle-v0.1.0...oracle-v0.2.0) (2026-04-09)


### Features

* add Oracle confidence calibration plugin with hooks for user prompts and tool usage ([4d39b9f](https://github.com/onlooker-community/marketplace/commit/4d39b9fb1a2e840f3814509d4b109c18f5ed70d7))

## [0.1.0](https://github.com/onlooker-community/oracle/compare/v0.0.0...v0.1.0) (2026-04-09)

### Features

- Initial release of Oracle confidence calibration plugin
- UserPromptSubmit hook for task ambiguity detection
- PreToolUse hooks on Write and Bash for high-consequence confidence checks
- Three-state confidence model: confident, uncertain-recoverable, uncertain-high-stakes
- Convergence sampling for ambiguous situations
- Slash command for configuration and audit inspection
