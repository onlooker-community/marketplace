# Scribe

Intent documentation from agent activity. Captures why changes were made during execution and distills them into readable documentation artifacts.

Git logs record what changed. Code comments describe what code does. Scribe records why — what problem was being solved, what tradeoffs were made, and what shaped the decision. This is documentation from intent, not documentation from code.

## How it works

1. **Capture** (PostToolUse on Write|Edit) — After each file operation, a lightweight prompt extracts the intent behind the change while the agent still has its reasoning in context. Captures are fast (≤3 seconds target) and append to a JSONL file.

2. **Distill** (Stop, SessionEnd, or manual) — Captures are grouped into logical change sets and synthesised into readable Markdown documentation. If Archivist is installed, its decisions and dead ends enrich the output.

## Install

Install from the Onlooker Marketplace:

```
/plugin
# Add marketplace → https://github.com/onlooker-community/marketplace
# Then install scribe from it
```

## Usage

Scribe is automatic once installed. Intent is captured on every file write, and documentation is distilled when the agent finishes.

```
/scribe:scribe status              # Pending captures, config, integrations
/scribe:scribe distill             # Distill current session now
/scribe:scribe distill --all       # Distill all undistilled sessions
/scribe:scribe show                # Recent documentation artifacts
/scribe:scribe show --decisions    # All decision docs
/scribe:scribe show --changes      # All change logs
/scribe:scribe open <filename>     # Display a specific artifact
/scribe:scribe captures            # Raw capture entries (debug)
/scribe:scribe config              # Current configuration
```

## Configuration

Edit `config.json` in the plugin directory:

| Key | Default | Description |
|-----|---------|-------------|
| `output_dir` | `docs/scribe` | Where documentation artifacts are written (relative to project root) |
| `capture_dir` | `~/.claude/scribe/captures` | Where JSONL capture files are stored |
| `min_captures_for_stop_distill` | `3` | Minimum captures before Stop trigger distills (prevents docs for trivial sessions) |
| `skip_trivial` | `true` | Skip capture for trivial changes (whitespace, formatting) |
| `skip_paths` | `["node_modules/", ".git/", "*.lock", "*.min.js"]` | Glob patterns for files to never capture |
| `archivist_integration` | `true` | Read Archivist session logs during distillation if available |
| `archivist_session_dir` | `~/.claude/archivist/sessions` | Where to find Archivist session files |

## Example capture entry

```json
{
  "file": "src/hooks/useAuth.ts",
  "change_type": "modified",
  "intent": "Add token refresh logic to prevent silent auth failures on long sessions",
  "decision": "Refresh 5 minutes before expiry rather than on 401, to avoid failed request retries",
  "tradeoffs": "Adds a background timer per session. Considered refresh-on-401 but rejected due to race conditions with concurrent requests",
  "follow_up": "Need to handle the case where refresh itself fails — currently falls through to logout",
  "tags": ["feature"]
}
```

## Example distilled change log

```markdown
# Changes: 2026-04-04

_Session: a1b2c3d4 · 5 files · /Users/dev/myproject_

The auth token was silently expiring during long sessions, causing API calls to fail
without meaningful error messages. The fix adds proactive token refresh — checking
expiry 5 minutes ahead rather than waiting for a 401. This avoids the race condition
that refresh-on-401 creates with concurrent requests, at the cost of a background timer
per active session.

## Files changed
- `src/hooks/useAuth.ts` — Add proactive token refresh before expiry
- `src/lib/api.ts` — Thread refresh token through API client
- `src/types/auth.ts` — Add RefreshState type for timer tracking
- `tests/hooks/useAuth.test.ts` — Cover refresh timing and failure cases
- `docs/scribe/decisions/proactive-token-refresh.md` — Decision doc

## Decisions made
→ See [Proactive token refresh](../decisions/proactive-token-refresh.md)
```

## Archivist integration

When Archivist is installed, Scribe reads its session logs during distillation to enrich documentation with structured decisions and dead ends. This avoids duplicating extraction logic — Archivist captures for the agent, Scribe captures for humans.

If Archivist is not installed, Scribe works standalone with its own capture data.

## Onlooker integration

Scribe emits `scribe_entry` events that Onlooker automatically picks up if installed. No configuration needed.

### Event schema

```json
{
  "type": "scribe_entry",
  "session_id": "...",
  "cwd": "/path/to/project",
  "artifact_type": "change_log",
  "artifact_path": "docs/scribe/changes/2026-04-04-a1b2c3d4.md",
  "file_count": 5,
  "decision_count": 1,
  "tags": ["feature", "fix"],
  "has_archivist_context": true
}
```

## Important: what Scribe captures

Scribe records the agent's stated intent — what it claimed to be doing and why. This is not a ground truth record of what the agent was "really thinking." It is the reasoning the agent articulated when asked to explain its changes, captured at the moment of execution.

This is valuable because:
- Stated intent is usually accurate and always informative
- It captures reasoning that is unrecoverable after the session ends
- Even when intent is imprecise, it provides context that git logs cannot

It is not:
- A guarantee that the code does what the intent describes
- A substitute for code review
- A complete record of all reasoning (only changes to files are captured)

## Architecture

See [docs/adr/](docs/adr/) for architecture decision records.
