"""
Shared utilities for Echo scripts.

Provides: test case loading, baseline loading, agent file hashing,
Tribunal availability check, Onlooker event emission, run log writing.
"""

import hashlib
import json
import os
import sys
import subprocess
import datetime
from pathlib import Path
from typing import Optional


# ---------------------------------------------------------------------------
# Plugin root resolution
# ---------------------------------------------------------------------------

def get_plugin_root() -> Path:
    """Return the Echo plugin root directory."""
    return Path(__file__).parent.parent.resolve()


def resolve_config_path(path_str: str) -> Path:
    """Expand ${CLAUDE_PLUGIN_ROOT} and ~ in a path string."""
    plugin_root = str(get_plugin_root())
    expanded = path_str.replace("${CLAUDE_PLUGIN_ROOT}", plugin_root)
    return Path(os.path.expanduser(expanded))


# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------

def load_config() -> dict:
    """Load config.json from the plugin root."""
    config_path = get_plugin_root() / "config.json"
    if not config_path.exists():
        raise FileNotFoundError(f"Echo config not found at {config_path}")
    with open(config_path) as f:
        return json.load(f)


# ---------------------------------------------------------------------------
# Test case loading
# ---------------------------------------------------------------------------

def load_test_case(path: Path) -> dict:
    """Load and return a single test case JSON file."""
    with open(path) as f:
        return json.load(f)


def load_all_test_cases(test_cases_dir: Path) -> list[dict]:
    """Load all test case JSON files from the given directory."""
    cases = []
    for p in sorted(test_cases_dir.glob("*.json")):
        try:
            cases.append(load_test_case(p))
        except Exception as e:
            print(f"Warning: could not load test case {p.name}: {e}", file=sys.stderr)
    return cases


def filter_test_cases(
    cases: list[dict],
    agent_file: Optional[str] = None,
    tag: Optional[str] = None,
    test_id: Optional[str] = None,
) -> list[dict]:
    """Return a filtered subset of test cases."""
    result = cases
    if agent_file:
        result = [c for c in result if c.get("agent_file") == agent_file]
    if tag:
        result = [c for c in result if tag in c.get("tags", [])]
    if test_id:
        result = [c for c in result if c.get("id") == test_id]
    return result


# ---------------------------------------------------------------------------
# Baseline loading
# ---------------------------------------------------------------------------

def load_baseline(baseline_path: Path) -> Optional[dict]:
    """Load a baseline file, returning None if it does not exist."""
    if not baseline_path.exists():
        return None
    with open(baseline_path) as f:
        return json.load(f)


def get_baseline_path(config: dict, test_id: str) -> Path:
    """Return the expected baseline file path for the given test ID."""
    baselines_dir = resolve_config_path(config["baselines_dir"])
    return baselines_dir / f"{test_id}.json"


# ---------------------------------------------------------------------------
# Agent file hashing
# ---------------------------------------------------------------------------

def hash_agent_file(agent_file_path: str) -> Optional[str]:
    """
    Compute a SHA-256 hex digest of the agent file at the given path.
    Returns None if the file cannot be found.
    """
    path = Path(agent_file_path)
    if not path.exists():
        # Try resolving relative to common base directories
        for base in [Path.cwd(), get_plugin_root().parent]:
            candidate = base / agent_file_path
            if candidate.exists():
                path = candidate
                break
        else:
            return None

    sha256 = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            sha256.update(chunk)
    return sha256.hexdigest()


# ---------------------------------------------------------------------------
# Tribunal availability check
# ---------------------------------------------------------------------------

def check_tribunal_available() -> bool:
    """
    Return True if the Tribunal plugin appears to be installed.

    Checks for the presence of Tribunal agent files in common install locations.
    This is a heuristic — actual availability is confirmed at runtime when
    spawning Tribunal subagents.
    """
    candidates = [
        Path.home() / ".claude" / "plugins" / "tribunal",
        Path.cwd() / ".claude" / "plugins" / "tribunal",
        Path.cwd() / ".claude" / "skills" / "tribunal",
        Path.home() / ".claude" / "skills" / "tribunal",
    ]
    return any(p.exists() for p in candidates)


def require_tribunal():
    """Exit with a clear error if Tribunal is not installed."""
    if not check_tribunal_available():
        print(
            "Echo requires Tribunal. Install with: /plugin install tribunal",
            file=sys.stderr,
        )
        sys.exit(1)


# ---------------------------------------------------------------------------
# Run log writing
# ---------------------------------------------------------------------------

def get_run_log_dir(config: dict) -> Path:
    """Return the run log directory, creating it if necessary."""
    log_dir = Path(os.path.expanduser(config.get("run_log_dir", "~/.claude/echo/runs")))
    log_dir.mkdir(parents=True, exist_ok=True)
    return log_dir


def write_run_log(config: dict, run_data: dict) -> Path:
    """Write a run log JSON file and return its path."""
    log_dir = get_run_log_dir(config)
    timestamp = datetime.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    log_path = log_dir / f"{timestamp}.json"
    with open(log_path, "w") as f:
        json.dump(run_data, f, indent=2)
    return log_path


# ---------------------------------------------------------------------------
# Onlooker event emission
# ---------------------------------------------------------------------------

def emit_onlooker_event(config: dict, event_type: str, payload: dict):
    """
    Emit an event to the Onlooker ingest endpoint if Onlooker is enabled.

    Fails silently — Onlooker integration is optional and must not block tests.
    """
    onlooker_cfg = config.get("onlooker", {})
    if not onlooker_cfg.get("enabled", False):
        return

    endpoint = onlooker_cfg.get("endpoint", "http://localhost:3000/ingest")
    workspace_id = onlooker_cfg.get("workspaceId", "echo")

    event = {
        "type": event_type,
        "workspaceId": workspace_id,
        "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
        "payload": payload,
    }

    try:
        import urllib.request
        import urllib.error
        data = json.dumps(event).encode("utf-8")
        req = urllib.request.Request(
            endpoint,
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            pass  # fire-and-forget; response ignored
    except Exception:
        pass  # Onlooker is optional; never propagate errors
