---
status: accepted
date: 2026-04-03
deciders: [onlooker-community]
---

# 1. Four-Category Extraction Schema

## Status

Accepted

## Context

Archivist needs a structured schema for extracting session memory that survives context truncation. The design is informed by YC-Bench (arXiv:2604.01212), which found that scratchpad usage was the strongest predictor of long-horizon agent success. The paper's experimental design instructs rule-form scratchpads; we interpret this as evidence that structured, reusable rules outperform one-off observations — though the paper evaluates scratchpad presence broadly and this sub-finding is our inference rather than an explicitly reported result.

The key constraint is that extraction happens under time pressure (PreCompact), the output must be machine-readable for injection, and the schema must remain stable since downstream consumers (Onlooker events, `/archivist:memory` display) depend on it.

## Decision

We will use a four-category extraction schema with a `schema_version` field:

```json
{
  "schema_version": "1",
  "decisions": [...],
  "files": [...],
  "dead_ends": [...],
  "open_questions": [...]
}
```

1. **decisions** — Reusable rules derived during the session. Each has a `rule`, `rationale`, and `confidence` (high/medium/low). These encode learned project conventions that future sessions can follow without re-deriving.

2. **files** — Paths modified with `change` description and `reason`. The diff is in git; what matters here is the *intent* behind the modification, which is not recoverable from git alone.

3. **dead_ends** — Approaches tried that failed, with `approach` and `why_failed`. These prevent the next session from repeating expensive failures. The extraction prompt explicitly instructs the LLM to populate this category by asking: "What did you try that did not work, and why?" — a direct question that creates a forcing function for surfacing failed approaches rather than letting them be silently omitted.

4. **open_questions** — Unresolved items with `question`, `context`, and `priority` (high/medium/low). These enable session continuity by defining what the next session should focus on.

## Consequences

### Positive

- Dead ends are explicitly captured, preventing the most expensive class of retry (approaches that were already tried and failed)
- Decisions as reusable rules align with the YC-Bench finding about structured scratchpads
- Open questions with priority enable intelligent injection — the injector can select the most important items rather than dumping everything
- Files capture rationale separately from diffs, preserving intent that git alone cannot
- The `schema_version` field allows consumers to detect and handle schema migrations without breaking on future changes

### Negative

- Four categories may not cover all session artifacts — some information may not fit cleanly (mitigation: the categories are broad enough to accommodate most cases; truly novel categories can be added in a future schema version, identified by the `schema_version` field)
- Schema stability creates upgrade pressure — changing the schema requires migration of existing session files (mitigation: the `schema_version` field in every output file lets consumers route to version-specific parsing logic without a flag day)
- Extraction failure modes introduce degraded recall risk: if the LLM mis-categorizes items, drops content under time pressure, or produces partial JSON, the session memory is silently incomplete. Mitigations: (a) the extraction prompt requires the LLM to emit all four top-level keys even if empty arrays, so partial output is structurally detectable; (b) Archivist validates the response against the schema before persisting and logs a warning on validation failure; (c) if validation fails the raw LLM output is preserved as a fallback so the session is not lost entirely.

### Neutral

- The schema is JSON, which is straightforward to parse but verbose compared to alternatives like YAML

## Alternatives Considered

### Flat key-value scratchpad

- Pros: Simple, flexible, no schema to maintain
- Cons: No structure means the injector cannot prioritise; YC-Bench specifically found that *structured* rules outperform unstructured notes
- Why rejected: Defeats the core insight that structure is what makes scratchpads effective

### Two categories (decisions + open_questions only)

- Pros: Simpler schema with fewer fields; extraction prompt is shorter and less likely to produce partial output under time pressure; easier to migrate
- Cons: Loses `files` (intent behind modifications is unrecoverable from git alone) and `dead_ends` (the highest-value category for preventing expensive retries); the two retained categories serve continuity but not failure-prevention
- Why rejected: `dead_ends` is the highest-value category for preventing expensive repeated failures. Dropping it saves schema complexity at too high a cost to session recall quality.

### Three categories (decisions + dead_ends + open_questions, no files)

- Pros: Removes the most verbose category (`files`) while retaining all three semantic categories; reduces extraction volume under time pressure
- Cons: Loses per-file intent capture; git diffs show *what* changed but not *why*, and that rationale is unrecoverable after the session ends
- Why rejected: The intent-behind-changes signal is unique to the session and cannot be reconstructed later; the verbosity cost of `files` is bounded by the number of modified files per session.

### Free-form prose summary

- Pros: No schema constraints, natural language is flexible
- Cons: Cannot be selectively injected, filtered by confidence, or consumed by Onlooker as structured events
- Why rejected: Structured data is essential for both intelligent injection and downstream analytics
