#!/usr/bin/env bash
set -euo pipefail

# clear-cue-markers.sh - Clear cue markers on session start
# Removes /tmp/.claude-cue-* markers to reset once-per-session gating
#
# Called by: SessionStart hook

SESSION_ID="${CLAUDE_SESSION_ID:-default}"

# Remove markers for this session (or all markers on fresh start)
if [[ "$SESSION_ID" != "default" ]]; then
    rm -f /tmp/.claude-cue-*-"${SESSION_ID}" 2>/dev/null || true
else
    # On resume without session ID, clear all markers
    rm -f /tmp/.claude-cue-* 2>/dev/null || true
fi

exit 0
