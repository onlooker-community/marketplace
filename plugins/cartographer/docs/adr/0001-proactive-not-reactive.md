---
status: accepted
date: 2026-04-14
deciders: [onlooker-community]
---

# 1. Proactive Audit Layer: Why Cartographer Fires on InstructionsLoaded

## Status

Accepted

## Context

Every other plugin in the Onlooker ecosystem is reactive:

- Sentinel fires when a dangerous command is attempted
- Oracle fires when a prompt is ambiguous
- Scribe fires when a file is written
- Archivist fires when context is compacted
- Relay fires when a session ends

All of them respond to events that happen during a session. None of them audit the persistent state — the instruction files — that shapes every session.

CLAUDE.md files are living documents that accumulate changes over months. A team might add a rule in week 1 ("use TypeScript strict mode"), reference a file in week 3 ("see ARCHITECTURE.md for the system design"), and then delete ARCHITECTURE.md in week 6 without updating the CLAUDE.md. The stale reference just sits there, and every agent that reads that CLAUDE.md gets slightly misleading guidance.

The problem compounds: contradictions appear when one developer adds a rule that conflicts with one added by another. Orphaned plugin references accumulate when plugins are uninstalled. Dead tool references linger when the project switches from npm to bun. Nobody reviews CLAUDE.md on a regular schedule — it's a fire-and-forget document in most projects.

The reactive plugins can't catch this because none of the events they fire on relate to CLAUDE.md health. A Sentinel event fires when a command is dangerous, not when the instructions that prompted the command were contradictory. An Oracle event fires when a prompt is ambiguous, not when the CLAUDE.md made the agent's prior behavior ambiguous.

## Decision

Cartographer will fire on `InstructionsLoaded` — the event that fires when Claude Code reads and loads instruction files. This is the correct trigger because:

1. It fires at the moment when the instruction files are actually being used
2. It fires when the set of active instructions is fully known (all CLAUDE.md files in the hierarchy have been loaded)
3. It fires even for files that haven't changed, allowing Cartographer to surface prior findings consistently

`ConfigChange` is a secondary trigger: when Claude Code configuration changes (plugins installed/removed), the set of valid plugin references in instruction files may have changed. Invalidating the hash cache on ConfigChange ensures the next InstructionsLoaded runs a fresh audit.

## Consequences

### Positive

- Instruction health is checked on every session start — the audit is always current
- Issues are surfaced as `additionalContext` before the user's first message, when they can still influence the session
- ConfigChange integration means plugin installation/removal automatically triggers re-evaluation of plugin references in instruction files
- The plugin fills a genuine gap in the ecosystem: no other plugin audits the instruction layer

### Negative

- InstructionsLoaded fires frequently (every session, and potentially on CWD changes mid-session). Without throttling, this would be expensive. The hash-based throttle (ADR 0002) makes most invocations cheap
- The agent hook adds some latency to session initialization, even on the fast path. Mitigated by `async: true` — the audit runs in the background and does not block the session

### Neutral

- The plugin is deliberately read-only during hook execution — it reports issues but does not modify instruction files. Remediation is always manual, via `/cartographer:audit view` and the user's own editor

## Alternatives Considered

### Fire on SessionStart instead of InstructionsLoaded

- Pros: More predictable timing; fires once per session
- Cons: SessionStart fires before instruction files are necessarily loaded. InstructionsLoaded is the precise event when the instructions are available for analysis
- Why rejected: InstructionsLoaded is the semantically correct hook. SessionStart would require assuming instruction files are available, which may not always hold

### Run as a scheduled task (cron-style) rather than event-driven

- Pros: Decoupled from session start; could run on a timer independent of Claude Code usage
- Cons: Claude Code's plugin system doesn't support scheduled tasks without external tooling. The InstructionsLoaded event naturally provides the right cadence (once per session, when the files are known to be loaded)
- Why rejected: Event-driven is simpler and more reliable within the plugin architecture
