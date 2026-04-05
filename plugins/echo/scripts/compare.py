"""
Echo comparison engine.

Compares a test run result against its recorded baseline and classifies
the outcome as improved, degraded, or neutral.
"""

from typing import Optional


def compare(
    current: dict,
    baseline: dict,
    config: dict,
    expected_characteristics: Optional[dict] = None,
) -> dict:
    """
    Compare a current test result against a baseline.

    Parameters
    ----------
    current : dict
        The result from the current Tribunal run. Expected keys:
          - final_score (float)
          - iterations (int)
          - bias_flags (list[str])
          - rubric_scores (dict[str, float])
    baseline : dict
        The recorded baseline loaded from baselines/<test-id>.json.
        Expected structure mirrors the baseline schema.
    config : dict
        Echo config.json contents. Used for threshold values.
    expected_characteristics : dict, optional
        The test case's expected_characteristics block, used for
        forbidden_bias_flags checks.

    Returns
    -------
    dict with keys:
        outcome        : "improved" | "degraded" | "neutral"
        delta          : float — overall score delta (current - baseline)
        regressions    : list[str] — criterion names that regressed
        improvements   : list[str] — criterion names that improved
        flags          : list[str] — non-fatal warnings (e.g., iteration increase)
    """
    regression_threshold = config.get("regression_threshold", 0.05)
    improvement_threshold = config.get("improvement_threshold", 0.05)
    per_criterion_threshold = config.get("per_criterion_regression_threshold", 0.10)

    baseline_result = baseline.get("result", {})
    baseline_score = baseline_result.get("final_score", 0.0)
    current_score = current.get("final_score", 0.0)

    overall_delta = current_score - baseline_score

    # Per-criterion comparison
    baseline_rubric = baseline.get("rubric_scores", {})
    current_rubric = current.get("rubric_scores", {})

    regressions = []
    improvements = []

    all_criteria = set(baseline_rubric.keys()) | set(current_rubric.keys())
    for criterion in sorted(all_criteria):
        b_score = baseline_rubric.get(criterion)
        c_score = current_rubric.get(criterion)
        if b_score is None or c_score is None:
            continue
        delta = c_score - b_score
        if delta < -per_criterion_threshold:
            regressions.append(criterion)
        elif delta > per_criterion_threshold:
            improvements.append(criterion)

    # Bias flag check
    forbidden_bias_flags = []
    if expected_characteristics:
        forbidden_bias_flags = expected_characteristics.get("forbidden_bias_flags", [])

    baseline_bias_flags = set(baseline_result.get("bias_flags", []))
    current_bias_flags = set(current.get("bias_flags", []))

    new_forbidden_flags = []
    for flag in forbidden_bias_flags:
        if flag not in baseline_bias_flags and flag in current_bias_flags:
            new_forbidden_flags.append(flag)
            if flag not in regressions:
                regressions.append(f"bias_flag:{flag}")

    # Non-fatal warnings
    flags = []
    baseline_iterations = baseline_result.get("iterations", 1)
    current_iterations = current.get("iterations", 1)
    if current_iterations > baseline_iterations + 1:
        flags.append(
            f"iterations increased: baseline={baseline_iterations}, "
            f"current={current_iterations}"
        )

    # Determine overall outcome
    # A per-criterion regression overrides a neutral overall score.
    if regressions:
        outcome = "degraded"
    elif overall_delta < -regression_threshold:
        outcome = "degraded"
    elif overall_delta > improvement_threshold:
        outcome = "improved"
    else:
        outcome = "neutral"

    return {
        "outcome": outcome,
        "delta": round(overall_delta, 4),
        "regressions": regressions,
        "improvements": improvements,
        "flags": flags,
    }
