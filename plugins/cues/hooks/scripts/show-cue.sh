#!/usr/bin/env bash
set -euo pipefail

# show-cue.sh - Display matched cue and emit engagement event
#
# Usage: show-cue.sh <cue_path> <trigger_type>
#   cue_path: Path to the cue.md file
#   trigger_type: prompt | command | file
#
# Outputs cue content (with macro if applicable) and emits cue_fired event

CUE_PATH="${1:-}"
TRIGGER_TYPE="${2:-prompt}"

if [[ -z "$CUE_PATH" || ! -f "$CUE_PATH" ]]; then
    exit 0
fi

CUE_DIR=$(dirname "$CUE_PATH")
CUE_ID=$(basename "$CUE_DIR")

# Extract field from YAML frontmatter
extract_field() {
    local file="$1"
    local field="$2"

    sed -n '/^---$/,/^---$/p' "$file" 2>/dev/null | \
        grep -E "^${field}:" | \
        sed "s/^${field}:[[:space:]]*//" | \
        tr -d '"'"'" || true
}

# Extract cue body (content after second ---)
extract_body() {
    local file="$1"
    awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$file"
}

# Mark cue as fired for this session
mark_fired() {
    local marker="/tmp/.claude-cue-${CUE_ID}-${CLAUDE_SESSION_ID:-default}"
    touch "$marker"
}

# Emit engagement event
emit_event() {
    local events_file="$HOME/.claude/cues/cue-events.jsonl"
    local has_macro="false"

    if [[ -f "${CUE_DIR}/macro.sh" ]]; then
        has_macro="true"
    fi

    mkdir -p "$(dirname "$events_file")"

    local event
    event=$(jq -n \
        --arg event_type "cue_fired" \
        --arg cue_id "$CUE_ID" \
        --arg trigger_type "$TRIGGER_TYPE" \
        --argjson has_macro "$has_macro" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            event_type: $event_type,
            timestamp: $timestamp,
            payload: {
                cue_id: $cue_id,
                trigger_type: $trigger_type,
                has_macro: $has_macro
            }
        }')

    echo "$event" >> "$events_file"
}

# Get macro content if applicable
get_macro_content() {
    local macro_type
    macro_type=$(extract_field "$CUE_PATH" "macro")

    if [[ -z "$macro_type" ]]; then
        return
    fi

    local macro_script="${CUE_DIR}/macro.sh"
    if [[ ! -x "$macro_script" ]]; then
        return
    fi

    local macro_output
    macro_output=$("$macro_script" 2>/dev/null || true)

    if [[ -n "$macro_output" ]]; then
        echo "$macro_type|$macro_output"
    fi
}

# Build output
build_output() {
    local body
    body=$(extract_body "$CUE_PATH")

    local macro_result
    macro_result=$(get_macro_content)

    if [[ -z "$macro_result" ]]; then
        echo "$body"
        return
    fi

    local macro_type macro_content
    macro_type=$(echo "$macro_result" | cut -d'|' -f1)
    macro_content=$(echo "$macro_result" | cut -d'|' -f2-)

    case "$macro_type" in
        prepend)
            printf '%s\n\n%s' "$macro_content" "$body"
            ;;
        append)
            printf '%s\n\n%s' "$body" "$macro_content"
            ;;
        *)
            echo "$body"
            ;;
    esac
}

# Main execution
mark_fired
emit_event

# Output the cue content
build_output
