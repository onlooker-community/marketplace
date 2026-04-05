---
status: accepted
date: 2026-04-04
deciders: [onlooker-community]
---

# 3. Archivist Integration

## Status

Accepted

## Context

Archivist already extracts structured `decisions` and `dead_ends` from agent sessions. These are exactly the kind of data Scribe needs during distillation to produce richer documentation — particularly the "approaches tried and abandoned" sections that developers find most valuable.

The question is whether Scribe should extract this data independently, require Archivist as a dependency, or optionally read Archivist's output when available.

## Decision

Scribe optionally reads Archivist session logs during distillation. When `archivist_integration` is enabled in config (default: true) and an Archivist session file exists for the current session, Scribe reads its `decisions` and `dead_ends` arrays to enrich the distilled documentation.

Scribe does not depend on Archivist. If Archivist is not installed or has no session file for the current session, Scribe proceeds without enrichment. The documentation is less rich but still complete.

## Consequences

### Positive

- Avoids duplicating Archivist's extraction logic — one plugin extracts, both consume
- Scribe documentation is richer when Archivist is present, providing a natural incentive to install both
- Standalone value is preserved — Scribe works without Archivist installed

### Negative

- Archivist's session file schema (`decisions`, `dead_ends` arrays with their field names) becomes a soft contract between the two plugins. Breaking changes to Archivist's schema should consider Scribe's read path (mitigation: Scribe reads defensively with `.get()` and missing-key fallbacks)
- Users may see different documentation quality depending on whether Archivist is installed, which could be confusing (mitigation: `/scribe:scribe status` shows whether Archivist context was found)

### Neutral

- The integration is read-only from Scribe's perspective — Scribe never writes to Archivist's storage

## Alternatives Considered

### Scribe extracts its own decisions independently

- Pros: No dependency on another plugin's schema, fully self-contained
- Cons: Duplicates extraction work already done by Archivist. Two plugins extracting decisions from the same session will produce inconsistent results. Additional API cost for redundant LLM calls.
- Why rejected: Archivist already does this well. Duplicating it adds cost and inconsistency.

### Scribe requires Archivist as a hard dependency

- Pros: Guarantees enriched documentation, simpler code (no fallback paths)
- Cons: Breaks standalone value — users who want intent documentation shouldn't be forced to install session memory. Plugin dependencies create installation friction.
- Why rejected: Each plugin should provide standalone value. Hard dependencies violate this principle.
