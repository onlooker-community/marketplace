# Sentinel

Pre-flight safety gate for destructive Bash operations in Claude Code.

Sentinel evaluates safety of intent before execution. It fires on `PreToolUse` for Bash commands matching known-dangerous patterns. The LLM evaluation layer only activates when a pattern match occurs — the vast majority of Bash calls pass through with zero latency.

## How it works

1. **Pattern pre-filter** — The hook `if` field catches commands matching dangerous patterns (`rm -rf`, `git push --force`, `DROP TABLE`, etc.). Non-matching commands pass through instantly.

2. **LLM evaluation** — Matched commands are evaluated by a single-turn prompt that classifies risk (critical/high/medium/low) and returns the configured behavior.

3. **Three behaviors:**
   - **Block** — Hard stop. Stderr explains why and suggests a safer alternative. The LLM receives actionable feedback, not just "blocked."
   - **Review** — Pauses for human confirmation via Claude Code's permission dialog.
   - **Log** — Allows execution but records to an audit log for later review.

## Install

Install from the Onlooker Marketplace:

```
/plugin
# Add marketplace → https://github.com/onlooker-community/marketplace
# Then install sentinel from it
```

## Usage

Sentinel is automatic once installed. Dangerous commands are intercepted before execution.

Use the slash command to manage it:

```
/sentinel:sentinel show                  # Current config and overrides
/sentinel:sentinel audit                 # Recent audit log entries
/sentinel:sentinel patterns              # All loaded patterns with risk levels
/sentinel:sentinel review <command>      # Dry-run evaluation without executing
/sentinel:sentinel allow --pattern <id>  # Temporarily allow a pattern this session
/sentinel:sentinel block --pattern <id>  # Temporarily block a pattern this session
```

## Configuration

Edit `config.json` in the plugin directory:

| Key | Default | Description |
|-----|---------|-------------|
| `enabled` | `true` | Master enable/disable switch |
| `default_behaviors.critical` | `"block"` | Behavior for critical-risk matches |
| `default_behaviors.high` | `"review"` | Behavior for high-risk matches |
| `default_behaviors.medium` | `"log"` | Behavior for medium-risk matches |
| `default_behaviors.low` | `"allow"` | Behavior for low-risk matches |
| `audit_log` | `~/.claude/sentinel/audit.jsonl` | Path to the audit log file |
| `protect_paths` | `[]` | Additional paths to treat as critical |
| `safe_paths` | `["/tmp", "~/.claude/archivist"]` | Paths where destructive operations are always allowed |

## Pattern categories

Patterns live in `patterns/` as JSON files grouped by category:

- **filesystem.json** — `rm -rf`, `shred`, `dd`, `chmod 777`, `find -delete`, `truncate`
- **git.json** — force push, `reset --hard`, `filter-branch`, `clean -f`, `stash drop`
- **environment.json** — writes to `.env`, credential files, `export` of secrets, shell profile modification
- **database.json** — `DROP TABLE`, `TRUNCATE`, `DELETE FROM` without WHERE, `ALTER TABLE DROP COLUMN`, migration commands
- **process.json** — `kill -9`, `pkill`, `killall`, `systemctl stop/disable`, `sudo`

Each pattern has a risk level, default behavior, and a `safer_alternative` that is shown when blocking.

## Onlooker integration

Sentinel emits `sentinel_event` entries via its audit log. Onlooker automatically picks these up if installed — no configuration needed on either side.

### Event schema

```json
{
  "type": "sentinel_event",
  "session_id": "...",
  "cwd": "/path/to/project",
  "command": "rm -rf /important (truncated to 200 chars)",
  "risk_level": "critical",
  "decision": "block",
  "pattern_matched": "fs-rm-rf-outside-safe",
  "safer_alternative": "Use trash-cli or move to a backup directory",
  "duration_ms": 3200
}
```

## What Sentinel does NOT protect against

Sentinel is scoped to Bash commands matching its pattern library. It does **not** cover:

- **Commands not matching `if` patterns** — If a destructive command isn't in the pattern library, Sentinel never sees it. The `if` field is the most important maintenance surface.
- **Operations via MCP tools** — Commands executed through MCP server tools bypass Claude Code's hook system entirely.
- **File writes via the Write tool** — Sentinel evaluates Bash commands, not file operations. Output quality evaluation is Tribunal's domain.
- **Operations initiated outside Claude Code** — Sentinel only intercepts commands that Claude Code's Bash tool executes.
- **Indirect destruction** — A script that internally runs `rm -rf` won't be caught if invoked as `python cleanup.py`.

## Headless / CI behavior

In headless contexts (no interactive terminal), the `review` behavior falls back to `block`. Sentinel will never hang waiting for input that cannot arrive.

## Architecture

See [docs/adr/](docs/adr/) for architecture decision records.
