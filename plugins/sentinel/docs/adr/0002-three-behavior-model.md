---
status: accepted
date: 2026-04-03
deciders: [onlooker-community]
---

# 2. Three Behavior Model

## Status

Accepted

## Context

Sentinel needs to respond to matched dangerous commands. The simplest model is binary: block or allow. However, users consistently disable binary safety tools because they are either too aggressive (blocking operations the user actually needs) or too permissive (allowing everything to avoid the first problem).

We need a model that lets users tune Sentinel's response to match their risk tolerance without disabling it entirely.

## Decision

We will implement three distinct behaviors, configurable per risk level:

1. **Block** — Hard stop. Exit code 2. Stderr message returned to Claude explaining why and suggesting a safer alternative. The command does not execute. Used for critical-risk operations by default.

2. **Review** — Pause for human confirmation. Uses `hookSpecificOutput.permissionDecision: "ask"` to trigger Claude Code's interactive permission dialog. The user sees the risk assessment and decides whether to proceed. Used for high-risk operations by default. **In headless/CI contexts, review falls back to block** — never hang waiting for input.

3. **Log** — Allow but record. Exit code 0 with JSON `additionalContext` containing the risk assessment. The command proceeds, and an audit entry is written to the JSONL log. Used for medium-risk operations by default.

Low-risk operations (or commands not matching any pattern) use an implicit fourth behavior: **allow** — pass through silently with no overhead.

Each risk level has a default behavior, but users can override the behavior for any risk level in `config.json`, and temporarily override individual pattern behaviors per session via `/sentinel:sentinel allow` and `/sentinel:sentinel block`.

## Consequences

### Positive

- Users can tune Sentinel to their comfort level without disabling it entirely
- The review behavior leverages Claude Code's existing permission dialog — no custom UI needed
- The log behavior creates an audit trail that users can review at their own pace via `/sentinel:sentinel audit`
- Session-level overrides allow temporary exceptions without permanent config changes
- The headless fallback (review → block) prevents CI/CD jobs from hanging indefinitely

### Negative

- Three behaviors are more complex to implement and test than a binary model
- The review → block fallback in headless mode means CI environments are strictly more restrictive than interactive ones. A command that would be reviewable interactively will be blocked in CI (mitigation: this is intentional and documented — in unattended contexts, the safe default is to block rather than allow)
- Users may find the three levels confusing initially (mitigation: defaults are sensible, and `/sentinel:sentinel show` displays the current configuration clearly)

### Neutral

- The audit log grows indefinitely. Users may want log rotation eventually, but this is not a v0.1 concern

## Alternatives Considered

### Block only

- Pros: Simplest implementation, strongest safety guarantee
- Cons: Users disable the plugin entirely when it blocks something they need. A safety tool that's disabled provides no safety
- Why rejected: Historical evidence from linters, pre-commit hooks, and CI gates shows that overly aggressive tools get disabled rather than tuned

### Block / allow (binary)

- Pros: Simple two-state model
- Cons: No middle ground. Everything is either "too dangerous to run" or "fine to run". Misses the large category of commands that are "probably fine but worth noting"
- Why rejected: The log behavior captures the most valuable signal: "this happened, and here's what it was." This audit trail is often more useful than blocking, because it lets users discover patterns in their agent's behavior

### Four behaviors (block / review / warn / log)

- Pros: Even more granular control
- Cons: Warn vs log distinction is unclear to most users. In practice, both would emit a message and allow the command
- Why rejected: The distinction between "warn" and "log" is not meaningful enough to justify the additional complexity. Three levels map cleanly to the risk model (critical → block, high → review, medium → log)
