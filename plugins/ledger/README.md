# Ledger

Resource governance and budget enforcement for Claude Code.

Ledger is the budget layer for the Onlooker ecosystem. It tracks token consumption, cost, and subagent spawning across all plugin activity — Tribunal's judge panel runs, Echo's regression suites, Archivist's extraction calls, everything. When a session budget is approached, it surfaces a structured warning. When the budget is exceeded, it blocks further subagent spawning.

## Research basis

The [Agent Contracts paper](https://arxiv.org/html/2601.08815) demonstrates 90% token reduction with 525× lower variance in iterative workflows through formal resource governance — conservation laws ensuring delegated budgets respect parent constraints. Ledger implements this at the Claude Code plugin level without requiring formal contract machinery.

The key insight: when an orchestrator creates subcontracts for workers, each worker must operate within defined bounds, and the aggregate must respect the original constraint — with a 10–15% reserve buffer for coordination overhead. Ledger enforces this at `SubagentStart`.

## How it works

1. **Cost accumulation** — Every time Claude finishes a response (`Stop` event), Ledger records the token usage and adds the estimated cost to the current session's running total at `~/.claude/ledger/sessions/<session_id>.json`.

2. **Subagent tracking** — When a subagent finishes (`SubagentStop`), its token usage is recorded separately under `subagent_*` fields. This lets you see how much of your session cost is attributed to spawned agents vs. direct conversation.

3. **Budget enforcement** — Before any subagent spawns (`SubagentStart`), Ledger reads the current session total and compares it to the configured budget. If the effective limit (budget × (1 − reserve_buffer_pct / 100)) is reached, the spawn is blocked with a clear message.

4. **Session summary** — At `SessionEnd`, the session file is finalized and a summary line is appended to `~/.claude/ledger/all-sessions.jsonl` for cross-session reporting.

## Install

Install from the Onlooker Marketplace:

```
/plugin
# Add marketplace → https://github.com/onlooker-community/marketplace
# Then install ledger from it
```

## Usage

Ledger is automatic once installed. Use the slash command to inspect budget state:

```
/ledger:ledger status          # Current session cost and budget consumption
/ledger:ledger report          # Last 10 sessions summary table
/ledger:ledger report --sessions 30  # Last 30 sessions
/ledger:ledger config          # Show current configuration
/ledger:ledger set-budget --cost 5.00  # Set session budget to $5.00
/ledger:ledger reset           # Clear current session ledger (fresh start)
```

## Configuration

Edit `config.json` in the plugin directory:

| Key | Default | Description |
|-----|---------|-------------|
| `enabled` | `true` | Master enable/disable switch |
| `storage_path` | `~/.claude/ledger` | Where session files are stored |
| `budgets.session_cost_usd` | `2.00` | Maximum USD spend per session (0 = no limit) |
| `budgets.warning_threshold_pct` | `80` | Warn at this % of budget |
| `reserve_buffer_pct` | `12` | Hold back this % of budget as coordination reserve |
| `block_on_budget_exceeded` | `true` | Block subagent spawns when budget is exceeded |
| `log_all_sessions` | `true` | Append session summaries to all-sessions.jsonl |

### Effective block threshold

The block fires at `session_cost_usd × (1 − reserve_buffer_pct / 100)`. With the defaults:

```
$2.00 × (1 − 0.12) = $1.76 effective limit
```

The 12% reserve ensures the budget warning response itself can be delivered without tripping the circuit breaker.

### Token-only budgets

Set `budgets.session_cost_usd` to `0` to disable cost-based budgeting. Token-count budgets (`session_input_tokens`, `session_output_tokens`) are available in config for future enforcement — set them to a positive integer to activate.

## Budget warnings

When the session reaches the warning threshold (default: 80% of budget), Ledger writes to stderr:

```
Ledger: Session budget at 83% of $2.00 (total: $1.66).
```

When the effective limit is reached and a subagent attempts to spawn:

```
Ledger: Session budget exceeded (92% of $2.00). Total cost: $1.84. Blocking subagent spawn.
Use /ledger:ledger status to review.
```

The spawn is blocked (exit code 2). Claude receives this message as actionable feedback, not just a generic failure.

## Session ledger format

Each session file at `~/.claude/ledger/sessions/<session_id>.json`:

```json
{
  "session_id": "...",
  "started_at": "2026-04-14T10:00:00Z",
  "updated_at": "2026-04-14T10:23:41Z",
  "ended_at": "2026-04-14T10:25:00Z",
  "finalized": true,
  "input_tokens": 45200,
  "output_tokens": 8300,
  "cache_read_tokens": 12000,
  "cache_creation_tokens": 3100,
  "estimated_cost_usd": 1.24,
  "subagent_count": 3,
  "subagent_input_tokens": 18400,
  "subagent_output_tokens": 4100,
  "subagent_cost_usd": 0.52,
  "stop_count": 12
}
```

`estimated_cost_usd` is the main session cost. Total session cost = `estimated_cost_usd + subagent_cost_usd`.

## What Ledger does NOT cover

- **MCP tool calls** — Tools executed via MCP server bypass Claude Code's hook system entirely
- **Cost precision** — Token counts are from the API usage fields in hook events. Cache behavior and model-specific billing details may cause small differences from the Anthropic invoice
- **In-flight subagents** — A subagent already running when the budget is exceeded will complete; only the next spawn is blocked
- **Direct API calls** — Code you write that calls the Anthropic API outside Claude Code is not tracked

## Onlooker integration

If Onlooker is installed, Ledger's session files live alongside Onlooker's event log under `~/.claude/`. The two plugins don't share hooks or state, but Onlooker's cost-tracker and Ledger's session ledger both write token counts — they are complementary: Onlooker records what happened per turn, Ledger enforces limits across turns.

## Architecture

See [docs/adr/](docs/adr/) for architecture decision records.
