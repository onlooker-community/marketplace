---
status: accepted
date: 2026-04-03
deciders: [onlooker-community]
---

# 1. Four-Category Extraction Schema

## Status

Accepted

## Context

Archivist needs a structured schema for extracting session memory that survives context truncation. The design is informed by YC-Bench (arXiv:2604.01212), which found that scratchpad usage — specifically structured, reusable rules rather than one-off observations — was the strongest predictor of long-horizon agent success.

The key constraint is that extraction happens under time pressure (PreCompact), the output must be machine-readable for injection, and the schema must remain stable since downstream consumers (Onlooker events, `/archivist:memory` display) depend on it.

## Decision

We will use a four-category extraction schema:

1. **decisions** — Reusable rules derived during the session. Each has a `rule`, `rationale`, and `confidence` (high/medium/low). These encode learned project conventions that future sessions can follow without re-deriving.

2. **files** — Paths modified with `change` description and `reason`. The diff is in git; what matters here is the *intent* behind the modification, which is not recoverable from git alone.

3. **dead_ends** — Approaches tried that failed, with `approach` and `why_failed`. These prevent the next session from repeating expensive failures.

4. **open_questions** — Unresolved items with `question`, `context`, and `priority` (high/medium/low). These enable session continuity by defining what the next session should focus on.

## Consequences

### Positive

- Dead ends are explicitly captured, preventing the most expensive class of retry (approaches that were already tried and failed)
- Decisions as reusable rules align with the YC-Bench finding about structured scratchpads
- Open questions with priority enable intelligent injection — the injector can select the most important items rather than dumping everything
- Files capture rationale separately from diffs, preserving intent that git alone cannot

### Negative

- Four categories may not cover all session artifacts — some information may not fit cleanly (mitigation: the categories are broad enough to accommodate most cases; truly novel categories can be added in a future schema version)
- Schema stability creates upgrade pressure — changing the schema requires migration of existing session files (mitigation: start with a version field in the schema so consumers can handle multiple versions)

### Neutral

- The schema is JSON, which is straightforward to parse but verbose compared to alternatives like YAML

## Alternatives Considered

### Flat key-value scratchpad

- Pros: Simple, flexible, no schema to maintain
- Cons: No structure means the injector cannot prioritise; YC-Bench specifically found that *structured* rules outperform unstructured notes
- Why rejected: Defeats the core insight that structure is what makes scratchpads effective

### Two categories (rules + context)

- Pros: Simpler schema, fewer fields to extract
- Cons: Loses the distinction between dead ends (prevent retries) and open questions (enable continuity), which serve fundamentally different purposes at injection time
- Why rejected: Dead ends and open questions have different injection priorities and different value propositions; collapsing them loses critical information

### Free-form prose summary

- Pros: No schema constraints, natural language is flexible
- Cons: Cannot be selectively injected, filtered by confidence, or consumed by Onlooker as structured events
- Why rejected: Structured data is essential for both intelligent injection and downstream analytics
