#!/usr/bin/env bash
set -euo pipefail

# cue-injector.sh - Main cue injector for UserPromptSubmit
# Matches user prompt against cues and injects matched cue content
#
# Called by: UserPromptSubmit hook
# Input: CLAUDE_USER_PROMPT (user's prompt text)
# Output: hookSpecificOutput.context with matched cue content

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT="${CLAUDE_USER_PROMPT:-}"

if [[ -z "$PROMPT" ]]; then
    exit 0
fi

# Get matched cues
MATCHED_CUES=$("$SCRIPT_DIR/match-cues.sh" "prompt" "$PROMPT" 2>/dev/null || echo "[]")

if [[ "$MATCHED_CUES" == "[]" || -z "$MATCHED_CUES" ]]; then
    exit 0
fi

# Collect cue content from all matches
cue_output=""

while IFS= read -r cue_path; do
    if [[ -z "$cue_path" ]]; then
        continue
    fi

    content=$("$SCRIPT_DIR/show-cue.sh" "$cue_path" "prompt" 2>/dev/null || true)
    if [[ -n "$content" ]]; then
        if [[ -n "$cue_output" ]]; then
            cue_output="${cue_output}

"
        fi
        cue_output="${cue_output}${content}"
    fi
done < <(echo "$MATCHED_CUES" | jq -r '.[]')

if [[ -z "$cue_output" ]]; then
    exit 0
fi

jq -n --arg context "$cue_output" '{hookSpecificOutput: {context: $context}}'
