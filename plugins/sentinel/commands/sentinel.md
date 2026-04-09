---
name: sentinel
description: Manage Sentinel pre-flight safety gate — view config, audit log, and pattern overrides
---

# /sentinel:sentinel

Manage the Sentinel pre-flight safety gate for destructive Bash operations.

## Subcommands

### `show`
Display current Sentinel configuration:
- Whether Sentinel is enabled
- Default behaviors for each risk level (critical/high/medium/low)
- Active session overrides (patterns temporarily allowed or blocked)
- Protected paths and safe paths
- Onlooker integration status

Read config from `${CLAUDE_PLUGIN_ROOT}/config.json`.

### `audit`
Display the most recent 20 entries from the audit log at the configured `audit_log` path. Show each entry as a formatted line with: timestamp, risk level, decision, command (truncated to 80 chars), and pattern matched.

If `--tail` is provided, show the last 10 entries and note that real-time streaming is not available in this context.

If no audit log exists or it is empty, say so clearly.

### `allow --pattern <id>`
Temporarily allow a blocked or reviewed pattern for this session. Add the pattern ID to `session_overrides` with value `"allow"`. Confirm the override by showing the pattern description and its normal default behavior.

Warn that this override only lasts for the current session.

### `block --pattern <id>`
Override a log or review pattern to block for this session. Add the pattern ID to `session_overrides` with value `"block"`. Confirm the override by showing the pattern description and its normal default behavior.

### `review <command>`
Manually run Sentinel evaluation against a command string without executing it. Load all patterns from `${CLAUDE_PLUGIN_ROOT}/patterns/*.json`, match the command against them, and report:
- Whether any patterns matched
- The risk level and default behavior for each match
- The safer alternative suggested for each match
- What Sentinel would do if this command were actually executed

This is a dry-run — the command is NOT executed.

### `patterns`
List all loaded patterns from `${CLAUDE_PLUGIN_ROOT}/patterns/*.json`. Group by category and show for each pattern:
- ID
- Description
- Risk level
- Default behavior
- Whether overridden for this session

## Behavior

- All commands are read-only except `allow` and `block`, which modify session state.
- Pattern files are loaded from `${CLAUDE_PLUGIN_ROOT}/patterns/` directory.
- Session overrides do not persist across sessions.
- If Sentinel is disabled in config, all commands still work but `show` should prominently note that Sentinel is currently disabled.
