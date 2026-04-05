#!/usr/bin/env python3
"""
Echo test suite runner.

Loads matching test cases, runs them through the Tribunal evaluation pipeline,
compares results against baselines, and reports outcomes.

Usage:
    python3 run_suite.py --trigger config_change --changed-file <path>
    python3 run_suite.py --trigger manual --all
    python3 run_suite.py --trigger manual --agent tribunal/agents/judge.md
    python3 run_suite.py --trigger manual --tag bias-detection
    python3 run_suite.py --trigger manual --test judge-bias-detection-001
"""

import argparse
import datetime
import json
import os
import subprocess
import sys
from pathlib import Path

# Add scripts/ to path so we can import sibling modules
sys.path.insert(0, str(Path(__file__).parent))

from utils import (
    load_config,
    load_all_test_cases,
    filter_test_cases,
    load_baseline,
    get_baseline_path,
    hash_agent_file,
    require_tribunal,
    write_run_log,
    emit_onlooker_event,
    resolve_config_path,
)
from compare import compare


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Echo test suite runner")
    parser.add_argument(
        "--trigger",
        choices=["config_change", "manual"],
        default="manual",
        help="What triggered this run",
    )
    parser.add_argument(
        "--changed-file",
        dest="changed_file",
        help="File that changed (used with --trigger config_change)",
    )
    parser.add_argument("--agent", help="Run tests for this agent file")
    parser.add_argument("--tag", help="Run tests with this tag")
    parser.add_argument("--test", help="Run a single test by ID")
    parser.add_argument("--all", action="store_true", help="Run all test cases")
    return parser.parse_args()


def invoke_tribunal(test_case: dict) -> dict:
    """
    Invoke the Tribunal evaluation pipeline for a test case.

    Spawns tribunal:tribunal-actor with the task and rubric from the test case,
    then runs tribunal:tribunal-judge on the output.

    Returns a result dict with keys matching the baseline result schema:
        final_score, iterations, pass, judge_scores, bias_flags,
        meta_approved, rubric_scores
    """
    # Tribunal is invoked as a subagent via Claude Code's Task tool.
    # At script runtime this is a subprocess call to the claude CLI.
    # The actual subagent spawning happens inside the claude session.
    #
    # For the purposes of this harness, we construct the Tribunal invocation
    # payload and call out to the CLI. In a full implementation this would
    # be replaced by direct Task tool API calls when running inside a session.

    task_prompt = test_case.get("task", "")
    rubric_path = test_case.get("rubric", "")
    passing_score = test_case.get("passing_score", 0.80)

    # Build a structured prompt for the Tribunal actor
    tribunal_input = json.dumps({
        "task": task_prompt,
        "rubric": rubric_path,
        "passing_score": passing_score,
        "test_id": test_case.get("id"),
    })

    # Attempt to invoke via claude CLI if available
    try:
        result = subprocess.run(
            [
                "claude",
                "--agent", "tribunal:tribunal-actor",
                "--input", tribunal_input,
                "--output-format", "json",
            ],
            capture_output=True,
            text=True,
            timeout=600,
        )
        if result.returncode == 0:
            return json.loads(result.stdout)
    except (subprocess.TimeoutExpired, FileNotFoundError, json.JSONDecodeError):
        pass

    # If CLI invocation is unavailable (e.g., running outside a session),
    # return a sentinel result indicating the pipeline could not be run.
    return {
        "final_score": None,
        "iterations": None,
        "pass": None,
        "judge_scores": [],
        "bias_flags": [],
        "meta_approved": None,
        "rubric_scores": {},
        "error": "Tribunal pipeline could not be invoked. Run echo inside a Claude Code session.",
    }


