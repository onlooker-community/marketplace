#!/usr/bin/env bash
# Shared utilities for Counsel scripts and hooks.
#
# Source this file: source "$(dirname "$0")/utils.sh"
# Or from hooks:    source "$CLAUDE_PLUGIN_ROOT/scripts/utils.sh"

set -euo pipefail

COUNSEL_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------

counsel_get_config() {
    local config_path="$COUNSEL_PLUGIN_ROOT/config.json"
    local defaults='{"enabled":true,"schedule":{"day":"monday","min_days_between_runs":6,"auto_run_on_session_start":true},"sources":{"onlooker_events":"~/.claude/logs/onlooker-events.jsonl","sentinel_audit":"~/.claude/sentinel/audit.jsonl","oracle_audit":"~/.claude/oracle/audit.jsonl","warden_audit":"~/.claude/warden/audit.jsonl","tribunal_verdicts":"~/.claude/tribunal/verdicts","echo_baselines":"~/.claude/echo/runs","archivist_sessions":"~/.claude/archivist/sessions"},"lore":{"enabled":true},"output_dir":"~/.claude/counsel","last_run_file":"~/.claude/counsel/last-run.json","lookback_days":7,"max_events_per_source":500,"brief_format":"layer-attributed"}'

    if [[ -f "$config_path" ]]; then
        jq -s '.[0] * .[1]' <(echo "$defaults") "$config_path" 2>/dev/null || echo "$defaults"
    else
        echo "$defaults"
    fi
}

counsel_config_get() {
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

counsel_resolve_path() {
    local path="$1"
    path="${path/#\~/$HOME}"
    echo "$path"
}

counsel_get_output_dir() {
    local config
    config="$(counsel_get_config)"
    local path
    path="$(counsel_config_get "$config" '.output_dir' '~/.claude/counsel')"
    path="$(counsel_resolve_path "$path")"
    mkdir -p "$path/briefs"
    echo "$path"
}

counsel_get_last_run_path() {
    local config
    config="$(counsel_get_config)"
    local path
    path="$(counsel_config_get "$config" '.last_run_file' '~/.claude/counsel/last-run.json')"
    path="$(counsel_resolve_path "$path")"
    mkdir -p "$(dirname "$path")"
    echo "$path"
}

# ---------------------------------------------------------------------------
# Schedule checking
# ---------------------------------------------------------------------------

counsel_should_run() {
    local config
    config="$(counsel_get_config)"

    local auto_run
    auto_run="$(counsel_config_get "$config" '.schedule.auto_run_on_session_start' 'true')"
    if [[ "$auto_run" != "true" ]]; then
        return 1
    fi

    local min_days
    min_days="$(counsel_config_get "$config" '.schedule.min_days_between_runs' '6')"

    local last_run_path
    last_run_path="$(counsel_get_last_run_path)"

    if [[ ! -f "$last_run_path" ]]; then
        # Never run before — should run
        return 0
    fi

    local last_run_ts
    last_run_ts="$(jq -r '.timestamp // ""' "$last_run_path" 2>/dev/null)" || last_run_ts=""

    if [[ -z "$last_run_ts" ]]; then
        return 0
    fi

    # Calculate days since last run
    local now_epoch last_epoch days_since
    now_epoch="$(date +%s)"

    if [[ "$(uname)" == "Darwin" ]]; then
        last_epoch="$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_run_ts" +%s 2>/dev/null)" || return 0
    else
        last_epoch="$(date -d "$last_run_ts" +%s 2>/dev/null)" || return 0
    fi

    days_since=$(( (now_epoch - last_epoch) / 86400 ))

    if [[ "$days_since" -ge "$min_days" ]]; then
        return 0
    fi

    return 1
}

counsel_update_last_run() {
    local last_run_path
    last_run_path="$(counsel_get_last_run_path)"

    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    jq -n --arg ts "$timestamp" '{timestamp: $ts}' > "$last_run_path" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Source file resolution
# ---------------------------------------------------------------------------

counsel_resolve_sources() {
    local config
    config="$(counsel_get_config)"

    echo "$config" | jq -r '.sources | to_entries[] | "\(.key)=\(.value)"' | while IFS='=' read -r key path; do
        local resolved
        resolved="$(counsel_resolve_path "$path")"
        echo "$key=$resolved"
    done
}

counsel_source_status() {
    local source_path="$1"
    local lookback_days="${2:-7}"

    if [[ -f "$source_path" ]]; then
        local line_count
        line_count="$(wc -l < "$source_path" 2>/dev/null | tr -d ' ')" || line_count="0"
        echo "file:${line_count} entries"
    elif [[ -d "$source_path" ]]; then
        local file_count
        file_count="$(find "$source_path" -type f -name "*.json" 2>/dev/null | wc -l | tr -d ' ')" || file_count="0"
        echo "dir:${file_count} files"
    else
        echo "missing"
    fi
}
