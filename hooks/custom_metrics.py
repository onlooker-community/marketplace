#!/usr/bin/env python3
"""
Custom metrics hook example.
Emits calculated metrics based on tool use events.
"""

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

def emit_custom_metric(hook_event_name: str, metric_type: str, value: any):
    """Emit a custom metric event."""
    input_data = json.load(sys.stdin)

    event = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "session_id": input_data.get("session_id"),
        "event_type": f"custom.{metric_type}",
        "payload": {"value": value}
    }

    log_path = Path.home() / ".claude" / "logs" / "agent-events.jsonl"
    with open(log_path, "a") as f:
        f.write(json.dumps(event) + "\n")

def main():
    try:
        input_data = json.load(sys.stdin)

        # Example: Calculate tokens per second
        if "payload" in input_data:
            payload = input_data["payload"]
            if "tokens" in payload and "latency_ms" in payload:
                tokens = payload["tokens"]
                latency_sec = payload["latency_ms"] / 1000
                tokens_per_sec = tokens / latency_sec if latency_sec > 0 else 0
                emit_custom_metric("PostToolUse", "efficiency", tokens_per_sec)

        return 0
    except Exception as e:
        sys.stderr.write(f"Error in custom metrics: {e}\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())
