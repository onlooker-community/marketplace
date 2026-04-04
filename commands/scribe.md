---
name: scribe
description: Manage Scribe intent documentation — view captures, distill sessions, browse artifacts
---

# /scribe:scribe

Manage Scribe intent documentation for the current project.

## Subcommands

### `status`
Show Scribe status:
- Number of undistilled capture entries for the current session
- Output directory path and whether it exists
- Total capture count and artifact count
- Archivist integration status (found session file or not)
- Whether skip_trivial is enabled and skip_paths configured

Read config from `${CLAUDE_PLUGIN_ROOT}/config.json`.

### `distill`
Distill the current session's captures immediately. Read all undistilled capture entries for the current session, group them, optionally enrich with Archivist context, and produce documentation artifacts in the configured output_dir.

If the current session has fewer captures than `min_captures_for_stop_distill`, distill anyway (manual distillation overrides the minimum).

### `distill --session <id>`
Distill a specific past session by its session ID.

### `distill --all`
Distill all undistilled sessions. Process each session independently, producing separate change logs for each.

### `show`
List recent documentation artifacts (change logs and decision docs) with timestamps, sorted by most recent first. Show the last 10 by default.

### `show --decisions`
List all decision documents in `output_dir/decisions/` with their topics and dates.

### `show --changes`
List all change log entries in `output_dir/changes/` with dates and file counts.

### `open <filename>`
Display a specific documentation artifact by filename. Searches in both `changes/` and `decisions/` subdirectories.

### `captures`
Show raw capture entries for the current session. Useful for debugging — displays each capture entry with file path, intent, tags, and timestamp.

### `config`
Show current Scribe configuration from `${CLAUDE_PLUGIN_ROOT}/config.json`.

## Behaviour

- `distill` commands write files to the configured `output_dir`. All other commands are read-only.
- If no captures exist for the current session, say so clearly rather than showing empty output.
- The `open` command should display the full file content, not just a summary.
- If Archivist integration is enabled but no session file is found, mention it but proceed without enrichment.
