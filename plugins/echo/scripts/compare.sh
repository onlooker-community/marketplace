#!/usr/bin/env bash
# Echo comparison engine.
#
# Compares a test run result against its recorded baseline and classifies
# the outcome as improved, degraded, or neutral.
#
# Usage: source this file then call compare()
#   compare "$current_json" "$baseline_json" "$config_json" "$expected_characteristics_json"
#
# Outputs a JSON object with: outcome, delta, regressions, improvements, flags

set -euo pipefail

# Source utils for config_get helper
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

compare() {
    local current="$1"
    local baseline="$2"
    local config="$3"
    local expected_characteristics="${4:-null}"

    local regression_threshold improvement_threshold per_criterion_threshold
    regression_threshold="$(config_get "$config" '.regression_threshold' '0.05')"
    improvement_threshold="$(config_get "$config" '.improvement_threshold' '0.05')"
    per_criterion_threshold="$(config_get "$config" '.per_criterion_regression_threshold' '0.10')"

    local baseline_score current_score overall_delta
    baseline_score="$(echo "$baseline" | jq -r '.result.final_score // 0')"
    current_score="$(echo "$current" | jq -r '.final_score // 0')"
    overall_delta="$(echo "$current_score - $baseline_score" | bc -l)"

    # Per-criterion comparison
    local baseline_rubric current_rubric
    baseline_rubric="$(echo "$baseline" | jq -c '.rubric_scores // {}')"
    current_rubric="$(echo "$current" | jq -c '.rubric_scores // {}')"

    local regressions="[]"
    local improvements="[]"

    # Get all criteria from both baseline and current
    local all_criteria
    all_criteria="$(echo "$baseline_rubric $current_rubric" | jq -s '.[0] + .[1] | keys | sort | unique | .[]' -r)"

    while IFS= read -r criterion; do
        [[ -z "$criterion" ]] && continue
        local b_score c_score delta
        b_score="$(echo "$baseline_rubric" | jq -r --arg c "$criterion" '.[$c] // empty')"
        c_score="$(echo "$current_rubric" | jq -r --arg c "$criterion" '.[$c] // empty')"
        [[ -z "$b_score" || -z "$c_score" ]] && continue

        delta="$(echo "$c_score - $b_score" | bc -l)"
        local neg_threshold
        neg_threshold="$(echo "-$per_criterion_threshold" | bc -l)"

        if (( $(echo "$delta < $neg_threshold" | bc -l) )); then
            regressions="$(echo "$regressions" | jq --arg c "$criterion" '. + [$c]')"
        elif (( $(echo "$delta > $per_criterion_threshold" | bc -l) )); then
            improvements="$(echo "$improvements" | jq --arg c "$criterion" '. + [$c]')"
        fi
    done <<< "$all_criteria"

    # Bias flag check
    if [[ "$expected_characteristics" != "null" ]]; then
        local forbidden_flags
        forbidden_flags="$(echo "$expected_characteristics" | jq -r '.forbidden_bias_flags // [] | .[]')"

        local baseline_bias_flags current_bias_flags
        baseline_bias_flags="$(echo "$baseline" | jq -c '.result.bias_flags // []')"
        current_bias_flags="$(echo "$current" | jq -c '.bias_flags // []')"

        while IFS= read -r flag; do
            [[ -z "$flag" ]] && continue
            local in_baseline in_current
            in_baseline="$(echo "$baseline_bias_flags" | jq --arg f "$flag" 'index($f) != null')"
            in_current="$(echo "$current_bias_flags" | jq --arg f "$flag" 'index($f) != null')"

            if [[ "$in_baseline" == "false" && "$in_current" == "true" ]]; then
                regressions="$(echo "$regressions" | jq --arg c "bias_flag:$flag" '. + [$c]')"
            fi
        done <<< "$forbidden_flags"
    fi

    # Non-fatal warnings
    local flags="[]"
    local baseline_iterations current_iterations
    baseline_iterations="$(echo "$baseline" | jq -r '.result.iterations // 1')"
    current_iterations="$(echo "$current" | jq -r '.iterations // 1')"
    local iter_threshold=$((baseline_iterations + 1))
    if (( current_iterations > iter_threshold )); then
        flags="$(echo "$flags" | jq --arg f "iterations increased: baseline=$baseline_iterations, current=$current_iterations" '. + [$f]')"
    fi

    # Determine overall outcome
    local outcome="neutral"
    local has_regressions
    has_regressions="$(echo "$regressions" | jq 'length > 0')"
    local neg_regression_threshold
    neg_regression_threshold="$(echo "-$regression_threshold" | bc -l)"

    if [[ "$has_regressions" == "true" ]]; then
        outcome="degraded"
    elif (( $(echo "$overall_delta < $neg_regression_threshold" | bc -l) )); then
        outcome="degraded"
    elif (( $(echo "$overall_delta > $improvement_threshold" | bc -l) )); then
        outcome="improved"
    fi

    # Round delta to 4 decimal places
    local rounded_delta
    rounded_delta="$(printf "%.4f" "$overall_delta")"

    jq -n \
        --arg outcome "$outcome" \
        --argjson delta "$rounded_delta" \
        --argjson regressions "$regressions" \
        --argjson improvements "$improvements" \
        --argjson flags "$flags" \
        '{outcome: $outcome, delta: $delta, regressions: $regressions, improvements: $improvements, flags: $flags}'
}