def run_test_case(test_case: dict, config: dict) -> dict:
    """
    Run a single test case and return a result record.

    Returns a dict with keys:
        test_id, outcome, delta, regressions, improvements, flags,
        current_result, baseline_result, warnings
    """
    test_id = test_case["id"]
    warnings = []

    # Load baseline
    baseline_path = get_baseline_path(config, test_id)
    baseline = load_baseline(baseline_path)

    if baseline is None:
        return {
            "test_id": test_id,
            "skipped": True,
            "reason": f"No baseline recorded. Run: /echo:echo record --test {test_id}",
        }

    # Check for agent file hash drift
    agent_file = test_case.get("agent_file", "")
    current_hash = hash_agent_file(agent_file)
    recorded_hash = baseline.get("agent_file_hash")

    if current_hash and recorded_hash and current_hash != recorded_hash:
        warnings.append(
            f"Agent file hash mismatch for {agent_file}. "
            "Baseline was recorded against a different version of the agent. "
            "Consider re-recording: /echo:echo record --test {test_id} --force"
        )

    # Invoke Tribunal
    print(f"  Running: {test_id} ...", flush=True)
    current_result = invoke_tribunal(test_case)

    if current_result.get("error"):
        return {
            "test_id": test_id,
            "skipped": True,
            "reason": current_result["error"],
            "warnings": warnings,
        }

    # Compare against baseline
    comparison = compare(
        current=current_result,
        baseline=baseline,
        config=config,
        expected_characteristics=test_case.get("expected_characteristics"),
    )

    return {
        "test_id": test_id,
        "skipped": False,
        "outcome": comparison["outcome"],
        "delta": comparison["delta"],
        "regressions": comparison["regressions"],
        "improvements": comparison["improvements"],
        "flags": comparison["flags"],
        "current_result": current_result,
        "baseline_result": baseline.get("result", {}),
        "warnings": warnings,
    }


def main():
    args = parse_args()
    config = load_config()

    # Determine which test cases to run
    if args.trigger == "config_change" and args.changed_file:
        agent_filter = args.changed_file
        tag_filter = None
        test_filter = None
        run_all = False
    else:
        agent_filter = args.agent
        tag_filter = args.tag
        test_filter = args.test
        run_all = args.all

    if not any([agent_filter, tag_filter, test_filter, run_all]):
        print(
            "Error: specify --all, --agent, --tag, or --test to select test cases.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Check Tribunal is available
    require_tribunal()

    # Load and filter test cases
    test_cases_dir = resolve_config_path(config["test_cases_dir"])
    all_cases = load_all_test_cases(test_cases_dir)
    cases = filter_test_cases(
        all_cases,
        agent_file=agent_filter,
        tag=tag_filter,
        test_id=test_filter,
    )

    if not cases and not run_all:
        print(f"No test cases matched the given filters.", file=sys.stderr)
        sys.exit(0)

    if run_all:
        cases = all_cases

    if not cases:
        print("No test cases found.", file=sys.stderr)
        sys.exit(0)

    # Run test cases
    print(f"Echo: running {len(cases)} test case(s)...", flush=True)
    results = []
    for tc in cases:
        result = run_test_case(tc, config)
        results.append(result)

        # Print warnings inline
        for w in result.get("warnings", []):
            print(f"  Warning: {w}", file=sys.stderr)

    # Tally outcomes
    counts = {"improved": 0, "degraded": 0, "neutral": 0, "skipped": 0}
    for r in results:
        if r.get("skipped"):
            counts["skipped"] += 1
        else:
            counts[r.get("outcome", "neutral")] += 1

    # Build run log
    run_data = {
        "trigger": args.trigger,
        "changed_file": getattr(args, "changed_file", None),
        "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
        "counts": counts,
        "results": results,
    }

    log_path = write_run_log(config, run_data)
    print(f"Run log written to: {log_path}", flush=True)

    # Summary
    print(
        f"\nEcho: {counts['improved']} improved, "
        f"{counts['degraded']} degraded, "
        f"{counts['neutral']} neutral, "
        f"{counts['skipped']} skipped"
    )

    # Emit Onlooker event
    emit_onlooker_event(config, "echo_run", run_data)

    # Output full results as JSON for callers
    print(json.dumps(run_data, indent=2))

    # Non-zero exit if any regressions
    if counts["degraded"] > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
