#!/usr/bin/env bash
# Shared utilities for Warden scripts and hooks.
#
# Source this file: source "$(dirname "$0")/utils.sh"
# Or from hooks:    source "$CLAUDE_PLUGIN_ROOT/scripts/utils.sh"

set -euo pipefail

WARDEN_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------

warden_get_config() {
    local config_path="$WARDEN_PLUGIN_ROOT/config.json"
    local defaults='{"enabled":true,"audit_log":"~/.claude/warden/audit.jsonl","state_file":"~/.claude/warden/gate-state.json","scan_tools":["WebFetch","Read"],"gate_tools":["Write","Edit","Bash"],"auto_clear":false,"cooldown_turns":0,"safe_paths":["/tmp","~/.claude/archivist","~/.claude/logs"],"max_content_scan_bytes":102400}'

    if [[ -f "$config_path" ]]; then
        jq -s '.[0] * .[1]' <(echo "$defaults") "$config_path" 2>/dev/null || echo "$defaults"
    else
        echo "$defaults"
    fi
}

warden_config_get() {
    local config="$1"
    local key="$2"
    local default="${3:-}"
    local val
    val="$(echo "$config" | jq -r "$key // empty")"
    echo "${val:-$default}"
}

# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------

warden_resolve_path() {
    local path="$1"
    path="${path/#\~/$HOME}"
    echo "$path"
}

warden_get_audit_path() {
    local config
    config="$(warden_get_config)"
    local path
    path="$(warden_config_get "$config" '.audit_log' '~/.claude/warden/audit.jsonl')"
    path="$(warden_resolve_path "$path")"
    mkdir -p "$(dirname "$path")"
    echo "$path"
}

warden_get_state_path() {
    local config
    config="$(warden_get_config)"
    local path
    path="$(warden_config_get "$config" '.state_file' '~/.claude/warden/gate-state.json')"
    path="$(warden_resolve_path "$path")"
    mkdir -p "$(dirname "$path")"
    echo "$path"
}

# ---------------------------------------------------------------------------
# Gate state management
# ---------------------------------------------------------------------------

warden_default_state() {
    jq -n '{
        lastFetchedTool: null,
        injectionSignalDetected: false,
        injectionPattern: null,
        injectionSource: null,
        gateOpen: true,
        cooldownRemaining: 0,
        lastUpdated: null
    }'
}

warden_read_state() {
    local state_path
    state_path="$(warden_get_state_path)"
    if [[ -f "$state_path" ]]; then
        cat "$state_path" 2>/dev/null || warden_default_state
    else
        warden_default_state
    fi
}

warden_write_state() {
    local state="$1"
    local state_path
    state_path="$(warden_get_state_path)"

    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    echo "$state" | jq --arg ts "$timestamp" '. + {lastUpdated: $ts}' > "$state_path" 2>/dev/null || true
}

warden_clear_state() {
    warden_write_state "$(warden_default_state)"
}

# ---------------------------------------------------------------------------
# Pattern loading
# ---------------------------------------------------------------------------

warden_load_patterns() {
    local patterns_dir="$WARDEN_PLUGIN_ROOT/patterns"
    local all_patterns="[]"

    if [[ ! -d "$patterns_dir" ]]; then
        echo "$all_patterns"
        return
    fi

    for pattern_file in "$patterns_dir"/*.json; do
        [[ -f "$pattern_file" ]] || continue
        local data
        data="$(cat "$pattern_file" 2>/dev/null)" || continue
        echo "$data" | jq -e '.' >/dev/null 2>&1 || continue

        local category
        category="$(echo "$data" | jq -r '.category // empty')"
        [[ -z "$category" ]] && category="$(basename "$pattern_file" .json)"

        all_patterns="$(echo "$data" | jq --arg cat "$category" --argjson existing "$all_patterns" \
            '$existing + [.patterns[]? | . + {"_category": $cat}]')"
    done

    echo "$all_patterns"
}

# ---------------------------------------------------------------------------
# Content scanning
# ---------------------------------------------------------------------------

warden_scan_content() {
    local content="$1"
    local patterns="$2"
    local matches="[]"
    local count
    count="$(echo "$patterns" | jq 'length')"

    local i=0
    while [[ $i -lt $count ]]; do
        local regex
        regex="$(echo "$patterns" | jq -r ".[$i].regex // empty")"
        if [[ -n "$regex" ]]; then
            # Case-insensitive regex match against content
            if echo "$content" | grep -iqP "$regex" 2>/dev/null || echo "$content" | grep -iqE "$regex" 2>/dev/null; then
                matches="$(echo "$patterns" | jq --argjson idx "$i" --argjson m "$matches" '$m + [.[$idx]]')"
            fi
        fi
        ((i++))
    done

    echo "$matches"
}

warden_highest_severity() {
    local matches="$1"
    local count
    count="$(echo "$matches" | jq 'length')"

    if [[ "$count" -eq 0 ]]; then
        echo "null"
        return
    fi

    echo "$matches" | jq '
        def severity_order:
            if . == "critical" then 0
            elif . == "high" then 1
            elif . == "medium" then 2
            else 3
            end;
        sort_by(.severity | severity_order) | first
    '
}

# ---------------------------------------------------------------------------
# Safe path checking
# ---------------------------------------------------------------------------

warden_is_safe_path() {
    local file_path="$1"
    local config
    config="$(warden_get_config)"
    local safe_paths
    safe_paths="$(echo "$config" | jq -r '.safe_paths // [] | .[]')"

    while IFS= read -r safe_path; do
        [[ -z "$safe_path" ]] && continue
        local expanded
        expanded="$(warden_resolve_path "$safe_path")"
        if [[ "$file_path" == "$expanded"* ]]; then
            return 0
        fi
    done <<< "$safe_paths"

    return 1
}

# ---------------------------------------------------------------------------
# Audit logging
# ---------------------------------------------------------------------------

warden_audit_write() {
    local event_type="$1"
    local tool_name="$2"
    local decision="$3"
    local pattern_id="${4:-}"
    local detail="${5:-}"

    local audit_path
    audit_path="$(warden_get_audit_path)" || return 0

    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    jq -nc \
        --arg ts "$timestamp" \
        --arg event "$event_type" \
        --arg tool "$tool_name" \
        --arg decision "$decision" \
        --arg pattern "$pattern_id" \
        --arg detail "$detail" \
        '{
            timestamp: $ts,
            event: $event,
            tool: $tool,
            decision: $decision,
            pattern_matched: (if $pattern == "" then null else $pattern end),
            detail: (if $detail == "" then null else $detail end)
        }' >> "$audit_path" 2>/dev/null || true
}
