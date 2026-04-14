# Repository layout

## Top level

```text
marketplace/
├── plugins/           # One directory per Claude Code plugin
├── tools/             # Supporting packages (npm workspaces)
├── docs/              # This MkDocs project (mkdocs.yml + docs/)
├── AGENTS.md          # Agent-oriented repo guide (kept in sync with this site where useful)
├── README.md          # Overview and consumer-oriented install snippets
└── package.json       # Root workspace and scripts (Biome, cspell, etc.)
```

The root `package.json` defines **npm workspaces** for `plugins/*` and `tools/*`. Tooling for the repo itself (formatting, spelling, commit hooks) runs from the root with **Bun** as described in `CLAUDE.md`.

## Plugin directory

Every plugin follows the same high-level shape. Individual plugins omit folders they do not need.

```text
plugins/<plugin-name>/
├── .claude-plugin/
│   └── plugin.json       # Required: plugin id, version, metadata for the marketplace
├── skills/<name>/
│   ├── SKILL.md          # Auto-invoked capability (keep lean; see below)
│   └── references/       # Optional: deeper material loaded on demand
├── commands/<name>.md    # Slash commands (user-triggered)
├── agents/<name>.md      # Subagent definitions
├── hooks/
│   └── hooks.json        # Lifecycle hooks (paths are relative to plugin root)
├── scripts/              # Optional: shell helpers invoked from hooks
└── README.md             # Human-oriented description of the plugin
```

### Progressive disclosure (skills)

Large `SKILL.md` files hurt model context. **Target:** keep each `SKILL.md` under roughly **500 lines** and move long reference material into `skills/<name>/references/` so it can be loaded only when needed.

### Hooks and paths

Paths declared in `hooks/hooks.json` are **relative to the plugin root**, not the repository root. Silent hook failures are often a path or executable bit issue; see [Development workflow](development.md#hooks-and-scripts) for quick checks.

## Tools workspace

Packages under `tools/` (for example `@onlooker-community/dashboard`) ship as normal npm packages alongside plugins. They are documented in their own `README.md` files and are not required to mirror the plugin layout above.
