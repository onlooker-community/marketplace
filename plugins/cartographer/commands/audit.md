---
name: audit
description: View instruction health audit results, trigger a fresh audit, and manage Cartographer configuration
---

# /cartographer:audit

Audit CLAUDE.md and `.claude/rules/` files for contradictions, stale references, orphaned plugin mentions, and dead rules.

## Subcommands

### `view`

Show the most recent audit for the current working directory.

Display:
- Health score (0.0–1.0) with a visual indicator (✓ healthy / ⚠ issues / ✗ critical)
- Issue count by severity (high / medium / low)
- Audit timestamp and files checked
- Full issue list, grouped by severity, each showing:
  - ID, category, description
  - Files affected
  - Evidence (quoted text from the instruction file)
  - Suggestion for remediation

If no audit exists for the current directory, say so and suggest running `/cartographer:audit run`.

Read audit data from `~/.claude/cartographer/state.json` (for the summary) and the referenced audit file for full detail.

### `run`

Force a fresh audit of the current working directory's instruction files immediately, regardless of the TTL or hash state.

Invoke the `cartographer-auditor` agent synchronously. After completion, display the results in the same format as `view`.

### `history [--n N]`

Show the last N audits (default: 10) for the current working directory, ordered newest-first.

For each audit show: timestamp, health score, issue counts, and whether it was triggered by a file change or forced manually.

List audit files from `~/.claude/cartographer/audits/` matching the current cwd slug.

### `issues [--severity high|medium|low] [--category <category>]`

List all active issues from the most recent audit, optionally filtered.

Categories: `contradiction`, `stale_reference`, `orphaned_plugin`, `dead_tool`, `duplicate`, `hierarchy_conflict`

### `config`

Display the current Cartographer configuration from `${CLAUDE_PLUGIN_ROOT}/config.json`:
- enabled
- storage_path
- audit_ttl_hours
- min_severity_to_inject
- max_issues_to_inject
- Which checks are enabled

Also show: last audit timestamp, current health score, number of stored audits.

## Behavior

- `view`, `history`, `issues`, and `config` are read-only.
- `run` triggers a new audit — it always refreshes, ignoring the TTL.
- The health score is `1.0 - (high * 0.15 + medium * 0.05 + low * 0.01)`, clamped to [0.0, 1.0].
- Issues are only injected at session start if their severity meets the `min_severity_to_inject` threshold.
