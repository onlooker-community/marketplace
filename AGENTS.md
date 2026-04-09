# AGENTS.md

This file provides guidance to Claude Code when working with this repository.

## Repository Overview

- **What:** Marketplace of Claude Code plugins for the Onlooker ecosystem (monorepo)
- **Purpose**: Collection of reusable plugins that power local agent observability
- **License**: Blue Oak Model License 1.0.0
- **Current plugins**:
  - archivist (structured session memory across context truncation)
  - echo (prompt regression testing for agent files)
  - onlooker (observability spine for your agents)
  - oracle (confidence calibration before action)
  - scribe (intent documentation for agent activity)
  - sentinel (pre-flight safety gate for destructive operations)
  - tribunal (multi-agent orchestration with quality gates)
  - warden (indirect prompt injection detection on retrieved content)

## Quick Start

```bash
# Install dependencies
bun install

# Format code
bun run fix:format

# Install marketplace locally
/plugin marketplace add /path/to/claude-plugins

# Install a plugin
/plugin install <plugin-name>@onlooker-marketplace
```

## Architecture

### Plugin Structure

Every plugin follows this pattern:

```text
plugins/<plugin-name>/
├── .claude-plugin/plugin.json   # REQUIRED: Plugin metadata
├── skills/<name>/SKILL.md       # Auto-invoked capabilities
├── commands/<name>.md           # Slash commands (user-triggered)
├── agents/<name>.md             # Specialized subagents
├── hooks/hooks.json             # Lifecycle event handlers
└── README.md
```

Plugins can include **any combination** of components, mix and match as needed.

### Key Concepts

#### Progressive Disclosure (CRITICAL)

Keep `SKILL.md` files under 500 lines. Move detailed content to `references/` subdirectory.

```text
skills/<skill-name>/
├── SKILL.md              # Core patterns only (< 500 lines)
└── references/           # Detailed docs (loaded on-demand)
    ├── api_reference.md
    └── common_patterns.md
```

## Development Workflow

### Commands

```bash
bun run fix:format # format with biome
bun run lint  # lint with biome
```

### Git Commits

**Format (enforced):** `<type>[scope]: <description>`

```bash
git commit -m "feat(tribunal): add tribunal plugin"
git commit -m "fix: resolve hook path issue"
git commit -m "docs: update README"
```

Types: `feat`, `fix`, `chore`, `docs`, `style`, `refactor`

**Releases:** Automated by release-please (don't manually edit CHANGELOG.md or version numbers).

### Git Worktrees

Used for parallel development:

```bash
git worktree add .worktrees/<branch> -b <branch>
cd .worktrees/<branch>
```

## Code Style

### Naming Conventions

| Entity               | Convention           | Example          |
| -------------------- | -------------------- | ---------------- |
| Plugin directories   | kebab-case           | `example-plugin` |
| Skill files          | SKILL.md (uppercase) | `SKILL.md`       |
| Command/agent files  | kebab-case.md        | `analyze.md`     |

## Critical Gotchas

### 1. Progressive Disclosure is Mandatory

**Problem:** Large skills (>500 lines) overwhelm Claude's context window.
**Solution:** Keep SKILL.md concise, move details to `references/`.


### 2. Hook Paths are Relative to Plugin Root

**Problem:** "Most common issue according to docs" - hooks fail silently.
**Solution:** Paths in `hooks.json` are relative to plugin root. Test manually:

```bash
bash plugins/<plugin>/scripts/<script>.sh
```

## Common Issues

**Hook not executing:**

```bash
ls -la plugins/<plugin>/scripts/<script>.sh  # Check path
chmod +x plugins/<plugin>/scripts/<script>.sh  # Add permission
```

**Skill not activating:**
Check YAML frontmatter - description must be specific and action-oriented.

**Commit rejected:**
Use format: `<type>: <description>` (conventional commits enforced).
