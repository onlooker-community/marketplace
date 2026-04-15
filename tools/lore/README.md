# Lore (Knowledge Gravity Engine)

Local SQLite-backed epistemic store for the Onlooker ecosystem: typed knowledge objects (OIDA-aligned classes), class-specific decay, rising urgency for unresolved **QUESTION**s, and signed **CONTRADICTS** edges with score suppression.

## Install

From this monorepo (dev):

```bash
bun install
# Run via workspace
bun tools/lore/bin/cli.ts doctor
```

Published (when available):

```bash
bunx @onlooker-community/lore doctor
```

Override the CLI command for plugin hooks:

```bash
export LORE_CLI="bun /path/to/marketplace/tools/lore/bin/cli.ts"
```

## Data locations

| Path | Purpose |
|------|---------|
| `~/.claude/lore/lore.sqlite` | SQLite database |
| `~/.claude/lore/config.json` | Optional decay / weight tuning |

## CLI

| Command | Description |
|---------|-------------|
| `lore ingest --format archivist-session --file <path>` | Upsert KOs from an Archivist session JSON |
| `lore ingest --format scribe-session --file <path>` | Upsert from `{ session_id, cwd, captures[] }` |
| `lore sync-cartographer --file <audit.json>` | Create hypothesis objects + **CONTRADICTS** edges from Cartographer contradiction issues |
| `lore query --cwd <path> [--limit N] [--json]` | Ranked knowledge for cwd (path-prefix match) |
| `lore context-for-inject --cwd <path> [--max-words N]` | Plain-text block for SessionStart injection |
| `lore export-for-brief --cwd <path> [--since ISO]` | JSON bundle for Counsel |
| `lore edge add --from <id> --to <id> [--weight] [--source]` | Manual contradiction edge |
| `lore doctor` | DB path, schema version, row counts |

Environment: **`LORE_DB_PATH`** overrides the SQLite file path.

## Integrations

- **Archivist** — ingests after each session extract (`lore_enabled` in `plugins/archivist/config.json`); optional `lore_ranking` merges Lore context into SessionStart injection.
- **Scribe** — ingests on distill (`lore_enabled` in Scribe config).
- **Counsel** — `gather.sh` attaches `sources.lore` when `lore.enabled` is true.
- **Relay** — optional `inject_lore` + `lore_max_words` in Relay config.
- **Cartographer** — `SessionEnd` hook runs `cartographer-lore-sync.sh` to push contradictions into Lore.

## Tests

```bash
cd tools/lore && bun test
```
