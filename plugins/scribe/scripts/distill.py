#!/usr/bin/env python3
"""Scribe distillation engine.

Reads capture entries, optionally enriches with Archivist context,
and produces documentation artifacts in the configured output directory.

Invoked by Stop/SessionEnd hooks or manually via /scribe:distill.
Must never raise exceptions or block session end.
"""

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

from utils import (
    find_archivist_session,
    find_undistilled_sessions,
    get_config,
    get_output_dir,
    load_template,
    mark_session_distilled,
    read_captures,
)


def build_change_log(
    session_id: str,
    captures: list[dict],
    archivist_session: dict | None,
    cwd: str,
) -> str:
    """Build a change log Markdown document from captures."""
    date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    session_short = session_id[:8] if len(session_id) > 8 else session_id

    lines = [
        f"# Changes: {date}",
        "",
        f"_Session: {session_short} · {len(captures)} files · {cwd}_",
        "",
    ]

    # Group captures by tags for a narrative structure
    by_tag: dict[str, list[dict]] = {}
    for cap in captures:
        for tag in cap.get("tags", ["other"]):
            by_tag.setdefault(tag, []).append(cap)

    # Write intents as narrative
    seen_files: set[str] = set()
    for cap in captures:
        file_path = cap.get("file", "unknown")
        if file_path in seen_files:
            continue
        seen_files.add(file_path)

        intent = cap.get("intent", "")
        decision = cap.get("decision")
        tradeoffs = cap.get("tradeoffs")

        if intent:
            lines.append(f"**`{file_path}`** — {intent}")
            if decision:
                lines.append(f"  Decision: {decision}")
            if tradeoffs:
                lines.append(f"  Tradeoffs: {tradeoffs}")
            lines.append("")

    # Incorporate Archivist dead ends if present
    if archivist_session:
        dead_ends = archivist_session.get("dead_ends", [])
        if dead_ends:
            lines.append("## Approaches tried and abandoned")
            lines.append("")
            for de in dead_ends:
                approach = de.get("approach", "")
                why = de.get("why_failed", "")
                if approach:
                    lines.append(f"- **{approach}** — {why}")
            lines.append("")

    # File list summary
    lines.append("## Files changed")
    lines.append("")
    for cap in captures:
        file_path = cap.get("file", "unknown")
        intent = cap.get("intent", "")
        lines.append(f"- `{file_path}` — {intent}")
    lines.append("")

    return "\n".join(lines)


def extract_decisions(
    captures: list[dict],
    archivist_session: dict | None,
) -> list[dict]:
    """Extract significant decisions from captures and Archivist context."""
    decisions = []

    for cap in captures:
        decision = cap.get("decision")
        if decision and cap.get("tradeoffs"):
            decisions.append({
                "file": cap.get("file", ""),
                "decision": decision,
                "tradeoffs": cap.get("tradeoffs", ""),
                "intent": cap.get("intent", ""),
            })

    # Enrich with Archivist decisions
    if archivist_session:
        for dec in archivist_session.get("decisions", []):
            if dec.get("confidence") == "high":
                decisions.append({
                    "file": "",
                    "decision": dec.get("rule", ""),
                    "tradeoffs": dec.get("rationale", ""),
                    "intent": "Archivist-captured decision",
                    "source": "archivist",
                })

    return decisions


def build_decision_doc(decision: dict, date: str, session_short: str) -> str:
    """Build a decision document section."""
    lines = [
        f"## {date} (Session: {session_short})",
        "",
        f"**Decision:** {decision.get('decision', '')}",
        "",
    ]

    tradeoffs = decision.get("tradeoffs", "")
    if tradeoffs:
        lines.append(f"**Tradeoffs:** {tradeoffs}")
        lines.append("")

    intent = decision.get("intent", "")
    if intent:
        lines.append(f"**Context:** {intent}")
        lines.append("")

    file_path = decision.get("file", "")
    if file_path:
        lines.append(f"**File:** `{file_path}`")
        lines.append("")

    return "\n".join(lines)


def slugify(text: str) -> str:
    """Convert text to a URL-safe slug."""
    import re
    slug = text.lower().strip()
    slug = re.sub(r"[^\w\s-]", "", slug)
    slug = re.sub(r"[\s_]+", "-", slug)
    slug = re.sub(r"-+", "-", slug)
    return slug[:60]


def distill_session(session_id: str, cwd: str, trigger: str = "manual") -> None:
    """Distill a single session's captures into documentation."""
    config = get_config()
    captures = read_captures(session_id)

    if not captures:
        return

    # On stop trigger, respect minimum captures threshold
    if trigger == "stop":
        min_captures = config.get("min_captures_for_stop_distill", 3)
        if len(captures) < min_captures:
            return

    # Find Archivist context
    archivist_session = find_archivist_session(session_id)

    # Build change log
    change_log = build_change_log(session_id, captures, archivist_session, cwd)

    date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    session_short = session_id[:8] if len(session_id) > 8 else session_id

    # Write change log
    output_dir = get_output_dir(cwd)
    change_log_path = output_dir / "changes" / f"{date}-{session_short}.md"

    try:
        with open(change_log_path, "w") as f:
            f.write(change_log)
    except OSError:
        pass

    # Extract and write decision docs
    decisions = extract_decisions(captures, archivist_session)
    for decision in decisions:
        decision_text = decision.get("decision", "")
        if not decision_text:
            continue

        slug = slugify(decision_text[:50])
        if not slug:
            continue

        decision_path = output_dir / "decisions" / f"{slug}.md"
        doc_section = build_decision_doc(decision, date, session_short)

        try:
            if decision_path.exists():
                # Append to existing decision doc
                with open(decision_path, "a") as f:
                    f.write("\n---\n\n" + doc_section)
            else:
                # Create new decision doc
                title = decision_text[:80]
                header = f"# {title}\n\n"
                with open(decision_path, "w") as f:
                    f.write(header + doc_section)
        except OSError:
            pass

    # Update index
    index_path = output_dir / "index.md"
    summary = captures[0].get("intent", "Session changes") if captures else "Session changes"
    index_line = f"- [{date} — {summary}](changes/{date}-{session_short}.md)\n"

    try:
        if not index_path.exists():
            with open(index_path, "w") as f:
                f.write("# Scribe Documentation Index\n\n")

        with open(index_path, "a") as f:
            f.write(index_line)
    except OSError:
        pass

    # Mark session as distilled
    mark_session_distilled(session_id)


def main() -> None:
    trigger = "manual"
    session_id = None
    distill_all = False
    cwd = os.getcwd()

    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--trigger" and i + 1 < len(args):
            trigger = args[i + 1]
            i += 2
        elif args[i] == "--session" and i + 1 < len(args):
            session_id = args[i + 1]
            i += 2
        elif args[i] == "--all":
            distill_all = True
            i += 1
        elif args[i] == "--cwd" and i + 1 < len(args):
            cwd = args[i + 1]
            i += 2
        else:
            i += 1

    try:
        if distill_all:
            for sid in find_undistilled_sessions():
                distill_session(sid, cwd, trigger)
        elif session_id:
            distill_session(session_id, cwd, trigger)
        else:
            # Try to find current session from environment or most recent
            sessions = find_undistilled_sessions()
            if sessions:
                distill_session(sessions[-1], cwd, trigger)
    except Exception:
        # Never crash — fail silently
        pass


if __name__ == "__main__":
    main()
