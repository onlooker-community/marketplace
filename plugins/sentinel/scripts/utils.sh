#!/usr/bin/env bash
# Shared utilities for Sentinel scripts.
#
# Source this file from other scripts: source "$(dirname "$0")/utils.sh"

set -euo pipefail

SENTINEL_PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------

get_config() {
    local config_path="$SENTINEL_PLUGIN_ROOT/config.json"
    local defaults='{"enabled":true,"default_behaviors":{"critical":"block","high":"review","medium":"log","low":"allow"},"session_overrides":{},"audit_log":"~/.claude/sentinel/audit.jsonl","protect_paths":[],"safe_paths":["/tmp","~/.claude/archivist"]}'

    if [[ -f "$config_path" ]]; then
        jq -s '.[0] * .[1]' <(echo "$defaults") "$config_path" 2>/dev/null || echo "$defaults"
    else
        echo "$defaults"
    fi
}

sentinel_config_get() {
    local config="$1"
    local key="$2"
    local default="${3:-}"
    local val
    val="$(echo "$config" | jq -r "$key // empty")"
    echo "${val:-$default}"
}

# ---------------------------------------------------------------------------
# Audit log path
# ---------------------------------------------------------------------------

get_audit_path() {
    local config
    config="$(get_config)"
    local path
    path="$(sentinel_config_get "$config" '.audit_log' '~/.claude/sentinel/audit.jsonl')"
    path="${path/#\~/$HOME}"
    mkdir -p "$(dirname "$path")"
    echo "$path"
}

# ---------------------------------------------------------------------------
# Pattern loading
# ---------------------------------------------------------------------------

load_patterns() {
    local patterns_dir="$SENTINEL_PLUGIN_ROOT/patterns"
    local all_patterns="[]"

    if [[ ! -d "$patterns_dir" ]]; then
        echo "$all_patterns"
        return
    fi

    for pattern_file in "$patterns_dir"/*.json; do
        [[ -f "$pattern_file" ]] || continue
        local data
        data="$(cat "$pattern_file" 2>/dev/null)" || continue
        # Validate JSON
        echo "$data" | jq -e '.' >/dev/null 2>&1 || continue

        local category
        category="$(echo "$data" | jq -r '.category // empty')"
        [[ -z "$category" ]] && category="$(basename "$pattern_file" .json)"

        # Add _category to each pattern and append to all_patterns
        all_patterns="$(echo "$data" | jq --arg cat "$category" --argjson existing "$all_patterns" \
            '$existing + [.patterns[]? | . + {"_category": $cat}]')"
    done

    echo "$all_patterns"
}

# ---------------------------------------------------------------------------
# Path checking
# ---------------------------------------------------------------------------

is_safe_path() {
    local command="$1"
    local config
    config="$(get_config)"
    local safe_paths
    safe_paths="$(echo "$config" | jq -r '.safe_paths // [] | .[]')"

    while IFS= read -r safe_path; do
        [[ -z "$safe_path" ]] && continue
        local expanded="${safe_path/#\~/$HOME}"
        if [[ "$command" == *"$expanded"* ]]; then
            return 0
        fi
    done <<< "$safe_paths"

    return 1
}

is_protected_path() {
    local command="$1"
    local config
    config="$(get_config)"
    local protect_paths
    protect_paths="$(echo "$config" | jq -r '.protect_paths // [] | .[]')"

    while IFS= read -r protected; do
        [[ -z "$protected" ]] && continue
        local expanded="${protected/#\~/$HOME}"
        if [[ "$command" == *"$expanded"* ]]; then
            return 0
        fi
    done <<< "$protect_paths"

    return 1
}
