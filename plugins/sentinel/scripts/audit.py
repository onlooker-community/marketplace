#!/usr/bin/env python3
"""Sentinel audit log writer and reader.

Writes structured audit entries to JSONL. Provides read path for
/sentinel:sentinel audit command. Write failures are always silent —
never block execution or propagate exceptions.
"""

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


def get_config() -> dict:
    """Load Sentinel config, falling back to defaults."""
    config_path = Path(__file__).parent.parent / "config.json"
    defaults = {
        "audit_log": "~/.claude/sentinel/audit.jsonl",
    }
    try:
        with open(config_path) as f:
            config = json.load(f)
        for key, value in defaults.items():
            config.setdefault(key, value)
        return config
    except (FileNotFoundError, json.JSONDecodeError):
        return defaults


def get_audit_path() -> Path:
    """Resolve the audit log path, creating parent dirs if needed."""
    config = get_config()
    path = Path(os.path.expanduser(config["audit_log"]))
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def write_entry(
    session_id: str,
    cwd: str,
    command: str,
    risk_level: str,
    decision: str,
    reason: str = "",
    pattern_matched: str = "",
) -> None:
    """Append an audit entry to the JSONL log. Silent on failure."""
    try:
        entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "session_id": session_id,
            "cwd": cwd,
            "command": command[:200],
            "risk_level": risk_level,
            "decision": decision,
            "reason": reason,
            "pattern_matched": pattern_matched,
        }

        path = get_audit_path()
        with open(path, "a") as f:
            f.write(json.dumps(entry) + "\n")
    except Exception:
        # Never block execution on audit failures
        pass


def read_entries(count: int = 20) -> list[dict]:
    """Read the most recent N entries from the audit log."""
    path = get_audit_path()
    if not path.exists():
        return []

    entries = []
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entries.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    except (OSError, PermissionError):
        return []

    return entries[-count:]


def main() -> None:
    """CLI interface for audit log operations."""
    if "--write" in sys.argv:
        # Read entry from stdin JSON
        try:
            raw = sys.stdin.read()
            data = json.loads(raw)
            write_entry(
                session_id=data.get("session_id", ""),
                cwd=data.get("cwd", ""),
                command=data.get("command", ""),
                risk_level=data.get("risk_level", ""),
                decision=data.get("decision", ""),
                reason=data.get("reason", ""),
                pattern_matched=data.get("pattern_matched", ""),
            )
        except Exception:
            pass
    elif "--read" in sys.argv:
        count = 20
        for i, arg in enumerate(sys.argv):
            if arg == "--count" and i + 1 < len(sys.argv):
                try:
                    count = int(sys.argv[i + 1])
                except ValueError:
                    pass
        entries = read_entries(count)
        json.dump(entries, sys.stdout, indent=2)
    else:
        entries = read_entries()
        json.dump(entries, sys.stdout, indent=2)


if __name__ == "__main__":
    main()
