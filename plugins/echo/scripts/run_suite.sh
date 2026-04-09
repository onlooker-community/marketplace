#!/usr/bin/env bash
# Echo test suite runner.
#
# Loads matching test cases, runs them through the Tribunal evaluation pipeline,
# compares results against baselines, and reports outcomes.
#
# Usage:
#     bash run_suite.sh --trigger config_change --changed-file <path>
#     bash run_suite.sh --trigger manual --all
#     bash run_suite.sh --trigger manual --agent tribunal/agents/judge.md
#     bash run_suite.sh --trigger manual --tag bias-detection
#     bash run_suite.sh --trigger manual --test judge-bias-detection-001

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/compare.sh"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

TRIGGER="manual"
CHANGED_FILE=""
AGENT=""
TAG=""
TEST=""
RUN_ALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --trigger)
            TRIGGER="$2"; shift 2 ;;
        --changed-file)
            CHANGED_FILE="$2"; shift 2 ;;
        --agent)
            AGENT="$2"; shift 2 ;;
        --tag)
            TAG="$2"; shift 2 ;;
        --test)
            TEST="$2"; shift 2 ;;
        --all)
            RUN_ALL=true; shift ;;
        *)
            echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Tribunal invocation
# ---------------------------------------------------------------------------

invoke_tribunal() {
    local test_case="$1"

    local task_prompt rubric_path passing_score test_id
    task_prompt="$(echo "$test_case" | jq -r '.task // ""')"
    rubric_path="$(echo "$test_case" | jq -r '.rubric // ""')"
    passing_score="$(echo "$test_case" | jq -r '.passing_score // 0.80')"
    test_id="$(echo "$test_case" | jq -r '.id // ""')"

    local tribunal_input
    tribunal_input="$(jq -n \
        --arg task "$task_prompt" \
        --arg rubric "$rubric_path" \
        --argjson passing_score "$passing_score" \
        --arg test_id "$test_id" \
        '{task: $task, rubric: $rubric, passing_score: $passing_score, test_id: $test_id}')"

    # Attempt to invoke via claude CLI if available
    local result
    if result="$(timeout 600 claude \
        --agent "tribunal:tribunal-actor" \
        --input "$tribunal_input" \
        --output-format json 2>/dev/null)"; then
        echo "$result"
        return
    fi

    # If CLI invocation is unavailable, return a sentinel result
    jq -n '{
        final_score: null,
        iterations: null,
        pass: null,
        judge_scores: [],
        bias_flags: [],
        meta_approved: null,
        rubric_scores: {},
        error: "Tribunal pipeline could not be invoked. Run echo inside a Claude Code session."
    }'
}

# ---------------------------------------------------------------------------
# Run a single test case
# ---------------------------------------------------------------------------

