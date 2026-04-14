#!/usr/bin/env bash
set -euo pipefail

# cue-injector-file.sh - Cue injector for Write/Edit operations
# Matches file paths against cues with files: triggers
#
# Called by: PreToolUse (Write|Edit) hook
# Input: Hook input JSON via stdin
# Output: hookSpecificOutput.context with matched cue content

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read hook input
INPUT=$(cat)

if [[ -z "$INPUT" ]]; then
    exit 0
fi

# Extract file path from tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Get matched cues for this file
MATCHED_CUES=$("$SCRIPT_DIR/match-cues.sh" "file" "$FILE_PATH" 2>/dev/null || echo "[]")

if [[ "$MATCHED_CUES" == "[]" || -z "$MATCHED_CUES" ]]; then
    exit 0
fi

# Collect cue content from all matches
cue_output=""

while IFS= read -r cue_path; do
    if [[ -z "$cue_path" ]]; then
        continue
    fi

    content=$("$SCRIPT_DIR/show-cue.sh" "$cue_path" "file" 2>/dev/null || true)
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
