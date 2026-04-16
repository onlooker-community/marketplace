# Development

This document covers working in the Onlooker Marketplace monorepo — setting up the environment, understanding the structure, running quality checks, and creating or modifying plugins.

## Prerequisites

- [mise](https://mise-en-place.jdx.dev) — manages the Bun runtime version
- [Bun](https://bun.sh) — JavaScript runtime and package manager (installed via mise)
- Git

## Setup

```bash
git clone git@github.com:onlooker-community/marketplace
cd marketplace
mise install        # installs Bun version from mise.toml
bun install         # installs dev dependencies (linting, formatting, etc.)
```

## Repository structure

```text
marketplace/
├── plugins/              # One directory per plugin
│   ├── <name>/
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json     # Required: plugin manifest
│   │   ├── agents/             # Agent prompt files (.md)
│   │   ├── commands/           # Slash command definitions (.md)
│   │   ├── hooks/              # Shell scripts for lifecycle hooks
│   │   ├── scripts/            # Supporting utility scripts
│   │   ├── docs/adr/           # Architecture decision records
│   │   ├── CHANGELOG.md        # Version history
│   │   └── README.md           # Plugin documentation
├── tools/                # Internal development tooling
│   ├── dashboard/        # Grafana-based metrics dashboard
│   └── lore/             # Shared epistemic store (knowledge graph)
├── docs/                 # This documentation
│   ├── architecture/     # Cross-cutting architecture decisions
│   ├── research/         # Academic papers that informed the system
│   └── plugins/          # Plugin directory and summaries
└── package.json          # Workspace root with lint/format scripts
```

## Available scripts

```bash
bun run lint            # Run all linters in parallel
bun run lint:biome      # Biome lint (TypeScript/JS)
bun run lint:format     # Biome format check
bun run lint:markdown   # Markdown lint
bun run lint:spelling   # Spell check (cspell)
bun run lint:knip       # Dead code / unused exports check

bun run fix             # Run all auto-fixers in sequence
bun run fix:lint        # Auto-fix lint issues
bun run fix:format      # Auto-format all files
bun run fix:markdown    # Auto-fix markdown issues
```

Linting and formatting run automatically on staged files via a pre-commit hook (husky + lint-staged).

## Commit conventions

This repository uses [Conventional Commits](https://www.conventionalcommits.org/). The commit message format is enforced by `commitlint`:

```
<type>(<scope>): <description>

feat(sentinel): add database pattern for TRUNCATE without WHERE
fix(archivist): handle missing storage directory on first run
chore: update bun lockfile
docs(tribunal): document meta-judge bias categories
```

Common types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`.

The scope is typically the plugin name (e.g., `sentinel`, `archivist`) or omitted for cross-cutting changes.

## Creating a new plugin

The repository includes a `create-new-plugin` skill that scaffolds a new plugin with the correct structure:

```
/create-new-plugin
```

This creates `plugins/<name>/` with:

- `.claude-plugin/plugin.json` — manifest with name, version, description
- `commands/` — placeholder command file
- `hooks/` — placeholder hook script
- `CHANGELOG.md` — initial changelog entry
- `README.md` — documentation template

### Plugin manifest (`plugin.json`)

Every plugin must have a `.claude-plugin/plugin.json`:

```json
{
  "name": "my-plugin",
  "version": "0.1.0",
  "description": "One sentence describing what the plugin does.",
  "author": {
    "name": "Onlooker Community",
    "url": "https://github.com/onlooker-community"
  },
  "license": "MIT",
  "keywords": ["relevant", "tags"],
  "commands": ["./commands/my-command.md"],
  "agents": ["./agents/my-agent.md"],
  "hooks": ["./hooks/my-hook.sh"]
}
```

Only `name`, `version`, and `description` are required. All path fields (`commands`, `agents`, `hooks`) are relative to the plugin root.

### Writing a command

Commands are Markdown files that define slash commands. The frontmatter is required:

```markdown
---
name: my-command
description: What this command does
argument-hint: [optional-arg]
---

# Command Title

Instructions to Claude for how to handle this command.
```

The command is invoked as `/my-plugin:my-command [arg]`.

### Writing a hook

Hooks are shell scripts in `hooks/`. They map to Claude Code lifecycle events via the plugin's settings configuration. The script receives event context via environment variables or stdin depending on the event type.

Common lifecycle events and their uses:

| Event | Used by |
|-------|---------|
| `SessionStart` | archivist (inject memory), relay (inject handoff), cues (clear markers) |
| `UserPromptSubmit` | oracle (confidence check), cues (trigger matching) |
| `PreToolUse` | sentinel (safety gate), warden (injection gate), oracle (pre-action check) |
| `PostToolUse` | scribe (intent capture), onlooker (event emission), warden (content scan) |
| `Stop` | ledger (cost accumulation), scribe (distill) |
| `PreCompact` | archivist (extract session memory) |
| `SessionEnd` | relay (capture handoff), ledger (session summary), cartographer (push to lore) |
| `SubagentStart` | ledger (budget enforcement) |
| `SubagentStop` | ledger (subagent cost tracking) |
| `InstructionsLoaded` | cartographer (instruction audit) |

### Updating the plugin registry

After creating a plugin, add it to the summary table in [`docs/plugins/README.md`](./plugins/README.md) and update [`docs/README.md`](./README.md) if needed.

Use the `update-readme` skill to regenerate the top-level `README.md` with the current plugin list:

```
/update-readme
```

## Modifying an existing plugin

Before modifying a plugin, read its README and any ADRs in `plugins/<name>/docs/adr/`. ADRs record why specific decisions were made and what alternatives were rejected — they prevent rediscovering already-explored dead ends.

When making a significant change:

1. Run the existing test suite if the plugin has one (check `plugins/<name>/test-cases/` for Echo-managed tests).
2. Update `CHANGELOG.md` with a summary of the change under a new version entry.
3. Update `README.md` if the behavior or configuration changed.
4. Consider whether the change warrants an ADR — if there's a meaningful tradeoff, write it down.

## Running the dashboard

The `tools/dashboard` package provides a local metrics dashboard backed by Grafana. It reads from the JSONL event logs emitted by the **onlooker** plugin.

```bash
cd tools/dashboard
bun run src/commands/up.ts      # Start the dashboard
bun run src/commands/down.ts    # Stop it
bun run src/commands/status.ts  # Check status
```

The dashboard is available at `http://localhost:3457` by default (configurable via `ONLOOKER_API_PORT`).

## Running lore

The `tools/lore` package is the shared epistemic store. Several plugins write to it (cartographer, archivist) and counsel reads from it for weekly synthesis. It stores knowledge as a scored graph with decay.

```bash
cd tools/lore
bun run bin/cli.ts --help       # See available commands
```

## Code style

- **TypeScript** for all tools and scripted logic. Biome handles linting and formatting.
- **Shell** for hooks and utility scripts. Keep hooks minimal — if logic is complex, extract it into a named script in `scripts/` and call it from the hook.
- **Markdown** for all agent prompts, commands, and documentation. Markdownlint enforces consistent style.

Biome config is at the repo root (`biome.json`). Markdownlint config is at `.markdownlint-cli2.jsonc`.
