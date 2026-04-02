# 0005 — Multi-persona judge panel over a single generic judge

Date: 2026-04-02
Status: Accepted

## Context and Problem Statement

Tribunal's initial Judge is a single generic evaluator. It has good scoring mechanics, bias-detection logic, and calibration anchors, but it evaluates every task from the same perspective on every run. This means the quality gate is only as broad as one evaluator's angle of view.

Research on agent-based evaluation panels (Jung & Na, 2026) identifies a score–coverage dissociation: scoring reliability saturates quickly with panel size (logarithmically, good reliability at N=8), while issue discovery follows a sublinear power law (b≈0.69) that never saturates — a 4-judge panel discovers 3.3× more unique issues than a single judge while producing nearly identical mean scores.

The mechanism is ensemble diversity: each agent probes the system from a different angle; diverse errors cancel out while the shared quality signal accumulates. This requires structured persona conditioning — not simple prompting — to produce the scaling properties.

The implication for Tribunal: a single generic Judge is the worst-case configuration from a discovery standpoint. It catches head issues (obvious failures) but systematically misses torso and tail issues (subtle gaps, corner cases) that require diverse evaluative perspectives to surface.

## Decision Drivers

* A single judge produces ICC of ~0.29 (poor reliability) on any individual run.
* Persona diversity is what drives issue discovery breadth, not panel size alone.
* Expert-level judges discover 1.9× more issue categories than novice judges, with the advantage in breadth rather than just score.
* Four judges is sufficient to achieve 3.3× issue discovery gain at moderate cost.
* Tribunal's current `config.json` defaults to `panel.size: 1`, which means the panel aggregation logic is doing nothing.

## Considered Options

* **Option A:** Single generic judge (current state)
* **Option B:** Multiple instances of the same judge prompt (increases reliability but not discovery — equivalent to the "repeated" ablation condition in the paper, which had SD 0.151 vs. structured diverse panels at 0.087)
* **Option C:** Multiple judges with distinct structured personas targeting different quality dimensions

## Decision Outcome

Chosen: **Option C** — a panel of four structured persona judges.

The four personas target distinct quality dimensions that a single generic judge under-weights:

| File | Persona | Primary lens |
|------|---------|--------------|
| `agents/personas/judge-security.md` | Security reviewer | Input validation, injection risks, unsafe operations, exposed secrets |
| `agents/personas/judge-maintainability.md` | Maintainability reviewer | Naming, coupling, testability, long-term readability |
| `agents/personas/judge-adversarial.md` | Adversarial expert | Failure modes, edge cases, "what would break this?" — high-skepticism probe |
| `agents/personas/judge-domain.md` | Domain expert | Configurable per project; defaults to Claude Code plugin schema for Tribunal itself |

Default `config.json` is updated to `panel.size: 4` and `panel.aggregation: "mean"`. The generic `agents/judge.md` is retained as the fallback for `panel.size: 1` runs.

### Consequences

* Good: 4-judge diverse panel discovers 3.3× more issues than single judge at similar mean score reliability.
* Good: Persona diversity is structural — different judges look at different things by design, not by chance.
* Good: `judge-domain.md` is configurable, making the panel extensible to any project's specific quality requirements.
* Bad: 4× judge invocations per Actor iteration increases cost and latency.
* Bad: Panel aggregation logic (currently `mean`) may not be the right strategy for all task types — `majority` may be better for pass/fail tasks.
* Neutral: The Meta-Judge now reviews an aggregated verdict from 4 judges rather than 1, which increases the complexity of bias detection but also gives it more signal to work with.

## Links

* Jung, H. & Na, W. (2026). Logarithmic Scores, Power-Law Discoveries: Disentangling Measurement from Coverage in Agent-Based Evaluation. arXiv:2604.00477.
* Relates to: [0004 — Domain-specific rubrics](0004-rubric-per-domain.md) (rubric diversity and judge persona diversity address the same coverage gap from different angles)
* Relates to: [0006 — Meta-Judge override thresholds](0006-meta-judge-override-thresholds.md)