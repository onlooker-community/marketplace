#!/usr/bin/env bash
set -euo pipefail

# cue-injector-bash.sh - Cue injector for Bash commands
# Matches bash commands against cues with commands: triggers
#
# Called by: PreToolUse (Bash) hook
# Input: Hook input JSON via stdin
# Output: hookSpecificOutput.context with matched cue content

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read hook input
INPUT=$(cat)

if [[ -z "$INPUT" ]]; then
    exit 0
fi

# Extract command from tool input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# Get matched cues for this command
MATCHED_CUES=$("$SCRIPT_DIR/match-cues.sh" "command" "$COMMAND" 2>/dev/null || echo "[]")

if [[ "$MATCHED_CUES" == "[]" || -z "$MATCHED_CUES" ]]; then
    exit 0
fi

# Collect cue content from all matches
cue_output=""

while IFS= read -r cue_path; do
    if [[ -z "$cue_path" ]]; then
        continue
    fi

    content=$("$SCRIPT_DIR/show-cue.sh" "$cue_path" "command" 2>/dev/null || true)
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
