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


def emit_onlooker_event(session: dict, config: dict) -> None:
    """Emit an archivist_session event to Onlooker if configured."""
    onlooker = config.get("onlooker", {})
    if not onlooker.get("enabled", False):
        return

    endpoint = onlooker.get("endpoint", "")
    if not endpoint:
        return

    try:
        import urllib.request

        event = {
            "type": "archivist_session",
            "workspaceId": onlooker.get("workspaceId", "archivist"),
            "session_id": session.get("session_id", ""),
            "cwd": session.get("cwd", ""),
            "timestamp": session.get("timestamp", ""),
            "decision_count": len(session.get("decisions", [])),
            "file_count": len(session.get("files", [])),
            "dead_end_count": len(session.get("dead_ends", [])),
            "open_question_count": len(session.get("open_questions", [])),
            "high_priority_questions": [
                q["question"]
                for q in session.get("open_questions", [])
                if q.get("priority") == "high"
            ],
        }

        req = urllib.request.Request(
            endpoint,
            data=json.dumps(event).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        urllib.request.urlopen(req, timeout=5)
    except Exception:
        # Never block on Onlooker failures
        pass


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

        config = get_config()
        emit_onlooker_event(data, config)
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
