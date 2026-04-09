---
name: oracle
description: Manage Oracle confidence calibration — view config, audit log, and calibration state
---

# /oracle:oracle

Manage the Oracle confidence calibration gate.

## Subcommands

### `show`
Display current Oracle configuration:
- Whether Oracle is enabled
- Confidence thresholds (proceed / flag boundaries)
- High-consequence tools being monitored
- Skip patterns (commands that bypass calibration)
- Convergence sampling status
- Audit log path

Read config from `${CLAUDE_PLUGIN_ROOT}/config.json`.

### `audit`
Display the most recent 20 entries from the audit log at the configured `audit_log` path. Show each entry as a formatted line with: timestamp, hook trigger (UserPromptSubmit/PreToolUse), confidence state (confident/uncertain_recoverable/uncertain_high_stakes), and the assumption or concern if present.

If `--uncertain` is provided, filter to only show entries where the state was not "confident".

If `--high-stakes` is provided, filter to only show entries where the state was "uncertain_high_stakes".

If no audit log exists or it is empty, say so clearly.

### `stats`
Compute calibration statistics from the audit log:
- Total assessments performed
- Breakdown by state (confident / uncertain_recoverable / uncertain_high_stakes)
- Breakdown by trigger (UserPromptSubmit / PreToolUse:Write / PreToolUse:Bash)
- Most common assumptions surfaced
- Rate of high-stakes pauses (should be low — if high, thresholds may need tuning)

### `threshold --proceed <value> --flag <value>`
Adjust confidence thresholds for this session. Both values should be between 0 and 1, and proceed must be greater than flag.

- `--proceed`: Confidence level above which Oracle always allows (default: 0.8)
- `--flag`: Confidence level below which Oracle escalates to high-stakes pause (default: 0.5)

Warn that this override only lasts for the current session.

### `disable`
Temporarily disable Oracle for this session. Oracle hooks will still fire but will always return confident. Useful when doing exploratory work where frequent pauses are counterproductive.

Warn that this only lasts for the current session.

### `enable`
Re-enable Oracle if it was disabled for this session.

## Behavior

- All commands are read-only except `threshold`, `disable`, and `enable`, which modify session state.
- Session overrides do not persist across sessions.
- If Oracle is disabled in config, all commands still work but `show` should prominently note that Oracle is currently disabled.
- Oracle is designed to have a low false-positive rate — if `stats` shows frequent high-stakes pauses, suggest the user review skip patterns or adjust thresholds.
