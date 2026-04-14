#!/usr/bin/env bash
set -euo pipefail

# escalate-friction.sh - Escalate friction patterns on session start
# Reads friction events and surfaces repeated issues
#
# Called by: SessionStart hook
# Output: hookSpecificOutput.context with friction summary if threshold exceeded

EVENTS_FILE="$HOME/.claude/cues/cue-events.jsonl"
FRICTION_THRESHOLD=3
LOOKBACK_HOURS=24

if [[ ! -f "$EVENTS_FILE" ]]; then
    exit 0
fi

# Calculate cutoff timestamp
if command -v gdate &>/dev/null; then
    # macOS with GNU date
    CUTOFF=$(gdate -u -d "${LOOKBACK_HOURS} hours ago" +%Y-%m-%dT%H:%M:%SZ)
else
    # Linux or BSD date
    CUTOFF=$(date -u -v-${LOOKBACK_HOURS}H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
             date -u -d "${LOOKBACK_HOURS} hours ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
             echo "1970-01-01T00:00:00Z")
fi

# Count friction events by cue_id in recent window
friction_counts=$(jq -r --arg cutoff "$CUTOFF" '
    select(.event_type == "cue_fired" and .timestamp >= $cutoff) |
    .payload.cue_id
' "$EVENTS_FILE" 2>/dev/null | sort | uniq -c | sort -rn)

if [[ -z "$friction_counts" ]]; then
    exit 0
fi

# Find cues exceeding threshold
escalated=()
while read -r count cue_id; do
    if [[ -n "$cue_id" && $count -ge $FRICTION_THRESHOLD ]]; then
        escalated+=("$cue_id ($count hits)")
    fi
done <<< "$friction_counts"

if [[ ${#escalated[@]} -eq 0 ]]; then
    exit 0
fi

# Build escalation context
context="# Repeated Friction Detected

The following cues have fired repeatedly in the last ${LOOKBACK_HOURS} hours:

$(printf -- '- %s\n' "${escalated[@]}")

This may indicate:
- Recurring issues that need root cause analysis
- Cues that are too sensitive (adjust triggers)
- Patterns worth discussing with the user"

jq -n --arg context "$context" '{hookSpecificOutput: {context: $context}}'
