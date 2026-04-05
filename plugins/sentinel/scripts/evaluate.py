#!/usr/bin/env python3
"""Sentinel deterministic evaluation fallback.

Reads a Bash command from stdin JSON, matches against patterns/*.json,
and returns a hook-compatible JSON decision. Used in CI/CD contexts
where LLM evaluation is unavailable.

Exit codes:
  0 — allow or log (command proceeds)
  2 — block (command rejected, stderr has reason)

Must produce identical decisions for exact pattern matches regardless
of environment.
"""

import json
import os
import re
import sys
from pathlib import Path
from typing import Optional


def load_config() -> dict:
    """Load Sentinel config, falling back to defaults."""
    config_path = Path(__file__).parent.parent / "config.json"
    defaults = {
        "enabled": True,
        "default_behaviors": {
            "critical": "block",
            "high": "review",
            "medium": "log",
            "low": "allow",
        },
        "session_overrides": {},
        "audit_log": "~/.claude/sentinel/audit.jsonl",
        "protect_paths": [],
        "safe_paths": ["/tmp", "~/.claude/archivist"],
    }
    try:
        with open(config_path) as f:
            config = json.load(f)
        for key, value in defaults.items():
            config.setdefault(key, value)
        return config
    except (FileNotFoundError, json.JSONDecodeError):
        return defaults


def load_patterns() -> list[dict]:
    """Load all pattern files from the patterns directory."""
    patterns_dir = Path(__file__).parent.parent / "patterns"
    all_patterns = []

    if not patterns_dir.exists():
        return all_patterns

    for pattern_file in sorted(patterns_dir.glob("*.json")):
        try:
            with open(pattern_file) as f:
                data = json.load(f)
            for pattern in data.get("patterns", []):
                pattern["_category"] = data.get("category", pattern_file.stem)
                all_patterns.append(pattern)
        except (json.JSONDecodeError, OSError):
            continue

    return all_patterns


def is_safe_path(command: str, safe_paths: list[str]) -> bool:
    """Check if the command targets only safe paths."""
    for safe_path in safe_paths:
        expanded = os.path.expanduser(safe_path)
        if expanded in command:
            return True
    return False


def is_protected_path(command: str, protect_paths: list[str]) -> bool:
    """Check if the command targets a protected path."""
    for protected in protect_paths:
        expanded = os.path.expanduser(protected)
        if expanded in command:
            return True
    return False


def match_patterns(command: str, patterns: list[dict]) -> list[dict]:
    """Find all patterns matching the command. Returns matched patterns."""
    matches = []
    for pattern in patterns:
        try:
            if re.search(pattern["regex"], command, re.IGNORECASE):
                matches.append(pattern)
        except re.error:
            continue
    return matches


def highest_risk(matches: list[dict]) -> Optional[dict]:
    """Return the highest-risk match from a list of matches."""
    risk_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
    if not matches:
        return None
    return min(matches, key=lambda m: risk_order.get(m.get("risk_level", "low"), 3))


def evaluate(command: str) -> dict:
    """Evaluate a command and return a decision dict."""
    config = load_config()

    if not config.get("enabled", True):
        return {"decision": "allow"}

    # Check safe paths first
    safe_paths = config.get("safe_paths", [])
    if is_safe_path(command, safe_paths):
        return {"decision": "allow"}

    patterns = load_patterns()
    matches = match_patterns(command, patterns)

    if not matches:
        return {"decision": "allow"}

    # Elevate risk if targeting protected paths
    protect_paths = config.get("protect_paths", [])
    if is_protected_path(command, protect_paths):
        for match in matches:
            match["risk_level"] = "critical"

    top = highest_risk(matches)
    if top is None:
        return {"decision": "allow"}

    risk = top["risk_level"]
    behaviors = config.get("default_behaviors", {})

    # Check session overrides
    overrides = config.get("session_overrides", {})
    override = overrides.get(top["id"])
    if override:
        behavior = override
    else:
        behavior = behaviors.get(risk, "log")

    if behavior == "block":
        return {
            "decision": "block",
            "risk_level": risk,
            "reason": top.get("description", "Matched a dangerous pattern"),
            "safer_alternative": top.get("safer_alternative", "Review the command manually before executing"),
            "pattern_matched": top["id"],
        }
    elif behavior == "review":
        return {
            "decision": "ask",
            "risk_level": risk,
            "reason": top.get("description", "This operation requires review"),
            "context": top.get("safer_alternative", ""),
            "pattern_matched": top["id"],
        }
    elif behavior == "log":
        return {
            "decision": "log",
            "risk_level": risk,
            "summary": top.get("description", "Matched a monitored pattern"),
            "pattern_matched": top["id"],
        }
    else:
        return {"decision": "allow"}


def main() -> None:
    """Read command from stdin JSON and output decision."""
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            json.dump({"decision": "allow"}, sys.stdout)
            return

        input_data = json.loads(raw)
        command = input_data.get("command", input_data.get("input", ""))

        if not command:
            json.dump({"decision": "allow"}, sys.stdout)
            return

        decision = evaluate(command)

        if decision["decision"] == "block":
            reason = f"Blocked: {decision['reason']}. {decision.get('safer_alternative', '')}"
            print(reason, file=sys.stderr)
            sys.exit(2)
        else:
            json.dump(decision, sys.stdout)

    except (json.JSONDecodeError, KeyError):
        json.dump({"decision": "allow"}, sys.stdout)
    except Exception:
        # Never crash — fail open
        json.dump({"decision": "allow"}, sys.stdout)


if __name__ == "__main__":
    main()
