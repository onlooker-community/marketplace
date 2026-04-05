---
status: accepted
date: 2026-04-04
deciders: [onlooker-community]
---

# 1. Capture-Distill Separation

## Status

Accepted

## Context

Scribe needs to document agent intent during execution. The question is when to produce the final documentation artifacts. Three timing strategies exist: on every file write, on demand only, or a two-phase approach where lightweight capture happens immediately and synthesis happens later.

The key constraint is that intent only exists while the agent has its reasoning in context. Once the session ends or context is truncated, the reasoning behind a change is unrecoverable. However, producing polished documentation on every file write would be slow (blocking the agent for 10-30 seconds per write), noisy (a function built across three Edit calls would produce three separate docs), and fragmented.

## Decision

We will use a two-phase architecture:

1. **Capture phase** (`PostToolUse` on Write|Edit) — Lightweight, fast (≤3 seconds target, ≤20 second timeout). Records file path, change type, and a brief intent snapshot. Appends to a JSONL capture file. Runs while the agent still has context.

2. **Distill phase** (`Stop`, `SessionEnd`, or manual `/scribe:distill`) — Reads all captures for the session, groups them into logical change sets, optionally enriches with Archivist context, and produces polished Markdown documentation artifacts.

## Consequences

### Positive

- Intent is captured at the only moment it exists — during agent execution with reasoning in context
- Distillation produces coherent documentation by seeing all changes together, not one at a time
- The capture hook is fast enough to not noticeably slow down file operations
- Manual distillation gives users control over when docs are generated

### Negative

- Captures must be idempotent — the same session distilled twice must not produce duplicate docs (mitigation: sessions are marked as distilled after processing)
- If the agent crashes before Stop/SessionEnd, captures exist but may never be distilled (mitigation: `/scribe:distill --all` picks up orphaned sessions)
- Two phases means two prompt designs to maintain — the capture prompt (brevity-optimized) and the distiller prompt (quality-optimized)

### Neutral

- Capture entries accumulate in JSONL files until distilled. Storage is minimal — each entry is a few hundred bytes

## Alternatives Considered

### Distill on every write

- Pros: Real-time documentation, no batch processing needed
- Cons: 10-30 seconds added to every Write/Edit. A function written across three edits produces three fragmented docs instead of one coherent entry. Blocks the agent.
- Why rejected: Speed is non-negotiable for PostToolUse hooks. Fragmented output defeats the purpose of readable documentation.

### Distill only on demand

- Pros: Simplest implementation, user controls when docs are generated
- Cons: Intent evaporates once the session ends. If the user forgets to run `/scribe:distill`, the reasoning behind changes is lost forever.
- Why rejected: The whole point of Scribe is capturing intent at the moment it exists. "Remember to document" is the problem Scribe solves.
