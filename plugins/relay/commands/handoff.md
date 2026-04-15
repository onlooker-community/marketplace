---
name: handoff
description: View and manage Relay session handoffs — current status, recent handoff history, and configuration
---

# /relay:handoff

Manage Relay session continuity handoffs.

## Subcommands

### `status`

Show the most recent handoff for the current working directory. Display all fields in a readable format:

- Task summary and status
- Next action
- Files in flight (with state and notes)
- Blocking questions
- Critical context
- Last intent
- Captured at timestamp

If no handoff exists for the current directory, say so and explain that a handoff is generated at SessionEnd.

If the most recent task status is `complete`, note that the handoff will not be injected at the next SessionStart (completed tasks are skipped).

Read handoffs from the `storage_path` configured in `${CLAUDE_PLUGIN_ROOT}/config.json`.

### `show [--all]`

List recent handoffs for the current working directory. Without `--all`, show the last 5. With `--all`, show everything.

For each handoff show: captured_at, task summary, status, and how many files were in flight.

### `clear`

Delete the most recent handoff for the current working directory. Confirm before deleting — show the task summary and captured_at so the user knows what they're discarding.

This is useful if the handoff is stale or if the task was completed and you don't want the injection to appear.

### `config`

Display the current Relay configuration from `${CLAUDE_PLUGIN_ROOT}/config.json`:

- enabled
- storage_path
- inject_on_start
- max_handoffs_to_keep
- max_injection_words

Also show how many handoffs currently exist for the current working directory and across all directories.

## Behavior

- `status`, `show`, and `config` are read-only.
- `clear` is destructive — confirm first.
- The inject script skips handoffs where `task.status == "complete"`. Use `/relay:handoff clear` if you want to suppress a non-complete handoff.
- If Relay is disabled in config, commands still work but note that capture and injection are disabled.
