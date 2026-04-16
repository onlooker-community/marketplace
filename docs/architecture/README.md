# Architecture Decision Records

ADRs capture significant cross-cutting decisions for the Onlooker Marketplace — choices that affect multiple plugins, the plugin contract, or the overall ecosystem design.

For decisions scoped to a single plugin, see that plugin's own `docs/adr/` directory (listed below).

## Cross-cutting ADRs

None yet. When a decision affects more than one plugin or defines a pattern the whole ecosystem follows, it belongs here.

To add one, create a file named `docs/architecture/NNNN-<short-title>.md` following the format below.

### ADR format

```markdown
# NNNN. Title

## Status

Accepted | Proposed | Deprecated | Superseded by [NNNN](link)

## Context

What situation or constraint is driving this decision?

## Decision

We will...

## Consequences

### Positive
-

### Negative
-

### Alternatives considered
-
```

---

## Per-plugin ADRs

Each plugin maintains its own ADR log. Links below go directly to each plugin's decision records.

### archivist

| ADR | Title |
|-----|-------|
| [0001](../../plugins/archivist/docs/adr/0001-extraction-schema.md) | Extraction schema |

### cartographer

| ADR | Title |
|-----|-------|
| [0001](../../plugins/cartographer/docs/adr/0001-proactive-not-reactive.md) | Proactive not reactive |
| [0002](../../plugins/cartographer/docs/adr/0002-hash-throttle.md) | Hash throttle |
| [0003](../../plugins/cartographer/docs/adr/0003-llm-for-analysis.md) | LLM for analysis |

### echo

| ADR | Title |
|-----|-------|
| [0001](../../plugins/echo/docs/adr/0001-tribunal-as-evaluator.md) | Tribunal as evaluator |
| [0002](../../plugins/echo/docs/adr/0002-score-delta-not-string-compare.md) | Score delta not string compare |
| [0003](../../plugins/echo/docs/adr/0003-baseline-as-committed-artifact.md) | Baseline as committed artifact |

### ledger

| ADR | Title |
|-----|-------|
| [0001](../../plugins/ledger/docs/adr/0001-conservation-law-approach.md) | Conservation law approach |
| [0002](../../plugins/ledger/docs/adr/0002-hook-scope-decision.md) | Hook scope decision |

### relay

| ADR | Title |
|-----|-------|
| [0001](../../plugins/relay/docs/adr/0001-handoff-vs-memory.md) | Handoff vs memory |
| [0002](../../plugins/relay/docs/adr/0002-agent-at-session-end.md) | Agent at session end |

### scribe

| ADR | Title |
|-----|-------|
| [0001](../../plugins/scribe/docs/adr/0001-capture-distill-separation.md) | Capture distill separation |
| [0002](../../plugins/scribe/docs/adr/0002-intent-not-code.md) | Intent not code |
| [0003](../../plugins/scribe/docs/adr/0003-archivist-integration.md) | Archivist integration |

### sentinel

| ADR | Title |
|-----|-------|
| [0001](../../plugins/sentinel/docs/adr/0001-pattern-matching-architecture.md) | Pattern matching architecture |
| [0002](../../plugins/sentinel/docs/adr/0002-three-behavior-model.md) | Three behavior model |

### tribunal

| ADR | Title |
|-----|-------|
| [0001](../../plugins/tribunal/docs/adr/0001-hook-type-selection.md) | Hook type selection |
| [0002](../../plugins/tribunal/docs/adr/0002-command-naming-and-namespacing.md) | Command naming and namespacing |
| [0003](../../plugins/tribunal/docs/adr/0003-bootstrap-constraint.md) | Bootstrap constraint |
| [0004](../../plugins/tribunal/docs/adr/0004-rubric-per-domain.md) | Rubric per domain |
| [0005](../../plugins/tribunal/docs/adr/0005-judge-persona-panel.md) | Judge persona panel |
| [0006](../../plugins/tribunal/docs/adr/0006-meta-judge-override-thresholds.md) | Meta-judge override thresholds |
| [0007](../../plugins/tribunal/docs/adr/0007-skeptical-actor.md) | Skeptical actor |
| [0008](../../plugins/tribunal/docs/adr/0008-onlooker-integration.md) | Onlooker integration |
