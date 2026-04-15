# Relay

Session continuity bridge for Claude Code.

Every developer who uses Claude Code loses context when they close the session. The first 5-10 turns of every new session re-establish what was already known. Relay eliminates that tax.

On `SessionEnd`, Relay generates a structured handoff: current task state, files in flight, the next concrete action, blocking questions, and critical context that must survive. On `SessionStart`, it injects this as an operational briefing — the first thing Claude sees, framed as "here's where we are" rather than buried history.

## Research basis

YC-Bench ([arXiv:2604.01212](https://arxiv.org/html/2604.01212v1)) establishes the underlying finding: agents that fail to record adversarial client state repeat costly mistakes after conversation history is truncated. The scratchpad — what the agent retains — determines what the next session can do. Relay applies this principle to the session boundary itself: what Claude records at session close determines how effectively it can resume.

## Relay vs Archivist

Both plugins fire at session boundaries. They solve different problems at different time scales:

| | Archivist | Relay |
|---|---|---|
| Captures | Decisions, dead ends, reusable rules | Task state, next action, open blockers |
| Time horizon | All future sessions | Next session only |
| Value decay | Slow — rules stay relevant | Fast — stale once task completes |
| Injection | Filtered prose, top items only | Full operational briefing |
| Clears when | Superseded by new learning | `task.status == "complete"` |

Install both if you want both. They complement rather than duplicate — the schemas don't overlap.

### Relay vs Lore

**[Lore](../../tools/lore/README.md)** holds long-lived organizational knowledge (typed objects, decay, open-question urgency, contradiction edges). Relay stays focused on the **current task handoff**. When `inject_lore` is enabled, SessionStart injection **appends** a short Lore context block (ranked questions and related items) after the handoff prose, within `lore_max_words`. That gives the next session both immediate task state and broader epistemic signal without merging the two into one schema.

## How it works

1. **Capture** — At `SessionEnd`, an agent reads the session and writes a handoff JSON to `~/.claude/relay/handoffs/<session_id>.json`. The agent captures task state, not decisions — what's in progress, what comes next, what's blocking.

2. **Inject** — At `SessionStart`, a command script finds the most recent handoff for the current working directory and returns it as `additionalContext`. Claude sees the handoff before the user's first message. Optionally, Lore can append a compact block from `lore context-for-inject` (same cwd, word budget from config).

3. **Skip complete tasks** — If the last handoff has `task.status: "complete"`, injection is skipped. A finished task doesn't need a briefing. (Lore is not appended when injection is skipped.)

## Install

Install from the Onlooker Marketplace:

```
/plugin
# Add marketplace → https://github.com/onlooker-community/marketplace
# Then install relay from it
```

## Usage

Relay is automatic once installed. The slash command lets you inspect and manage handoffs:

```
/relay:handoff status          # Most recent handoff for current directory
/relay:handoff show            # Last 5 handoffs for current directory
/relay:handoff show --all      # All handoffs
/relay:handoff clear           # Delete most recent handoff (with confirmation)
/relay:handoff config          # Show current configuration
```

## Configuration

Edit `config.json` in the plugin directory:

| Key | Default | Description |
|-----|---------|-------------|
| `enabled` | `true` | Master enable/disable switch |
| `storage_path` | `~/.claude/relay/handoffs` | Where handoff files are stored |
| `inject_on_start` | `true` | Whether to inject at SessionStart |
| `max_handoffs_to_keep` | `10` | Maximum handoffs retained per directory |
| `max_injection_words` | `500` | Word limit on the injected briefing |
| `inject_lore` | `false` | When `true`, append Lore-ranked organizational memory after the handoff (requires [Lore](../../tools/lore/README.md) CLI) |
| `lore_max_words` | `80` | Word budget for the Lore block (separate from `max_injection_words`, which applies to the handoff itself) |

## Lore integration

Relay does not write to Lore. With **`inject_lore`: `true`**, `relay-inject.sh` calls `lore context-for-inject` for the session cwd and concatenates the result below the formatted handoff before emitting `additionalContext`. If the Lore CLI is missing, injection degrades to the handoff only.

Resolve the CLI the same way as other plugins: **`LORE_CLI`**, `lore` on `PATH`, a monorepo checkout containing `tools/lore/bin/cli.ts`, or `bunx @onlooker-community/lore`.

Use Lore when you want unresolved questions and contradiction-aware ranking to surface on **every** new session alongside Relay’s task briefing. Keep it off if you prefer a slimmer prompt or do not use Lore yet.

## Handoff schema

```json
{
  "session_id": "...",
  "cwd": "/absolute/path/to/project",
  "captured_at": "2026-04-14T18:23:00Z",
  "task": {
    "summary": "Refactoring auth middleware to use JWT",
    "status": "in_progress"
  },
  "next_action": "Add refresh token rotation to src/auth/middleware.ts starting at handleExpiry (line 47)",
  "files_in_flight": [
    {
      "path": "src/auth/middleware.ts",
      "state": "partial",
      "notes": "handleExpiry stub written, rotation logic not yet implemented"
    },
    {
      "path": "src/controllers/user_controller.ts",
      "state": "needs_review",
      "notes": "Middleware integration looks correct but not tested"
    }
  ],
  "blocking_questions": [
    "Should refresh tokens be stored in Redis or in the DB?",
    "What is the expiry window for refresh tokens — 7 days or 30?"
  ],
  "critical_context": [
    "The legacy auth path at /api/v1/auth is still live in production — do not remove it",
    "The JWT secret is set via JWT_SECRET env var, not hardcoded"
  ],
  "last_intent": "Get the refresh token rotation working so the expiry tests pass"
}
```

## Injection format

At `SessionStart`, Claude sees:

```
RELAY HANDOFF — 2026-04-14T18:23:00Z

Task: Refactoring auth middleware to use JWT [in_progress]
Next: Add refresh token rotation to src/auth/middleware.ts starting at handleExpiry (line 47)

In flight:
  • src/auth/middleware.ts (partial) — handleExpiry stub written, rotation logic not yet implemented
  • src/controllers/user_controller.ts (needs_review) — Middleware integration looks correct but not tested

Blocking:
  • Should refresh tokens be stored in Redis or in the DB?
  • What is the expiry window for refresh tokens — 7 days or 30?

Do not forget:
  • The legacy auth path at /api/v1/auth is still live in production — do not remove it
  • The JWT secret is set via JWT_SECRET env var, not hardcoded

Last intent: Get the refresh token rotation working so the expiry tests pass
```

## What Relay does NOT cover

- **In-session context loss** — Relay fires at session boundaries, not on context truncation mid-session. For mid-session memory across compaction, use Archivist
- **MCP tool activity** — Operations via MCP servers bypass Claude Code's hook system
- **Crashed sessions** — If Claude Code crashes rather than closing cleanly, `SessionEnd` may not fire. The previous handoff remains until a new one is written
- **Long-horizon learning** — Reusable rules are Archivist’s domain; the epistemic graph (questions, contradictions, decay) is Lore’s. Relay captures immediate task state only, but can **surface** Lore when `inject_lore` is enabled

## Architecture

See [docs/adr/](docs/adr/) for architecture decision records.
