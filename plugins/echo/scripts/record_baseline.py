#!/usr/bin/env python3
"""
Echo baseline recorder.

Runs the Tribunal pipeline for one or more test cases and records the result
as the baseline for future regression comparisons.

Usage:
    python3 record_baseline.py --test judge-bias-detection-001
    python3 record_baseline.py --agent tribunal/agents/judge.md
    python3 record_baseline.py --all
    python3 record_baseline.py --test judge-bias-detection-001 --force
"""

import argparse
import datetime
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from utils import (
    load_config,
    load_all_test_cases,
    filter_test_cases,
    get_baseline_path,
    hash_agent_file,
    require_tribunal,
    resolve_config_path,
)
from run_suite import invoke_tribunal


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Echo baseline recorder")
    parser.add_argument("--test", help="Record baseline for a single test case ID")
    parser.add_argument("--agent", help="Record baselines for all test cases for this agent file")
    parser.add_argument("--all", action="store_true", help="Record baselines for all test cases")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing baselines without prompting",
    )
    return parser.parse_args()


def record_one(test_case: dict, config: dict, force: bool) -> bool:
    """
    Record baseline for a single test case.

    Returns True on success, False on skip/error.
    """
    test_id = test_case["id"]
    baseline_path = get_baseline_path(config, test_id)

    # Guard against accidental overwrites
    if baseline_path.exists() and not force:
        print(
            f"Error: Baseline already exists for {test_id}. Use --force to overwrite.",
            file=sys.stderr,
        )
        return False

    # Hash the agent file at record time
    agent_file = test_case.get("agent_file", "")
    agent_hash = hash_agent_file(agent_file)
    if agent_hash is None:
        print(
            f"Warning: could not hash agent file '{agent_file}' for {test_id}. "
            "Baseline will be recorded without a file hash.",
            file=sys.stderr,
        )

    # Run Tribunal
    print(f"  Recording: {test_id} ...", flush=True)
    result = invoke_tribunal(test_case)

    if result.get("error"):
        print(f"Error recording baseline for {test_id}: {result['error']}", file=sys.stderr)
        return False

    # Build baseline record
    baseline = {
        "test_id": test_id,
        "recorded": datetime.datetime.utcnow().isoformat() + "Z",
        "agent_file_hash": agent_hash,
        "result": {
            "final_score": result.get("final_score"),
            "iterations": result.get("iterations"),
            "pass": result.get("pass"),
            "judge_scores": result.get("judge_scores", []),
            "bias_flags": result.get("bias_flags", []),
            "meta_approved": result.get("meta_approved"),
        },
        "rubric_scores": result.get("rubric_scores", {}),
    }

    # Ensure baselines dir exists
    baseline_path.parent.mkdir(parents=True, exist_ok=True)

    # Write
    with open(baseline_path, "w") as f:
        json.dump(baseline, f, indent=2)

    score = result.get("final_score", "N/A")
    iterations = result.get("iterations", "N/A")
    print(f"  Baseline recorded for {test_id}: score={score}, iterations={iterations}")
    return True


def main():
    args = parse_args()
    config = load_config()

    if not any([args.test, args.agent, args.all]):
        print(
            "Error: specify --test, --agent, or --all to select test cases.",
            file=sys.stderr,
        )
        sys.exit(1)

    require_tribunal()

    test_cases_dir = resolve_config_path(config["test_cases_dir"])
    all_cases = load_all_test_cases(test_cases_dir)

    if args.all:
        cases = all_cases
    else:
        cases = filter_test_cases(
            all_cases,
            agent_file=args.agent,
            test_id=args.test,
        )

    if not cases:
        print("No matching test cases found.", file=sys.stderr)
        sys.exit(1)

    success = 0
    failed = 0
    for tc in cases:
        ok = record_one(tc, config, force=args.force)
        if ok:
            success += 1
        else:
            failed += 1

    print(f"\nDone: {success} recorded, {failed} failed/skipped.")
    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
