#!/usr/bin/env python3
"""Archivist injection script.

Invoked by the SessionStart hook (command fallback).
Reads cwd from stdin JSON, finds the most recent session extract,
and returns additionalContext JSON on stdout.

Must never raise exceptions or block session start.
"""

import json
import sys

from utils import find_most_recent_session, get_config


CONFIDENCE_LEVELS = {"high": 3, "medium": 2, "low": 1}
PRIORITY_LEVELS = {"high": 3, "medium": 2, "low": 1}


def confidence_value(level: str) -> int:
    return CONFIDENCE_LEVELS.get(level, 0)


def priority_value(level: str) -> int:
    return PRIORITY_LEVELS.get(level, 0)


def build_summary(session: dict, config: dict) -> str:
    """Build a concise injection summary from a session extract."""
    min_confidence = config.get("min_confidence_to_inject", "medium")
    min_conf_val = confidence_value(min_confidence)
    max_words = config.get("max_injection_words", 400)

    parts = ["Continuing from last session:"]

    # Open questions first — top 3 by priority
    questions = sorted(
        session.get("open_questions", []),
        key=lambda q: priority_value(q.get("priority", "low")),
        reverse=True,
    )[:3]
    if questions:
        parts.append("")
        for q in questions:
            priority = q.get("priority", "medium")
            parts.append(f"- [{priority}] {q['question']}: {q.get('context', '')}")

    # Decisions — top 3 by confidence, filtered by min threshold
    decisions = [
        d
        for d in session.get("decisions", [])
        if confidence_value(d.get("confidence", "low")) >= min_conf_val
    ]
    decisions.sort(key=lambda d: confidence_value(d.get("confidence", "low")), reverse=True)
    decisions = decisions[:3]
    if decisions:
        parts.append("")
        for d in decisions:
            parts.append(f"- Rule: {d['rule']} ({d.get('confidence', 'medium')} confidence)")

    # Dead ends — top 2, only if relevant
    dead_ends = session.get("dead_ends", [])[:2]
    if dead_ends:
        parts.append("")
        for de in dead_ends:
            parts.append(f"- Avoid: {de['approach']} — {de.get('why_failed', 'did not work')}")

    summary = "\n".join(parts)

    # Truncate to max words
    words = summary.split()
    if len(words) > max_words:
        summary = " ".join(words[:max_words]) + "..."

    return summary


def main() -> None:
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            return

        input_data = json.loads(raw)
        cwd = input_data.get("cwd", "")
        if not cwd:
            return

        config = get_config()
        if not config.get("inject_on_start", True):
            return

        session = find_most_recent_session(cwd)
        if not session:
            return

        summary = build_summary(session, config)

        output = {"additionalContext": summary}
        print(json.dumps(output))
    except (json.JSONDecodeError, KeyError, OSError):
        pass


if __name__ == "__main__":
    main()
