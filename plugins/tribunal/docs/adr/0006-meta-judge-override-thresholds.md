# 0006 — Meta-Judge override thresholds and flag/override independence

Date: 2026-04-02
Status: Accepted

## Context and Problem Statement

The Meta-Judge reviews Judge verdicts for bias and reasoning quality. Two design questions needed resolving:

1. **When should the Meta-Judge override the Judge's score?** Without a threshold, the Meta-Judge either rubber-stamps every verdict (useless) or re-litigates every judgment call (undermines the Judge's authority and adds noise).

2. **Should detecting a bias always trigger a score override?** If yes, the Meta-Judge becomes a second Judge rather than a quality assurance layer. If no, the pipeline needs to distinguish between flagging (observability) and overriding (action).

This was observed in practice: during a Tribunal-on-Tribunal run, the Meta-Judge flagged `rubric_misalignment` and `weak_reasoning` (the Judge used generic criteria instead of the plugin-specific rubric) but correctly determined that the substantive findings were valid and the adjusted score still passed the threshold. Flagging without overriding was the right call — the gate outcome was unchanged.

## Decision Drivers

- Overriding too aggressively introduces Meta-Judge noise into every verdict, making scores unpredictable.
- Never overriding makes the Meta-Judge a pure logging layer with no gate authority.
- Bias detection (flagging) and score adjustment (overriding) serve different purposes: flagging is for observability and pipeline analysis; overriding is for gate integrity.
- The threshold for override should be tied to gate outcome: only adjust scores when the bias materially changes whether the output passes or fails.

## Considered Options

- **Option A:** Override any time a bias is detected
- **Option B:** Override only when bias flips the pass/fail outcome
- **Option C:** Tiered thresholds — override required above a delta, recommended in a middle band, flag-only below a minimum delta

## Decision Outcome

Chosen: **Option C** — tiered thresholds with flagging and overriding as independent actions.

| Situation | Action |
|-----------|--------|
| Bias changes pass/fail outcome | Override required |
| Score delta ≥ 0.15 due to bias | Override required |
| Score delta 0.05–0.14 due to bias | Override recommended |
| Score delta < 0.05 | Flag bias, keep original score |

**Flagging and overriding are independent.** A non-empty `biasFlags` array does NOT require `approved: false`. `approved: false` is set only when the override changes the gate outcome or represents a significant evaluation failure.

This means a verdict can be:

- Approved with no flags (clean verdict)
- Approved with flags (bias detected but outcome unchanged)
- Not approved with flags (bias materially affects outcome)
- Not approved without flags (structural failure — e.g., Judge ignored the rubric)

### Consequences

- Good: The Meta-Judge acts as quality assurance, not a second Judge. It intervenes when it matters and observes when it doesn't.
- Good: `biasFlags` provides a signal for pipeline analysis independent of gate decisions — patterns in flagging over time indicate systemic Judge issues.
- Good: The 0.15 hard threshold prevents the Meta-Judge from making micro-adjustments that add noise without changing outcomes.
- Bad: The thresholds (0.15, 0.05) are not empirically calibrated — they are reasonable starting points but may need tuning based on observed Meta-Judge behavior.
- Neutral: The Meta-Judge must still estimate a score delta, which requires it to reason about what the score "should" be — this is the hardest part of the Meta-Judge's job and the most likely source of error.

## Links

- Demonstrated in practice: Tribunal-on-Tribunal run scoring `rubrics/claude-plugin.md`, where the Meta-Judge flagged `rubric_misalignment` and `weak_reasoning` but kept `approved: true` and adjusted score from 0.87 → 0.85 (gate outcome unchanged).
- Relates to: [0005 — Judge persona panel](0005-judge-persona-panel.md) (with a 4-judge panel, the Meta-Judge reviews an aggregated verdict which changes the bias detection context)
