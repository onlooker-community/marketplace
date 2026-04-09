#!/usr/bin/env bash
# Echo baseline recorder.
#
# Runs the Tribunal pipeline for one or more test cases and records the result
# as the baseline for future regression comparisons.
#
# Usage:
#     bash record_baseline.sh --test judge-bias-detection-001
#     bash record_baseline.sh --agent tribunal/agents/judge.md
#     bash record_baseline.sh --all
#     bash record_baseline.sh --test judge-bias-detection-001 --force

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Source run_suite.sh for invoke_tribunal — but only the function, not main()
# We inline invoke_tribunal here to avoid triggering run_suite.sh's main()
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

    local result
    if result="$(timeout 600 claude \
        --agent "tribunal:tribunal-actor" \
        --input "$tribunal_input" \
        --output-format json 2>/dev/null)"; then
        echo "$result"
        return
    fi

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
# Argument parsing
# ---------------------------------------------------------------------------

TEST=""
AGENT=""
RUN_ALL=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --test)
            TEST="$2"; shift 2 ;;
        --agent)
            AGENT="$2"; shift 2 ;;
        --all)
            RUN_ALL=true; shift ;;
        --force)
            FORCE=true; shift ;;
        *)
            echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Record a single baseline
# ---------------------------------------------------------------------------

record_one() {
    local test_case="$1"
    local config="$2"
    local force="$3"

    local test_id
    test_id="$(echo "$test_case" | jq -r '.id')"
    local baseline_path
    baseline_path="$(get_baseline_path "$config" "$test_id")"

    # Guard against accidental overwrites
    if [[ -f "$baseline_path" && "$force" != "true" ]]; then
        echo "Error: Baseline already exists for $test_id. Use --force to overwrite." >&2
        return 1
    fi

    # Hash the agent file at record time
    local agent_file
    agent_file="$(echo "$test_case" | jq -r '.agent_file // ""')"
    local agent_hash
    agent_hash="$(hash_agent_file "$agent_file")"
    if [[ -z "$agent_hash" ]]; then
        echo "Warning: could not hash agent file '$agent_file' for $test_id. Baseline will be recorded without a file hash." >&2
    fi

    # Run Tribunal
    echo "  Recording: $test_id ..."
    local result
    result="$(invoke_tribunal "$test_case")"

    local error
    error="$(echo "$result" | jq -r '.error // empty')"
    if [[ -n "$error" ]]; then
        echo "Error recording baseline for $test_id: $error" >&2
        return 1
    fi

    # Build baseline record
    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    local baseline
    baseline="$(jq -n \
        --arg test_id "$test_id" \
        --arg recorded "$timestamp" \
        --arg agent_hash "$agent_hash" \
        --argjson result "$result" \
        '{
            test_id: $test_id,
            recorded: $recorded,
            agent_file_hash: $agent_hash,
            result: {
                final_score: $result.final_score,
                iterations: $result.iterations,
                pass: $result.pass,
                judge_scores: ($result.judge_scores // []),
                bias_flags: ($result.bias_flags // []),
                meta_approved: $result.meta_approved
            },
            rubric_scores: ($result.rubric_scores // {})
        }')"

    # Ensure baselines dir exists
    mkdir -p "$(dirname "$baseline_path")"

    # Write
    echo "$baseline" | jq '.' > "$baseline_path"

    local score iterations
    score="$(echo "$result" | jq -r '.final_score // "N/A"')"
    iterations="$(echo "$result" | jq -r '.iterations // "N/A"')"
    echo "  Baseline recorded for $test_id: score=$score, iterations=$iterations"
    return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    if [[ -z "$TEST" && -z "$AGENT" && "$RUN_ALL" != "true" ]]; then
        echo "Error: specify --test, --agent, or --all to select test cases." >&2
        exit 1
    fi

    local config
    config="$(load_config)"

    require_tribunal

    local test_cases_dir
    test_cases_dir="$(resolve_config_path "$(config_get "$config" '.test_cases_dir')")"
    local all_cases
    all_cases="$(load_all_test_cases "$test_cases_dir")"

    local cases
    if [[ "$RUN_ALL" == "true" ]]; then
        cases="$all_cases"
    else
        cases="$(filter_test_cases "$all_cases" "$AGENT" "" "$TEST")"
    fi

    local case_count
    case_count="$(echo "$cases" | jq 'length')"

    if [[ "$case_count" -eq 0 ]]; then
        echo "No matching test cases found." >&2
        exit 1
    fi

    local success=0 failed=0
    local i
    for (( i=0; i<case_count; i++ )); do
        local tc
        tc="$(echo "$cases" | jq -c ".[$i]")"
        if record_one "$tc" "$config" "$FORCE"; then
            ((success++))
        else
            ((failed++))
        fi
    done

    echo ""
    echo "Done: $success recorded, $failed failed/skipped."
    if [[ "$failed" -gt 0 ]]; then
        exit 1
    fi
}

main
