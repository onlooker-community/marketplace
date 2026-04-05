# ADR 0002: Compare Rubric Criterion Scores, Not Output Strings

Date: 2026-04-04
Status: Accepted

## Context

Echo needs to determine whether a change to an agent file improved, degraded, or had no measurable effect on output quality. To make this determination, it must compare the output of a test run against a recorded baseline.

LLM outputs are non-deterministic. The same agent, given the same task twice, will produce outputs that differ in wording, structure, and length — even when the underlying quality is identical. Any comparison method must be robust to this natural variation.

## Decision

Echo compares rubric criterion scores (floats) between the current run and the baseline, using a configurable tolerance threshold. A test is classified as degraded only if the score delta exceeds the regression threshold or a per-criterion regression exceeds its own threshold.

The comparison is implemented in `scripts/compare.py`.

## Options considered

### Option A: String similarity comparison

Compare the text of Actor outputs between runs using edit distance, cosine similarity over embeddings, or similar techniques.

Rejected. String similarity conflates semantic quality with surface form. A paraphrased but equally correct solution would show as "changed" even though quality is identical. Worse, a verbose but lower-quality output might score higher on string similarity to a verbose baseline. This approach produces noisy, misleading signals.

### Option B: Exact rubric score match

Require the rubric scores to match the baseline exactly (or within a very small epsilon, e.g., 0.01).

Rejected. Rubric scores are themselves the output of an LLM Judge. Judge outputs have natural variance even for identical Actor outputs — slight rewording, different emphasis, marginal score differences. An exact match threshold would produce constant false positives and make Echo unusable in practice.

### Option C: Score delta with configurable tolerance (chosen)

Compare overall score and per-criterion scores against the baseline. A run is degraded only if the delta exceeds the configured `regression_threshold` (default: 0.05) at the overall level, or `per_criterion_regression_threshold` (default: 0.10) on any individual criterion.

Accepted. This approach:
- Is robust to natural LLM variance (small random fluctuations within threshold are treated as neutral)
- Is sensitive to genuine regressions (a 5-point overall drop or a 10-point criterion drop is clearly meaningful)
- Is transparent — the thresholds are explicit in `config.json` and can be tuned per project
- Handles the non-determinism of both the Actor and the Judge

## Consequences

- Thresholds in `config.json` require calibration. The defaults (0.05 overall, 0.10 per-criterion) are starting points. Projects with very stable pipelines may tighten these; projects with high variance may loosen them.
- A test can show as "neutral" even after a real change, if the change is small enough to fall within the tolerance band. This is acceptable: it is better to miss a tiny regression than to produce constant false alarms that erode trust in the CI signal.
- Per-criterion regressions are detected even when the overall score is neutral. A test case where the Judge scores `error_handling` 0.15 points lower than baseline will be flagged as degraded even if `correctness` improved to compensate. This prevents masking of targeted regressions by unrelated improvements.
