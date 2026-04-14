---
status: accepted
date: 2026-04-14
deciders: [onlooker-community]
---

# 1. Handoff vs Memory: Relay's Distinct Role from Archivist

## Status

Accepted

## Context

Archivist already handles session memory. Before building Relay, the question is: does another plugin that fires on SessionStart and SessionEnd create redundancy with Archivist, or does it solve a genuinely different problem?

The YC-Bench paper (arXiv:2604.01212) establishes the answer empirically. Its core finding: agents that fail to record which clients are adversarial repeat costly mistakes after conversation history is truncated. The scratchpad — what the agent retains between turns — is the determining factor for whether work continues correctly. The paper demonstrates this in an agentic customer service context, but the principle is general: **what survives truncation determines what the next session can do**.

Archivist solves the long-horizon problem: decisions that should inform all future work in a project ("always use absolute imports here"; "the legacy auth path is deprecated"). These are reusable rules with high confidence values, extracted after a session ends.

Relay solves the immediate resumption problem: "I was in the middle of editing `src/auth/middleware.ts`, I stopped at line 47, the test I was trying to fix is still failing because of the JWT expiry logic, and I haven't touched `UserController` yet." This information has zero value three sessions from now. It has maximum value in the next 30 minutes.

The distinction maps to two different failure modes:
1. **Long-horizon failure** (Archivist's domain): repeating a dead end that was tried two weeks ago; violating a project convention that was established in a session that was compacted away
2. **Immediate resumption failure** (Relay's domain): spending the first 5-10 turns re-establishing what the developer already knew when they closed Claude Code yesterday

These are different failure modes at different time scales.

## Decision

Relay will capture a **handoff document** at SessionEnd with a different schema and different extraction principles from Archivist:

| Dimension | Archivist | Relay |
|-----------|-----------|-------|
| What it captures | Decisions, dead ends, reusable rules | Task state, next action, open blockers |
| Time horizon | All future sessions | Next session only |
| Value decay | Slow (rules stay relevant) | Fast (stale after task complete) |
| Injection format | Prose summary, filtered by confidence | Operational briefing, injected in full |
| When it's cleared | When superseded by new learning | When task status is `complete` |
| Fields | decisions, dead ends, open_questions, files | task, next_action, files_in_flight, blocking_questions, critical_context |

The schemas deliberately do not overlap. Relay has no `decisions` or `dead_ends` field. Archivist has no `next_action` or `blocking_questions` field. Users who want both can install both — they complement rather than duplicate.

## Consequences

### Positive

- Clear separation of concerns: Archivist users are not affected by Relay's installation, and vice versa
- Relay can skip injection entirely when `task.status == "complete"`, which Archivist cannot do (rules are always relevant)
- The handoff schema is optimized for operational immediacy, not archival completeness — shorter, more actionable
- The YC-Bench research validates the core insight: what the agent records at the scratchpad level determines what the next session can accomplish

### Negative

- Two plugins where one might seem sufficient. The counter-argument is that compression of both into one plugin would require a single agent to be good at both long-horizon memory extraction AND immediate task state capture — these are distinct cognitive tasks that are better separated
- Users must install and configure both if they want both capabilities

### Neutral

- Relay handoffs are ephemeral by design. They are not meant to accumulate into a knowledge base. The `max_handoffs_to_keep` config exists to bound storage, not to enable historical analysis

## Alternatives Considered

### Add a "handoff mode" to Archivist

- Pros: One plugin; shared injection infrastructure
- Cons: Confuses two different abstractions. The Archivist extractor is already well-defined around decision extraction. Adding task-state capture to the same agent would degrade both. The injection logic would need to merge two very different schemas into a coherent briefing
- Why rejected: Separation is a feature, not a limitation. The two plugins serve different users in different moments. A developer who wants long-horizon memory but not immediate handoffs should be able to install Archivist without Relay

### Use Archivist's `open_questions` as the handoff mechanism

- Pros: Re-uses existing schema and infrastructure
- Cons: `open_questions` in Archivist is filtered by priority and confidence; it is not designed to hold "I was at line 47 in this file." Archivist's injection is capped and compressed; Relay's injection must be complete (a truncated handoff is worse than no handoff). The time-to-injection delay in Archivist (extraction happens at PreCompact, not at the exact SessionEnd moment) means the handoff might miss the last 10-20 turns of work
- Why rejected: The schema mismatch is fundamental. `open_questions` is a question; a handoff is an operational state. They answer different prompts
