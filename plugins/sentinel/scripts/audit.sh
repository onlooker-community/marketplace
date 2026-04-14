#!/usr/bin/env bash
# Sentinel audit log writer and reader.
#
# Writes structured audit entries to JSONL. Provides read path for
# /sentinel:guard audit command. Write failures are always silent —
# never block execution or propagate exceptions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# ---------------------------------------------------------------------------
# Write an audit entry
# ---------------------------------------------------------------------------

write_entry() {
    local session_id="$1"
    local cwd="$2"
    local command="$3"
    local risk_level="$4"
    local decision="$5"
    local reason="${6:-}"
    local pattern_matched="${7:-}"

    # Truncate command to 200 chars
    local truncated_command="${command:0:200}"

    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    local entry
    entry="$(jq -n \
        --arg ts "$timestamp" \
        --arg sid "$session_id" \
        --arg cwd "$cwd" \
        --arg cmd "$truncated_command" \
        --arg risk "$risk_level" \
        --arg dec "$decision" \
        --arg reason "$reason" \
        --arg pat "$pattern_matched" \
        '{
            timestamp: $ts,
            session_id: $sid,
            cwd: $cwd,
            command: $cmd,
            risk_level: $risk,
            decision: $dec,
            reason: $reason,
            pattern_matched: $pat
        }')" || return 0

    local path
    path="$(get_audit_path)" || return 0

    echo "$entry" | jq -c '.' >> "$path" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Read audit entries
# ---------------------------------------------------------------------------

read_entries() {
    local count="${1:-20}"
    local path
    path="$(get_audit_path)"

    if [[ ! -f "$path" ]]; then
        echo "[]"
        return
    fi

    local entries="[]"
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local entry
        entry="$(echo "$line" | jq -c '.' 2>/dev/null)" || continue
        entries="$(echo "$entries" | jq --argjson e "$entry" '. + [$e]')"
    done < "$path" 2>/dev/null || true

    # Return last N entries
    echo "$entries" | jq --argjson n "$count" '.[-$n:]'
}

# ---------------------------------------------------------------------------
# Main — CLI interface
# ---------------------------------------------------------------------------

main() {
    case "${1:-}" in
        --write)
            # Read entry from stdin JSON
            local raw
            raw="$(cat)" || return 0
            local data
            data="$(echo "$raw" | jq -c '.' 2>/dev/null)" || return 0

            write_entry \
                "$(echo "$data" | jq -r '.session_id // ""')" \
                "$(echo "$data" | jq -r '.cwd // ""')" \
                "$(echo "$data" | jq -r '.command // ""')" \
                "$(echo "$data" | jq -r '.risk_level // ""')" \
                "$(echo "$data" | jq -r '.decision // ""')" \
                "$(echo "$data" | jq -r '.reason // ""')" \
                "$(echo "$data" | jq -r '.pattern_matched // ""')"
            ;;
        --read)
            local count=20
            if [[ "${2:-}" == "--count" && -n "${3:-}" ]]; then
                count="$3"
            fi
            read_entries "$count"
            ;;
        *)
            read_entries
            ;;
    esac
}

# Never block execution on audit failures
main "$@" 2>/dev/null || true
