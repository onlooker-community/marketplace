#!/usr/bin/env bash
# Shared utilities for Echo scripts.
#
# Provides: test case loading, baseline loading, agent file hashing,
# Tribunal availability check, Onlooker event emission, run log writing.
#
# Source this file from other scripts: source "$(dirname "$0")/utils.sh"

set -euo pipefail

# ---------------------------------------------------------------------------
# Plugin root resolution
# ---------------------------------------------------------------------------

get_plugin_root() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$(cd "$script_dir/.." && pwd)"
}

PLUGIN_ROOT="$(get_plugin_root)"

resolve_config_path() {
    local path_str="$1"
    path_str="${path_str//\$\{CLAUDE_PLUGIN_ROOT\}/$PLUGIN_ROOT}"
    path_str="${path_str/#\~/$HOME}"
    echo "$path_str"
}

# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------

load_config() {
    local config_path="$PLUGIN_ROOT/config.json"
    if [[ ! -f "$config_path" ]]; then
        echo "Echo config not found at $config_path" >&2
        return 1
    fi
    cat "$config_path"
}

# Config accessor helpers (call load_config once, then use these)
config_get() {
    local config="$1"
    local key="$2"
    local default="${3:-}"
    local val
    val="$(echo "$config" | jq -r "$key // empty")"
    echo "${val:-$default}"
}

# ---------------------------------------------------------------------------
# Test case loading
# ---------------------------------------------------------------------------

load_test_case() {
    local path="$1"
    cat "$path"
}

load_all_test_cases() {
    local test_cases_dir="$1"
    local cases="[]"
    local file
    for file in "$test_cases_dir"/*.json; do
        [[ -f "$file" ]] || continue
        local tc
        tc="$(cat "$file" 2>/dev/null)" || {
            echo "Warning: could not load test case $(basename "$file")" >&2
            continue
        }
        cases="$(echo "$cases" | jq --argjson tc "$tc" '. + [$tc]')"
    done
    echo "$cases"
}

filter_test_cases() {
    local cases="$1"
    local agent_file="${2:-}"
    local tag="${3:-}"
    local test_id="${4:-}"

    local result="$cases"

    if [[ -n "$agent_file" ]]; then
        result="$(echo "$result" | jq --arg af "$agent_file" '[.[] | select(.agent_file == $af)]')"
    fi
    if [[ -n "$tag" ]]; then
        result="$(echo "$result" | jq --arg t "$tag" '[.[] | select(.tags // [] | index($t))]')"
    fi
    if [[ -n "$test_id" ]]; then
        result="$(echo "$result" | jq --arg id "$test_id" '[.[] | select(.id == $id)]')"
    fi

    echo "$result"
}

# ---------------------------------------------------------------------------
# Baseline loading
# ---------------------------------------------------------------------------

load_baseline() {
    local baseline_path="$1"
    if [[ ! -f "$baseline_path" ]]; then
        echo "null"
        return
    fi
    cat "$baseline_path"
}

get_baseline_path() {
    local config="$1"
    local test_id="$2"
    local baselines_dir
    baselines_dir="$(resolve_config_path "$(config_get "$config" '.baselines_dir' '${CLAUDE_PLUGIN_ROOT}/baselines')")"
    echo "$baselines_dir/$test_id.json"
}

# ---------------------------------------------------------------------------
# Agent file hashing
# ---------------------------------------------------------------------------

hash_agent_file() {
    local agent_file_path="$1"
    local path="$agent_file_path"

    if [[ ! -f "$path" ]]; then
        # Try resolving relative to common base directories
        if [[ -f "$(pwd)/$agent_file_path" ]]; then
            path="$(pwd)/$agent_file_path"
        elif [[ -f "$PLUGIN_ROOT/../$agent_file_path" ]]; then
            path="$PLUGIN_ROOT/../$agent_file_path"
        else
            echo ""
            return
        fi
    fi

    shasum -a 256 "$path" | awk '{print $1}'
}

# ---------------------------------------------------------------------------
# Tribunal availability check
# ---------------------------------------------------------------------------

check_tribunal_available() {
    local candidates=(
        "$HOME/.claude/plugins/tribunal"
        "$(pwd)/.claude/plugins/tribunal"
        "$(pwd)/.claude/skills/tribunal"
        "$HOME/.claude/skills/tribunal"
    )
    for candidate in "${candidates[@]}"; do
        if [[ -e "$candidate" ]]; then
            return 0
        fi
    done
    return 1
}

require_tribunal() {
    if ! check_tribunal_available; then
        echo "Echo requires Tribunal. Install with: /plugin install tribunal" >&2
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Run log writing
# ---------------------------------------------------------------------------

get_run_log_dir() {
    local config="$1"
    local log_dir
    log_dir="$(config_get "$config" '.run_log_dir' '~/.claude/echo/runs')"
    log_dir="${log_dir/#\~/$HOME}"
    mkdir -p "$log_dir"
    echo "$log_dir"
}

write_run_log() {
    local config="$1"
    local run_data="$2"
    local log_dir
    log_dir="$(get_run_log_dir "$config")"
    local timestamp
    timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
    local log_path="$log_dir/$timestamp.json"
    echo "$run_data" | jq '.' > "$log_path"
    echo "$log_path"
}

# ---------------------------------------------------------------------------
# Onlooker event emission
# ---------------------------------------------------------------------------

emit_onlooker_event() {
    local config="$1"
    local event_type="$2"
    local payload="$3"

    local enabled
    enabled="$(config_get "$config" '.onlooker.enabled' 'false')"
    if [[ "$enabled" != "true" ]]; then
        return
    fi

    local endpoint
    endpoint="$(config_get "$config" '.onlooker.endpoint' 'http://localhost:3000/ingest')"
    local workspace_id
    workspace_id="$(config_get "$config" '.onlooker.workspaceId' 'echo')"

    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    local event
    event="$(jq -n \
        --arg type "$event_type" \
        --arg ws "$workspace_id" \
        --arg ts "$timestamp" \
        --argjson payload "$payload" \
        '{type: $type, workspaceId: $ws, timestamp: $ts, payload: $payload}')"

    # Fire-and-forget; Onlooker is optional and must not block tests
    curl -s -X POST "$endpoint" \
        -H "Content-Type: application/json" \
        -d "$event" \
        --max-time 5 \
        >/dev/null 2>&1 || true
}
