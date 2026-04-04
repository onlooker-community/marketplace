# ADR 0003: Store Baselines as Committed JSON Files in Version Control

Date: 2026-04-04
Status: Accepted

## Context

Echo's regression testing depends on baseline records: the before-state of an agent's performance that new runs are compared against. These baselines must be:

1. Persistent — they must survive machine changes, re-installs, and team handoffs.
2. Visible — changes to baselines must be reviewable. When an engineer re-records a baseline after a prompt change, that should be visible in a PR.
3. Accessible — any team member with the repo should be able to run regression tests immediately, without connecting to external state.

## Decision

Baselines are stored as JSON files in `baselines/` within the plugin directory and committed to version control alongside the test cases and agent files. The `baselines/` directory must NOT be gitignored.

Run logs (`~/.claude/echo/runs/`) are local only and are never committed.

## Options considered

### Option A: Local SQLite database

Store baselines in a SQLite file (e.g., `~/.claude/echo/baselines.db`).

Rejected. A local database is not visible in PRs, is not portable across machines, and cannot be reviewed in code review. It also introduces a migration surface — schema changes require database migrations. For data of this simplicity and volume, a database adds complexity with no benefit.

### Option B: Remote database or API

Store baselines in a hosted service — a database, an object store, or a CI-specific API.

Rejected. This creates an external dependency with availability, authentication, and latency concerns. It makes Echo harder to use in offline or isolated environments. It also violates the principle that the plugin should be self-contained and installable anywhere.

### Option C: Committed JSON files in version control (chosen)

Store baselines as plain JSON files in `baselines/`, committed to the same repository as the agent files and test cases.

Accepted. This approach:
- Makes baseline changes visible in PR diffs. When a baseline is re-recorded after a prompt change, the diff shows the before/after scores directly in the review interface.
- Requires no external infrastructure. The repo is the database.
- Is portable. Any engineer who clones the repo can run regression tests immediately.
- Enables blame and log tracking. `git log baselines/judge-bias-detection-001.json` shows the full history of that agent's regression baseline.
- Keeps the data close to the code it describes. The baseline for `tribunal/agents/judge.md` lives in the same repo as `judge.md`.

## Consequences

- Baselines grow the repo's file count over time as test cases are added. This is acceptable — JSON files are small and the growth is linear.
- Teams must remember to commit updated baselines when re-recording. This is the intended workflow: re-record, verify the scores look correct, commit the updated baseline alongside the agent file change in the same PR.
- The `baselines/` directory must not be added to `.gitignore`. If a project's `.gitignore` has a pattern that matches `baselines/` or `*.json`, it must be explicitly negated.
- Run logs remain local. Only the deliberate baseline snapshots are committed. The volume of run log data is unbounded and not meaningful for historical review.
