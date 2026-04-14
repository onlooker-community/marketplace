# Cartographer

Periodic audit of CLAUDE.md and `.claude/rules/` files for contradictions, stale references, and dead rules.

Every other plugin in the Onlooker ecosystem is reactive — it fires when something happens. Cartographer is the exception. It audits the persistent instruction layer that shapes every session, before problems become expensive agent misbehavior.

## The problem

CLAUDE.md files accumulate problems over time:

- A rule added in week 1 conflicts with one added in week 6 by a different developer
- A file path referenced in the instructions was deleted months ago
- A plugin reference remains after the plugin was uninstalled
- The project switched from npm to bun, but three instructions still say `npm test`
- The same rule is stated in both the project CLAUDE.md and the user CLAUDE.md with different specifics

Nobody notices until an agent does something wrong, and you spend an hour tracing the behavior to a conflicting instruction from weeks ago. Archivist captures session decisions — it doesn't audit the instruction files themselves. Scribe documents intent — it doesn't check whether that intent is still correctly encoded. Echo tests agent prompts — not the project-level instructions that shape every session.

## How it works

1. **InstructionsLoaded (command)** — When Claude Code loads instruction files, Cartographer reads the most recent audit and injects a brief summary of active issues as `additionalContext`. If the audit is stale, it notes this.

2. **InstructionsLoaded (agent, async)** — A Haiku agent runs in the background. It checks a content hash of the instruction files against the last audit. If files haven't changed and the audit is within the TTL (default: 24h), it exits immediately. If files changed, it runs the full six-category analysis and writes results to `~/.claude/cartographer/audits/`.

3. **ConfigChange (command)** — When Claude Code configuration changes (plugin installed/removed, settings updated), the hash cache is invalidated so the next session triggers a fresh audit. Plugin installation changes which `/plugin:command` references are valid.

## Install

Install from the Onlooker Marketplace:

```
/plugin
# Add marketplace → https://github.com/onlooker-community/marketplace
# Then install cartographer from it
```

## Usage

Cartographer is automatic once installed. The slash command gives you full control:

```
/cartographer:audit view           # Most recent audit for current directory
/cartographer:audit run            # Force a fresh audit now
/cartographer:audit history        # Last 10 audits
/cartographer:audit issues --severity high   # Filter by severity
/cartographer:audit config         # Show configuration
```

## Six issue categories

| Category | What it detects | Example |
|----------|----------------|---------|
| `contradiction` | Two rules that cannot simultaneously be true | "always use tabs" + "use 2-space indentation" |
| `stale_reference` | File path in instructions that no longer exists | "see ARCHITECTURE.md" — file was deleted |
| `orphaned_plugin` | `/plugin:command` reference to an uninstalled plugin | `/echo:regression` — Echo not installed |
| `dead_tool` | Tool/command that doesn't match the project's toolchain | "run `npm test`" in a bun project |
| `duplicate` | Substantially the same rule stated in multiple files | "use strict mode" + "enable strict: true in tsconfig" |
| `hierarchy_conflict` | Project instruction implicitly overrides user-level instruction | Different default formatters at user vs project level |

## Configuration

Edit `config.json` in the plugin directory:

| Key | Default | Description |
|-----|---------|-------------|
| `enabled` | `true` | Master enable/disable |
| `storage_path` | `~/.claude/cartographer` | Where audit files are stored |
| `audit_ttl_hours` | `24` | How long before an audit is considered stale |
| `min_severity_to_inject` | `"medium"` | Minimum severity to include in `additionalContext` |
| `max_issues_to_inject` | `3` | Maximum issues to show in session injection |
| `checks.contradictions` | `true` | Enable/disable each check category individually |
| `emit_health_metric` | `true` | Emit `instruction_health` events to Onlooker |

## Health score

Each audit produces a health score from 0.0 to 1.0:

```
score = 1.0 - (high_issues × 0.15 + medium_issues × 0.05 + low_issues × 0.01)
```

Clamped to [0.0, 1.0]. A score of 1.0 means no issues found. A score below 0.7 indicates the instruction files need attention.

If Onlooker is installed, the health score is emitted as an `instruction_health` event after each audit, enabling tracking of instruction quality over time.

## Audit schema

Each audit is stored as JSON in `~/.claude/cartographer/audits/`:

```json
{
  "audit_id": "project-2026-04-14T18-00-00Z",
  "audited_at": "2026-04-14T18:00:00Z",
  "cwd": "/Users/dev/project",
  "instruction_files": ["CLAUDE.md", ".claude/rules/style.md"],
  "instruction_hash": "...",
  "issue_count": { "high": 1, "medium": 2, "low": 0 },
  "issues": [
    {
      "id": "CART-001",
      "category": "contradiction",
      "severity": "high",
      "description": "CLAUDE.md says 'always use tabs' but .claude/rules/style.md says 'use 2-space indentation'",
      "files": ["CLAUDE.md", ".claude/rules/style.md"],
      "evidence": "CLAUDE.md line 4: 'always use tabs for indentation'",
      "suggestion": "Remove the conflicting rule from one file or add scope qualifiers to both"
    }
  ],
  "health_score": 0.80,
  "summary": "12 rules checked across 2 files. 1 high, 2 medium issues found."
}
```

## What Cartographer does NOT audit

- **Agent files themselves** — The quality of agent prompts is Echo's domain (via Tribunal evaluation)
- **Runtime behavior** — Whether agents are following the instructions is what Onlooker observes
- **Correctness of the rules** — Cartographer detects structural problems (contradictions, stale refs), not whether the rules themselves are good advice
- **Files outside the instruction hierarchy** — Only CLAUDE.md, `.claude/rules/`, and `.claude/agents/` are in scope

## Architecture

See [docs/adr/](docs/adr/) for architecture decision records.
