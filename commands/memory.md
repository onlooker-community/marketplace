---
name: memory
description: View, manage, and inspect Archivist session memory extracts
---

# /archivist:memory

Manage Archivist session memory for the current working directory.

## Subcommands

### `show`
Display the most recent session extract for the current working directory in a readable format. Show all four categories (decisions, files, dead_ends, open_questions) with their details. Format for human readability — use headers, bullets, and confidence/priority labels.

### `show --all`
List all session extracts for the current working directory with timestamps, session IDs, and a one-line summary (number of decisions, dead ends, open questions). Sort by most recent first.

### `show --session <id>`
Display a specific session extract by its session ID. Same format as `show`.

### `forget --session <id>`
Delete a specific session extract by its session ID. Confirm the deletion by displaying the session timestamp and cwd before removing. Print confirmation after deletion.

### `forget --cwd`
Delete all session extracts for the current working directory. Show the count of sessions that will be deleted and confirm before removing. Print confirmation after deletion.

### `status`
Show Archivist configuration and status:
- Storage path and whether it exists
- Number of session extracts for current cwd
- Total session extracts across all cwds
- Whether inject_on_start is enabled
- Whether extract_on_compact is enabled
- Onlooker connection status (enabled/disabled, endpoint if enabled)

## Behaviour

- All commands that reference "current working directory" should match sessions from the cwd or any parent directory, consistent with how injection works.
- The `show` commands are read-only and safe to run at any time.
- The `forget` commands are destructive — always confirm what will be deleted before acting.
- If no session extracts exist, say so clearly rather than showing empty output.
