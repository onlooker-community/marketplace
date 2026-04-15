#!/usr/bin/env bash
# Shared utilities for Scribe scripts.
#
# Source this file from other scripts: source "$(dirname "$0")/utils.sh"

set -euo pipefail

SCRIBE_PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------

get_config() {
    local config_path="$SCRIBE_PLUGIN_ROOT/config.json"
    local defaults='{"output_dir":"docs/scribe","capture_dir":"~/.claude/scribe/captures","min_captures_for_stop_distill":3,"skip_trivial":true,"skip_paths":["node_modules/",".git/","*.lock","*.min.js"],"archivist_integration":true,"archivist_session_dir":"~/.claude/archivist/sessions","lore_enabled":true}'

    if [[ -f "$config_path" ]]; then
        # Merge defaults with config (config values take precedence)
        jq -s '.[0] * .[1]' <(echo "$defaults") "$config_path" 2>/dev/null || echo "$defaults"
    else
        echo "$defaults"
    fi
}

scribe_config_get() {
    local config="$1"
    local key="$2"
    local default="${3:-}"
    local val
    val="$(echo "$config" | jq -r "$key // empty")"
    echo "${val:-$default}"
}

# ---------------------------------------------------------------------------
# Directory helpers
# ---------------------------------------------------------------------------

get_capture_dir() {
    local config
    config="$(get_config)"
    local path
    path="$(scribe_config_get "$config" '.capture_dir' '~/.claude/scribe/captures')"
    path="${path/#\~/$HOME}"
    mkdir -p "$path"
    echo "$path"
}

get_output_dir() {
    local cwd="$1"
    local config
    config="$(get_config)"
    local output_dir
    output_dir="$(scribe_config_get "$config" '.output_dir' 'docs/scribe')"
    local path="$cwd/$output_dir"
    mkdir -p "$path/changes" "$path/decisions"
    echo "$path"
}

# ---------------------------------------------------------------------------
# Capture file helpers
# ---------------------------------------------------------------------------

capture_file_path() {
    local session_id="$1"
    echo "$(get_capture_dir)/$session_id.jsonl"
}

read_captures() {
    local session_id="$1"
    local path
    path="$(capture_file_path "$session_id")"

    if [[ ! -f "$path" ]]; then
        echo "[]"
        return
    fi

    # Read JSONL, filter out trivial entries, collect into array
    local entries="[]"
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local entry
        entry="$(echo "$line" | jq -c '.' 2>/dev/null)" || continue
        local trivial
        trivial="$(echo "$entry" | jq -r '.trivial // false')"
        if [[ "$trivial" != "true" ]]; then
            entries="$(echo "$entries" | jq --argjson e "$entry" '. + [$e]')"
        fi
    done < "$path" 2>/dev/null || true

    echo "$entries"
}

append_capture() {
    local session_id="$1"
    local entry="$2"
    local path
    path="$(capture_file_path "$session_id")" 2>/dev/null || return 0
    echo "$entry" | jq -c '.' >> "$path" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Skip path checking
# ---------------------------------------------------------------------------

should_skip_path() {
    local file_path="$1"
    local config
    config="$(get_config)"

    local patterns
    patterns="$(echo "$config" | jq -r '.skip_paths // [] | .[]')"

    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        # Check if pattern appears in the path (substring match)
        if [[ "$file_path" == *"$pattern"* ]]; then
            return 0
        fi
        # Check glob match using bash pattern matching
        # shellcheck disable=SC2254
        case "$file_path" in
            $pattern) return 0 ;;
        esac
    done <<< "$patterns"

    return 1
}

# ---------------------------------------------------------------------------
# Archivist integration
# ---------------------------------------------------------------------------

find_archivist_session() {
    local session_id="$1"
    local config
    config="$(get_config)"

    local enabled
    enabled="$(scribe_config_get "$config" '.archivist_integration' 'true')"
    if [[ "$enabled" != "true" ]]; then
        echo "null"
        return
    fi

    local session_dir
    session_dir="$(scribe_config_get "$config" '.archivist_session_dir' '~/.claude/archivist/sessions')"
    session_dir="${session_dir/#\~/$HOME}"

    local session_file="$session_dir/$session_id.json"
    if [[ ! -f "$session_file" ]]; then
        echo "null"
        return
    fi

    cat "$session_file" 2>/dev/null || echo "null"
}

# ---------------------------------------------------------------------------
# Undistilled session discovery
# ---------------------------------------------------------------------------

find_undistilled_sessions() {
    local capture_dir
    capture_dir="$(get_capture_dir)"

    if [[ ! -d "$capture_dir" ]]; then
        echo "[]"
        return
    fi

    local sessions="[]"
    for path in "$capture_dir"/*.jsonl; do
        [[ -f "$path" ]] || continue
        local session_id
        session_id="$(basename "$path" .jsonl)"
        local captures
        captures="$(read_captures "$session_id")"
        local count
        count="$(echo "$captures" | jq 'length')"
        if [[ "$count" -gt 0 ]]; then
            # Check if any are not distilled
            local undistilled
            undistilled="$(echo "$captures" | jq '[.[] | select(.distilled != true)] | length')"
            if [[ "$undistilled" -gt 0 ]]; then
                sessions="$(echo "$sessions" | jq --arg s "$session_id" '. + [$s]')"
            fi
        fi
    done

    echo "$sessions"
}

# ---------------------------------------------------------------------------
# Template loading
# ---------------------------------------------------------------------------

load_template() {
    local name="$1"
    local template_path="$SCRIBE_PLUGIN_ROOT/templates/$name"
    if [[ -f "$template_path" ]]; then
        cat "$template_path"
    fi
}

# ---------------------------------------------------------------------------
# Mark session distilled
# ---------------------------------------------------------------------------

mark_session_distilled() {
    local session_id="$1"
    local path
    path="$(capture_file_path "$session_id")" 2>/dev/null || return 0

    if [[ ! -f "$path" ]]; then
        return 0
    fi

    local tmp_file="${path}.tmp"
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local entry
        entry="$(echo "$line" | jq -c '. + {distilled: true}' 2>/dev/null)" || {
            entry="$(jq -n --arg raw "$line" '{raw: $raw, distilled: true}')"
        }
        echo "$entry"
    done < "$path" > "$tmp_file" 2>/dev/null || true

    mv "$tmp_file" "$path" 2>/dev/null || true
}
