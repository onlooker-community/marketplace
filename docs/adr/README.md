# Architectural Decision Records

This directory contains Architectural Decision Records (ADRs) for the Tribunal Claude Code plugin.
ADRs document significant decisions made during the design and evolution of the plugin,
including the context that motivated them and the consequences that followed.

Format: [MADR](https://adr.github.io/madr/) (Markdown Architectural Decision Records)

## Index

| ID | Title | Status |
|----|-------|--------|
| [0001](0001-hook-type-selection.md) | Hook type selection for quality gate events | Accepted |
| [0002](0002-command-naming-and-namespacing.md) | Command naming to avoid slash command namespace collision | Accepted |
| [0003](0003-bootstrap-constraint.md) | Tribunal cannot validate its own initial scaffold | Accepted |
| [0004](0004-rubric-per-domain.md) | Domain-specific rubrics over a single generic rubric | Accepted |
| [0005](0005-judge-persona-panel.md) | Multi-persona judge panel over a single generic judge | Accepted |
| [0006](0006-meta-judge-override-thresholds.md) | Meta-Judge override thresholds and flag/override independence | Accepted |
| [0007](0007-skeptical-actor.md) | Actor self-challenge before submission | Accepted |

## Status legend

- **Proposed** — under discussion, not yet adopted
- **Accepted** — adopted and in effect
- **Deprecated** — no longer in effect, superseded by another ADR
- **Superseded** — replaced by a later ADR (linked)