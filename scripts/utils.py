"""Shared utilities for Archivist scripts."""

import json
import os
from pathlib import Path
from typing import Optional


def get_config() -> dict:
    """Load Archivist config, falling back to defaults."""
    config_path = Path(__file__).parent.parent / "config.json"
    defaults = {
        "storage_path": "~/.claude/archivist/sessions",
        "max_injection_words": 400,
        "inject_on_start": True,
        "extract_on_compact": True,
        "extract_on_end": True,
        "min_confidence_to_inject": "medium",
        "onlooker": {
            "enabled": False,
            "endpoint": "http://localhost:3000/ingest",
            "workspaceId": "archivist",
        },
    }
    try:
        with open(config_path) as f:
            config = json.load(f)
        # Merge with defaults so missing keys don't cause errors
        for key, value in defaults.items():
            config.setdefault(key, value)
        return config
    except (FileNotFoundError, json.JSONDecodeError):
        return defaults


def get_storage_path() -> Path:
    """Resolve the storage path, creating it if needed."""
    config = get_config()
    path = Path(os.path.expanduser(config["storage_path"]))
    path.mkdir(parents=True, exist_ok=True)
    return path


def session_file_path(session_id: str) -> Path:
    """Return the file path for a given session ID."""
    return get_storage_path() / f"{session_id}.json"


def find_sessions_for_cwd(cwd: str) -> list[dict]:
    """Find all session files matching a cwd or its parents.

    A session from /project matches a query for /project/src because
    the session's cwd is a prefix of the query cwd.
    """
    storage = get_storage_path()
    cwd_path = Path(cwd).resolve()
    matches = []

    if not storage.exists():
        return matches

    for file in storage.glob("*.json"):
        session = read_session(file)
        if session is None:
            continue
        session_cwd = Path(session.get("cwd", "")).resolve()
        # Match if session cwd is the same as or a parent of the query cwd
        try:
            cwd_path.relative_to(session_cwd)
            matches.append(session)
        except ValueError:
            continue

    # Sort by timestamp, most recent first
    matches.sort(key=lambda s: s.get("timestamp", ""), reverse=True)
    return matches


def find_most_recent_session(cwd: str) -> Optional[dict]:
    """Find the most recent session for a cwd."""
    sessions = find_sessions_for_cwd(cwd)
    return sessions[0] if sessions else None


def read_session(path: Path) -> Optional[dict]:
    """Read a session JSON file, returning None on any error."""
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError, PermissionError):
        return None


def write_session(session_id: str, data: dict) -> Path:
    """Write a session extract to storage. Returns the file path."""
    path = session_file_path(session_id)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
    return path
