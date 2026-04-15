#!/usr/bin/env bash
# Counsel data gatherer — collects recent events from all plugin data sources.
#
# Reads events from Onlooker, Tribunal, Echo, Sentinel, Warden, Oracle,
# Archivist, and Scribe within the configured lookback window.
#
# Output: a single JSON file with all gathered data, written to stdout
# or to a file path if provided as $1.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
# shellcheck source=lore-invoke.sh
[[ -f "$SCRIPT_DIR/lore-invoke.sh" ]] && source "$SCRIPT_DIR/lore-invoke.sh"

OUTPUT_PATH="${1:-}"

CONFIG=$(counsel_get_config)
LOOKBACK_DAYS=$(counsel_config_get "$CONFIG" '.lookback_days' '7')
MAX_EVENTS=$(counsel_config_get "$CONFIG" '.max_events_per_source' '500')

# Calculate cutoff timestamp
if [[ "$(uname)" == "Darwin" ]]; then
    CUTOFF=$(date -u -v-"${LOOKBACK_DAYS}"d +"%Y-%m-%dT%H:%M:%SZ")
else
    CUTOFF=$(date -u -d "$LOOKBACK_DAYS days ago" +"%Y-%m-%dT%H:%M:%SZ")
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ---------------------------------------------------------------------------
# Helper: read JSONL file, filter by timestamp, take last N entries
# ---------------------------------------------------------------------------

read_jsonl_source() {
    local path="$1"
    local max="$2"
    local cutoff="$3"

    if [[ ! -f "$path" ]]; then
        echo "[]"
        return
    fi

    # Filter entries with timestamp >= cutoff, take last N
    jq -s --arg cutoff "$cutoff" --argjson max "$max" '
        [.[] | select(.timestamp >= $cutoff)] | .[-$max:]
    ' "$path" 2>/dev/null || echo "[]"
}

# ---------------------------------------------------------------------------
# Helper: read JSON files from a directory
# ---------------------------------------------------------------------------

read_dir_source() {
    local dir_path="$1"
    local max="$2"

    if [[ ! -d "$dir_path" ]]; then
        echo "[]"
        return
    fi

    local entries="[]"
    local count=0
    # Process most recent files first
    for file in $(ls -t "$dir_path"/*.json 2>/dev/null | head -n "$max"); do
        local data
        data="$(cat "$file" 2>/dev/null)" || continue
        echo "$data" | jq -e '.' >/dev/null 2>&1 || continue
        entries="$(echo "$entries" | jq --argjson d "$data" '. + [$d]')"
        ((count++))
        [[ $count -ge $max ]] && break
    done

    echo "$entries"
}

# ---------------------------------------------------------------------------
# Gather from all sources
# ---------------------------------------------------------------------------

# Resolve source paths
ONLOOKER_PATH=$(counsel_resolve_path "$(counsel_config_get "$CONFIG" '.sources.onlooker_events' '~/.claude/logs/onlooker-events.jsonl')")
SENTINEL_PATH=$(counsel_resolve_path "$(counsel_config_get "$CONFIG" '.sources.sentinel_audit' '~/.claude/sentinel/audit.jsonl')")
ORACLE_PATH=$(counsel_resolve_path "$(counsel_config_get "$CONFIG" '.sources.oracle_audit' '~/.claude/oracle/audit.jsonl')")
WARDEN_PATH=$(counsel_resolve_path "$(counsel_config_get "$CONFIG" '.sources.warden_audit' '~/.claude/warden/audit.jsonl')")
TRIBUNAL_PATH=$(counsel_resolve_path "$(counsel_config_get "$CONFIG" '.sources.tribunal_verdicts' '~/.claude/tribunal/verdicts')")
ECHO_PATH=$(counsel_resolve_path "$(counsel_config_get "$CONFIG" '.sources.echo_baselines' '~/.claude/echo/runs')")
ARCHIVIST_PATH=$(counsel_resolve_path "$(counsel_config_get "$CONFIG" '.sources.archivist_sessions' '~/.claude/archivist/sessions')")

# Gather each source
ONLOOKER_DATA=$(read_jsonl_source "$ONLOOKER_PATH" "$MAX_EVENTS" "$CUTOFF")
SENTINEL_DATA=$(read_jsonl_source "$SENTINEL_PATH" "$MAX_EVENTS" "$CUTOFF")
ORACLE_DATA=$(read_jsonl_source "$ORACLE_PATH" "$MAX_EVENTS" "$CUTOFF")
WARDEN_DATA=$(read_jsonl_source "$WARDEN_PATH" "$MAX_EVENTS" "$CUTOFF")
TRIBUNAL_DATA=$(read_dir_source "$TRIBUNAL_PATH" "$MAX_EVENTS")
ECHO_DATA=$(read_dir_source "$ECHO_PATH" "$MAX_EVENTS")
ARCHIVIST_DATA=$(read_dir_source "$ARCHIVIST_PATH" "$MAX_EVENTS")

LORE_SNAPSHOT='{}'
if [[ "$(counsel_config_get "$CONFIG" '.lore.enabled' 'true')" == "true" ]] && type lore_cli_run >/dev/null 2>&1; then
    CWD_GATHER="$(pwd -P 2>/dev/null || pwd)"
    LORE_SNAPSHOT="$(lore_cli_run export-for-brief --cwd "$CWD_GATHER" --since "$CUTOFF" 2>/dev/null)" || LORE_SNAPSHOT='{}'
    if ! echo "$LORE_SNAPSHOT" | jq -e . >/dev/null 2>&1; then
        LORE_SNAPSHOT='{}'
    fi
fi

# Assemble gathered data
GATHERED=$(jq -n \
    --arg ts "$TIMESTAMP" \
    --arg cutoff "$CUTOFF" \
    --argjson lookback "$LOOKBACK_DAYS" \
    --argjson onlooker "$ONLOOKER_DATA" \
    --argjson sentinel "$SENTINEL_DATA" \
    --argjson oracle "$ORACLE_DATA" \
    --argjson warden "$WARDEN_DATA" \
    --argjson tribunal "$TRIBUNAL_DATA" \
    --argjson echo_data "$ECHO_DATA" \
    --argjson archivist "$ARCHIVIST_DATA" \
    --argjson lore_snap "$LORE_SNAPSHOT" \
    '{
        gathered_at: $ts,
        lookback_cutoff: $cutoff,
        lookback_days: $lookback,
        sources: {
            onlooker: {count: ($onlooker | length), events: $onlooker},
            sentinel: {count: ($sentinel | length), events: $sentinel},
            oracle: {count: ($oracle | length), events: $oracle},
            warden: {count: ($warden | length), events: $warden},
            tribunal: {count: ($tribunal | length), events: $tribunal},
            echo: {count: ($echo_data | length), events: $echo_data},
            archivist: {count: ($archivist | length), events: $archivist},
            lore: {
                count: (($lore_snap.top_questions // []) | length),
                snapshot: $lore_snap
            }
        }
    }')

if [[ -n "$OUTPUT_PATH" ]]; then
    echo "$GATHERED" | jq '.' > "$OUTPUT_PATH"
    echo "$OUTPUT_PATH"
else
    echo "$GATHERED" | jq '.'
fi
