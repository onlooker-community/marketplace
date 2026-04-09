---
name: gate
description: Manage Warden content gate — view status, audit log, injection patterns, and clear blocked state
---

# /warden:gate

Manage the Warden indirect prompt injection detection gate.

## Subcommands

### `status`
Display current Warden gate state:
- Whether Warden is enabled
- Current gate state (open or closed)
- Last fetched tool that triggered a scan
- Whether an injection signal is active
- Cooldown remaining (if any)
- Tools being scanned (PostToolUse targets)
- Tools being gated (PreToolUse targets)

Read config from `${CLAUDE_PLUGIN_ROOT}/config.json` and state from the configured `state_file` path.

### `audit`
Display the most recent 20 entries from the audit log at the configured `audit_log` path. Show each entry as a formatted line with: timestamp, event type (scan/gate), tool name, gate decision (allow/block/warn), and injection pattern matched (if any).

If `--blocked` is provided, filter to only show entries where the decision was "block".

If no audit log exists or it is empty, say so clearly.

### `clear`
Manually clear the injection signal and re-open the gate. This is the explicit user clearance required after an injection is detected. Reset the state file to: `injectionSignalDetected = false`, `gateOpen = true`, `cooldownRemaining = 0`.

Confirm the clearance by showing what injection signal was active and when it was detected.

### `patterns`
List all loaded injection patterns from `${CLAUDE_PLUGIN_ROOT}/patterns/*.json`. Group by category and show for each pattern:
- ID
- Description
- Severity (critical/high/medium/low)
- Regex pattern (truncated to 80 chars)

### `block`
Manually close the gate for this session. Useful when the user suspects injected content has already been processed but Warden didn't catch it. Sets `gateOpen = false` and `injectionSignalDetected = true` with reason "manual block".

## Behavior

- All commands are read-only except `clear` and `block`, which modify gate state.
- When the gate is closed, Warden's PreToolUse hooks will block Write, Edit, and Bash operations until the user runs `/warden:gate clear`.
- The `auto_clear` config option (default: false) controls whether the gate automatically re-opens. The default requires explicit user clearance per Meta's Agents Rule of Two.
- If Warden is disabled in config, all commands still work but `status` should prominently note that Warden is currently disabled.
