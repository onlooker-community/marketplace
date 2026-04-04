#!/usr/bin/env python3
"""Scribe capture script — fallback for environments without agent hook support.

Reads PostToolUse JSON from stdin, extracts file path and change type,
and appends a capture entry to the session's JSONL file.

Must never raise exceptions or block file operations.
"""

import json
import sys
from datetime import datetime, timezone

from utils import append_capture, get_config, should_skip_path


def extract_capture_from_stdin() -> None:
    """Read tool use context from stdin and create a capture entry."""
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            return

        data = json.loads(raw)

        # Extract file path from tool input
        tool_input = data.get("tool_input", {})
        file_path = tool_input.get("file_path", "")

        if not file_path:
            return

        # Check skip paths
        if should_skip_path(file_path):
            return

        # Determine change type
        tool_name = data.get("tool_name", "")
        if tool_name == "Write":
            change_type = "created"
        else:
            change_type = "modified"

        # Extract session ID
        session_id = data.get("session_id", "unknown")

        # Build a minimal capture entry (without LLM enrichment)
        entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "file": file_path,
            "change_type": change_type,
            "intent": None,
            "decision": None,
            "tradeoffs": None,
            "follow_up": None,
            "tags": [],
            "source": "fallback",
        }

        config = get_config()
        if config.get("skip_trivial", True):
            # Check if the change is trivially small
            tool_response = data.get("tool_response", "")
            if isinstance(tool_response, str) and len(tool_response.strip()) < 3:
                return

        append_capture(session_id, entry)

    except (json.JSONDecodeError, KeyError, OSError):
        pass
    except Exception:
        # Never surface errors
        pass


def main() -> None:
    extract_capture_from_stdin()


if __name__ == "__main__":
    main()
