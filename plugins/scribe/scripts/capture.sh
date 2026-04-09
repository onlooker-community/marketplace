#!/usr/bin/env bash
# Scribe capture script — fallback for environments without agent hook support.
#
# Reads PostToolUse JSON from stdin, extracts file path and change type,
# and appends a capture entry to the session's JSONL file.
#
# Must never raise exceptions or block file operations.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

extract_capture_from_stdin() {
    local raw
    raw="$(cat)" || return 0

    [[ -z "${raw// /}" ]] && return 0

    local data
    data="$(echo "$raw" | jq -c '.' 2>/dev/null)" || return 0

    # Extract file path from tool input
    local file_path
    file_path="$(echo "$data" | jq -r '.tool_input.file_path // ""')"
    [[ -z "$file_path" ]] && return 0

    # Check skip paths
    if should_skip_path "$file_path"; then
        return 0
    fi

    # Determine change type
    local tool_name change_type
    tool_name="$(echo "$data" | jq -r '.tool_name // ""')"
    if [[ "$tool_name" == "Write" ]]; then
        change_type="created"
    else
        change_type="modified"
    fi

    # Extract session ID
    local session_id
    session_id="$(echo "$data" | jq -r '.session_id // "unknown"')"

    # Check if change is trivially small
    local config
    config="$(get_config)"
    local skip_trivial
    skip_trivial="$(scribe_config_get "$config" '.skip_trivial' 'true')"
    if [[ "$skip_trivial" == "true" ]]; then
        local tool_response
        tool_response="$(echo "$data" | jq -r '.tool_response // ""')"
        local response_len=${#tool_response}
        if [[ "$response_len" -lt 3 ]]; then
            return 0
        fi
    fi

    # Build a minimal capture entry (without LLM enrichment)
    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    local entry
    entry="$(jq -n \
        --arg timestamp "$timestamp" \
        --arg file "$file_path" \
        --arg change_type "$change_type" \
        '{
            timestamp: $timestamp,
            file: $file,
            change_type: $change_type,
            intent: null,
            decision: null,
            tradeoffs: null,
            follow_up: null,
            tags: [],
            source: "fallback"
        }')"

    append_capture "$session_id" "$entry"
}

# Main — never surface errors
extract_capture_from_stdin 2>/dev/null || true
