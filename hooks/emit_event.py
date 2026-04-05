#!/usr/bin/env python3
"""
Core Onlooker event emission hook.
Reads hook input from stdin and emits structured events to JSONL.
"""

import json
import sys
import os
from datetime import datetime, timezone
from pathlib import Path

def get_event_log_path():
    """Get the path to the event log file."""
    home = Path.home()
    log_dir = home / ".claude" / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    return log_dir / "agent-events.jsonl"

def emit_event(hook_event_name: str):
    """Read hook input and emit structured event."""
    try:
        # Read event data from stdin
        input_data = json.load(sys.stdin)

        # Extract relevant fields
        session_id = input_data.get("session_id", "unknown")
        cwd = input_data.get("cwd", "")

        # Build event based on hook type
        event = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "session_id": session_id,
            "hook_event_name": hook_event_name,
            "cwd": cwd,
        }

        # Add hook-specific data
        if hook_event_name in ["PreToolUse", "PostToolUse", "PostToolUseFailure"]:
            event["tool_name"] = input_data.get("tool_name", "unknown")
            event["tool_input"] = input_data.get("tool_input", {})

        elif hook_event_name == "SessionStart":
            event["source"] = input_data.get("source", "unknown")

        elif hook_event_name == "Stop":
            event["stop_reason"] = input_data.get("stop_reason", "unknown")

        # Emit to JSONL
        log_path = get_event_log_path()
        with open(log_path, "a") as f:
            f.write(json.dumps(event) + "\n")

        return 0

    except Exception as e:
        sys.stderr.write(f"Error emitting event: {e}\n")
        return 1

if __name__ == "__main__":
    hook_name = sys.argv[1] if len(sys.argv) > 1 else "unknown"
    sys.exit(emit_event(hook_name))