run_test_case() {
    local test_case="$1"
    local config="$2"

    local test_id
    test_id="$(echo "$test_case" | jq -r '.id')"
    local warnings="[]"

    # Load baseline
    local baseline_path
    baseline_path="$(get_baseline_path "$config" "$test_id")"
    local baseline
    baseline="$(load_baseline "$baseline_path")"

    if [[ "$baseline" == "null" ]]; then
        jq -n --arg id "$test_id" \
            --arg reason "No baseline recorded. Run: /echo:echo record --test $test_id" \
            '{test_id: $id, skipped: true, reason: $reason}'
        return
    fi

    # Check for agent file hash drift
    local agent_file
    agent_file="$(echo "$test_case" | jq -r '.agent_file // ""')"
    local current_hash recorded_hash
    current_hash="$(hash_agent_file "$agent_file")"
    recorded_hash="$(echo "$baseline" | jq -r '.agent_file_hash // ""')"

    if [[ -n "$current_hash" && -n "$recorded_hash" && "$current_hash" != "$recorded_hash" ]]; then
        warnings="$(echo "$warnings" | jq --arg w \
            "Agent file hash mismatch for $agent_file. Baseline was recorded against a different version of the agent. Consider re-recording: /echo:echo record --test $test_id --force" \
            '. + [$w]')"
    fi

    # Invoke Tribunal
    echo "  Running: $test_id ..." >&2
    local current_result
    current_result="$(invoke_tribunal "$test_case")"

    local error
    error="$(echo "$current_result" | jq -r '.error // empty')"
    if [[ -n "$error" ]]; then
        jq -n --arg id "$test_id" --arg reason "$error" --argjson warnings "$warnings" \
            '{test_id: $id, skipped: true, reason: $reason, warnings: $warnings}'
        return
    fi

    # Compare against baseline
    local expected_chars
    expected_chars="$(echo "$test_case" | jq -c '.expected_characteristics // null')"
    local comparison
    comparison="$(compare "$current_result" "$baseline" "$config" "$expected_chars")"

    local baseline_result
    baseline_result="$(echo "$baseline" | jq -c '.result // {}')"

    jq -n \
        --arg id "$test_id" \
        --arg outcome "$(echo "$comparison" | jq -r '.outcome')" \
        --argjson delta "$(echo "$comparison" | jq '.delta')" \
        --argjson regressions "$(echo "$comparison" | jq '.regressions')" \
        --argjson improvements "$(echo "$comparison" | jq '.improvements')" \
        --argjson flags "$(echo "$comparison" | jq '.flags')" \
        --argjson current_result "$current_result" \
        --argjson baseline_result "$baseline_result" \
        --argjson warnings "$warnings" \
        '{
            test_id: $id,
            skipped: false,
            outcome: $outcome,
            delta: $delta,
            regressions: $regressions,
            improvements: $improvements,
            flags: $flags,
            current_result: $current_result,
            baseline_result: $baseline_result,
            warnings: $warnings
        }'
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    local config
    config="$(load_config)"

    # Determine filters
    local agent_filter="" tag_filter="" test_filter=""
    local run_all=false

    if [[ "$TRIGGER" == "config_change" && -n "$CHANGED_FILE" ]]; then
        agent_filter="$CHANGED_FILE"
    else
        agent_filter="$AGENT"
        tag_filter="$TAG"
        test_filter="$TEST"
        run_all="$RUN_ALL"
    fi

    if [[ -z "$agent_filter" && -z "$tag_filter" && -z "$test_filter" && "$run_all" != "true" ]]; then
        echo "Error: specify --all, --agent, --tag, or --test to select test cases." >&2
        exit 1
    fi

    # Check Tribunal is available
    require_tribunal

    # Load and filter test cases
    local test_cases_dir
    test_cases_dir="$(resolve_config_path "$(config_get "$config" '.test_cases_dir')")"
    local all_cases
    all_cases="$(load_all_test_cases "$test_cases_dir")"

    local cases
    if [[ "$run_all" == "true" ]]; then
        cases="$all_cases"
    else
        cases="$(filter_test_cases "$all_cases" "$agent_filter" "$tag_filter" "$test_filter")"
    fi

    local case_count
    case_count="$(echo "$cases" | jq 'length')"

    if [[ "$case_count" -eq 0 ]]; then
        if [[ "$run_all" != "true" ]]; then
            echo "No test cases matched the given filters." >&2
        else
            echo "No test cases found." >&2
        fi
        exit 0
    fi

    # Run test cases
    echo "Echo: running $case_count test case(s)..." >&2
    local results="[]"
    local improved=0 degraded=0 neutral=0 skipped=0

    local i
    for (( i=0; i<case_count; i++ )); do
        local tc
        tc="$(echo "$cases" | jq -c ".[$i]")"
        local result
        result="$(run_test_case "$tc" "$config")"
        results="$(echo "$results" | jq --argjson r "$result" '. + [$r]')"

        # Print warnings inline
        echo "$result" | jq -r '.warnings // [] | .[]' | while IFS= read -r w; do
            [[ -n "$w" ]] && echo "  Warning: $w" >&2
        done

        # Tally
        local is_skipped
        is_skipped="$(echo "$result" | jq -r '.skipped // false')"
        if [[ "$is_skipped" == "true" ]]; then
            ((skipped++))
        else
            local outcome
            outcome="$(echo "$result" | jq -r '.outcome // "neutral"')"
            case "$outcome" in
                improved) ((improved++)) ;;
                degraded) ((degraded++)) ;;
                *) ((neutral++)) ;;
            esac
        fi
    done

    # Build run log
    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    local counts
    counts="$(jq -n \
        --argjson improved "$improved" \
        --argjson degraded "$degraded" \
        --argjson neutral "$neutral" \
        --argjson skipped "$skipped" \
        '{improved: $improved, degraded: $degraded, neutral: $neutral, skipped: $skipped}')"

    local run_data
    run_data="$(jq -n \
        --arg trigger "$TRIGGER" \
        --arg changed_file "$CHANGED_FILE" \
        --arg timestamp "$timestamp" \
        --argjson counts "$counts" \
        --argjson results "$results" \
        '{trigger: $trigger, changed_file: $changed_file, timestamp: $timestamp, counts: $counts, results: $results}')"

    local log_path
    log_path="$(write_run_log "$config" "$run_data")"
    echo "Run log written to: $log_path" >&2

    # Summary
    echo "" >&2
    echo "Echo: $improved improved, $degraded degraded, $neutral neutral, $skipped skipped" >&2

    # Emit Onlooker event
    emit_onlooker_event "$config" "echo_run" "$run_data"

    # Output full results as JSON for callers
    echo "$run_data" | jq '.'

    # Non-zero exit if any regressions
    if [[ "$degraded" -gt 0 ]]; then
        exit 1
    fi
}

main
