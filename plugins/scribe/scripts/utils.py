"""Shared utilities for Scribe scripts."""

import json
import os
from pathlib import Path
from typing import Optional


def get_config() -> dict:
    """Load Scribe config, falling back to defaults."""
    config_path = Path(__file__).parent.parent / "config.json"
    defaults = {
        "output_dir": "docs/scribe",
        "capture_dir": "~/.claude/scribe/captures",
        "min_captures_for_stop_distill": 3,
        "skip_trivial": True,
        "skip_paths": ["node_modules/", ".git/", "*.lock", "*.min.js"],
        "archivist_integration": True,
        "archivist_session_dir": "~/.claude/archivist/sessions",
    }
    try:
        with open(config_path) as f:
            config = json.load(f)
        for key, value in defaults.items():
            config.setdefault(key, value)
        return config
    except (FileNotFoundError, json.JSONDecodeError):
        return defaults


def get_capture_dir() -> Path:
    """Resolve the capture directory, creating it if needed."""
    config = get_config()
    path = Path(os.path.expanduser(config["capture_dir"]))
    path.mkdir(parents=True, exist_ok=True)
    return path


def get_output_dir(cwd: str) -> Path:
    """Resolve the output directory relative to cwd, creating it if needed."""
    config = get_config()
    path = Path(cwd) / config["output_dir"]
    path.mkdir(parents=True, exist_ok=True)
    (path / "changes").mkdir(exist_ok=True)
    (path / "decisions").mkdir(exist_ok=True)
    return path


def capture_file_path(session_id: str) -> Path:
    """Return the JSONL capture file path for a session."""
    return get_capture_dir() / f"{session_id}.jsonl"


def read_captures(session_id: str) -> list[dict]:
    """Read all capture entries for a session."""
    path = capture_file_path(session_id)
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
                    entry = json.loads(line)
                    if not entry.get("trivial"):
                        entries.append(entry)
                except json.JSONDecodeError:
                    continue
    except (OSError, PermissionError):
        pass
    return entries


def append_capture(session_id: str, entry: dict) -> None:
    """Append a capture entry to the session's JSONL file. Silent on failure."""
    try:
        path = capture_file_path(session_id)
        with open(path, "a") as f:
            f.write(json.dumps(entry) + "\n")
    except Exception:
        pass


def should_skip_path(file_path: str) -> bool:
    """Check if a file path matches any skip pattern."""
    config = get_config()
    import fnmatch

    for pattern in config.get("skip_paths", []):
        if fnmatch.fnmatch(file_path, pattern) or pattern in file_path:
            return True
    return False


def find_archivist_session(session_id: str) -> Optional[dict]:
    """Read Archivist session file if it exists. Returns None if not found."""
    config = get_config()
    if not config.get("archivist_integration", True):
        return None

    session_dir = Path(os.path.expanduser(
        config.get("archivist_session_dir", "~/.claude/archivist/sessions")
    ))

    session_file = session_dir / f"{session_id}.json"
    if not session_file.exists():
        return None

    try:
        with open(session_file) as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return None


def find_undistilled_sessions() -> list[str]:
    """Find all session IDs with undistilled captures."""
    capture_dir = get_capture_dir()
    if not capture_dir.exists():
        return []

    sessions = []
    for path in capture_dir.glob("*.jsonl"):
        session_id = path.stem
        captures = read_captures(session_id)
        if captures and not all(c.get("distilled") for c in captures):
            sessions.append(session_id)
    return sessions


def load_template(name: str) -> str:
    """Load a template file by name."""
    template_path = Path(__file__).parent.parent / "templates" / name
    try:
        with open(template_path) as f:
            return f.read()
    except (FileNotFoundError, OSError):
        return ""


def mark_session_distilled(session_id: str) -> None:
    """Mark all captures in a session as distilled. Silent on failure."""
    try:
        path = capture_file_path(session_id)
        if not path.exists():
            return

        entries = []
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    entry["distilled"] = True
                    entries.append(entry)
                except json.JSONDecodeError:
                    entries.append({"raw": line, "distilled": True})

        with open(path, "w") as f:
            for entry in entries:
                f.write(json.dumps(entry) + "\n")
    except Exception:
        pass
