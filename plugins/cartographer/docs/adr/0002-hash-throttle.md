---
status: accepted
date: 2026-04-14
deciders: [onlooker-community]
---

# 2. Hash-Based Throttle for Audit Frequency

## Status

Accepted

## Context

InstructionsLoaded fires frequently — at minimum once per session, and potentially more often if the working directory changes mid-session. Running the full audit agent on every invocation would be prohibitively expensive in both time and API cost.

The audit only needs to run when something relevant has changed:

1. An instruction file was added, removed, or modified
2. The plugin configuration changed (which could affect plugin reference validity)
3. The last audit is older than the TTL (to catch environmental changes like files being deleted)

Without a throttle, a developer who opens five sessions in a day would run five full audits, most of which would produce identical results.

## Decision

We will use a content-hash-based throttle with a TTL fallback.

**Hash computation:** The auditor agent computes a hash of the current instruction files by:

1. Collecting all instruction file paths (CLAUDE.md hierarchy, .claude/rules/*, .claude/agents/*)
2. Reading their content
3. Concatenating `path + content` for all files in sorted order
4. Deriving a change-detection string (content length + prefix sampling — a fast approximation, not a cryptographic hash)

**Throttle logic:**

- If the computed hash matches the stored hash AND the last audit was within `audit_ttl_hours`: exit immediately (no analysis, no API call)
- If the hash differs OR the audit is older than TTL: run the full audit, update the stored hash

**TTL purpose:** Catches changes that aren't reflected in file content — a file referenced in CLAUDE.md might be deleted without the CLAUDE.md itself changing. The TTL ensures at least daily re-evaluation even for stable instruction files.

**ConfigChange invalidation:** The `config-change.sh` hook clears the stored hash when Claude Code configuration changes. This ensures the next InstructionsLoaded runs a fresh audit without waiting for the TTL to expire.

**State persistence:** The hash and last-audit timestamp are stored in `~/.claude/cartographer/state.json`. This file is read on every InstructionsLoaded invocation by both the command hook (to inject prior findings) and the agent hook (to check the throttle).

## Consequences

### Positive

- The vast majority of InstructionsLoaded invocations exit in under 1 second (read one JSON file, compute approximate hash, compare, exit)
- API cost is proportional to the frequency of instruction file changes, not session frequency
- ConfigChange invalidation ensures timely re-auditing when the environment changes

### Negative

- The hash is an approximation (not a cryptographic hash). A sufficiently adversarial file change could theoretically produce the same hash. In practice, any real change to an instruction file will produce a different hash by this method
- The state file contains only the most recent audit hash. If a user switches between multiple projects frequently, the state may be for the wrong cwd, causing unnecessary re-audits. The agent checks cwd in state before trusting the hash

### Neutral

- The TTL is configurable (`audit_ttl_hours`, default 24). Users who modify instruction files frequently can lower it; users who rarely change them can raise it
- A hash miss is recoverable (runs the full audit) while a hash false positive (skipping a needed audit) is bounded in damage by the TTL

## Alternatives Considered

### File modification time instead of content hash

- Pros: Faster to compute (stat call vs read + hash); doesn't require reading file content
- Cons: mtime can change without content changing (touch, file system events, backup tools). Would cause unnecessary re-audits
- Why rejected: Content-based change detection is more accurate. The files are small enough that reading them is not a performance concern

### No throttle — always run the full audit

- Pros: Always up to date
- Cons: Every session incurs an API call and 5-30 seconds of analysis time. Unacceptable for frequent users
- Why rejected: User experience requires that session start be fast. The throttle is essential
