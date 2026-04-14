---
name: ledger
description: View session budget status, cost breakdown, and historical spend across sessions
---

# /ledger:ledger

Manage and inspect the Ledger resource budget for the current and past sessions.

## Subcommands

### `status`

Display the current session's budget state:
- Session ID and start time
- Accumulated input/output tokens (main + subagent)
- Estimated cost so far (USD)
- Subagent count and subagent-attributed cost
- Budget limit and percentage consumed
- Whether the budget circuit breaker is armed (block_on_budget_exceeded)
- Warning threshold and reserve buffer

Read the session file from `${LEDGER_SESSIONS_DIR}/<session_id>.json` where `LEDGER_SESSIONS_DIR` is the `storage_path` from `${CLAUDE_PLUGIN_ROOT}/config.json` with `/sessions` appended.

If no session file exists yet, say so and explain that cost tracking begins on the first Stop event.

### `report [--sessions N]`

Show a summary table of the last N sessions (default: 10) from the all-sessions log at `<storage_path>/all-sessions.jsonl`.

For each session show: session ID (truncated to 12 chars), start time, duration (if ended_at is present), total input tokens, total output tokens, subagent count, and total cost in USD.

Include a totals row at the bottom.

If the log doesn't exist or is empty, say so clearly.

### `set-budget --cost <usd>`

Update the `budgets.session_cost_usd` value in `${CLAUDE_PLUGIN_ROOT}/config.json` to the provided USD amount.

Validate that the value is a positive number. Confirm the change and show the new effective block threshold (budget × (1 - reserve_buffer_pct / 100)).

### `reset`

Clear the current session's ledger file. Use this to reset accumulated cost mid-session (e.g., after a runaway loop has been manually stopped and you want a clean slate for the remaining work).

Confirm before clearing. Show the cost that will be discarded.

### `config`

Display the full current configuration from `${CLAUDE_PLUGIN_ROOT}/config.json`:
- enabled
- storage_path
- budgets (session_cost_usd, warning_threshold_pct)
- reserve_buffer_pct
- block_on_budget_exceeded
- log_all_sessions

## Behavior

- All subcommands are read-only except `set-budget` and `reset`.
- Token counts and costs are estimates based on the pricing table in `hooks/ledger-utils.sh`.
- If Ledger is disabled in config, `status` and `config` still work but note that tracking is disabled.
