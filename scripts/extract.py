#!/usr/bin/env python3
"""Archivist extraction script.

Invoked by the PreCompact hook (via command fallback) or SessionEnd (--finalize).
Reads hook input from stdin, writes structured session JSON to storage.

Must never raise exceptions or block compaction/session end.
"""

import json
import sys
from datetime import datetime, timezone

from utils import get_config, get_storage_path, write_session


def finalize_session() -> None:
    """Mark the most recent incomplete session as complete."""
    storage = get_storage_path()
    if not storage.exists():
        return

    # Find the most recent session file
    sessions = sorted(storage.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not sessions:
        return

    try:
        with open(sessions[0]) as f:
            data = json.load(f)

        if data.get("complete"):
            return

        data["complete"] = True
        data["completed_at"] = datetime.now(timezone.utc).isoformat()

        with open(sessions[0], "w") as f:
            json.dump(data, f, indent=2)
    except (json.JSONDecodeError, PermissionError, OSError):
        pass


def extract_from_stdin() -> None:
    """Read extraction data from stdin and write to storage."""
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            return

        data = json.loads(raw)

        # Validate minimum required fields
        session_id = data.get("session_id")
        if not session_id:
            return

        # Ensure timestamp
        if "timestamp" not in data:
            data["timestamp"] = datetime.now(timezone.utc).isoformat()

        # Ensure all categories exist
        for key in ("decisions", "files", "dead_ends", "open_questions"):
            data.setdefault(key, [])

        data["complete"] = False
        write_session(session_id, data)
    except (json.JSONDecodeError, KeyError, OSError):
        pass


def main() -> None:
    if "--finalize" in sys.argv:
        finalize_session()
    else:
        extract_from_stdin()


if __name__ == "__main__":
    main()
