#!/usr/bin/env bash
set -euo pipefail

# cue-task-stash.sh - Stash task context for cue matching
# Captures task metadata when Task tool is used
#
# Called by: PreToolUse (Task) hook
# Input: Hook input JSON via stdin
# Output: Stashes task info for later cue correlation

# Read hook input
INPUT=$(cat)

if [[ -z "$INPUT" ]]; then
    exit 0
fi

# Extract task details
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [[ "$TOOL_NAME" != "Task"* ]]; then
    exit 0
fi

# Extract task input parameters
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.tool_input.subject // empty')
TASK_DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // empty')
TASK_STATUS=$(echo "$INPUT" | jq -r '.tool_input.status // empty')
TASK_ID=$(echo "$INPUT" | jq -r '.tool_input.taskId // empty')

# Stash current task context for correlation
STASH_DIR="/tmp/.claude-cue-task-stash"
mkdir -p "$STASH_DIR"

SESSION_ID="${CLAUDE_SESSION_ID:-default}"
STASH_FILE="${STASH_DIR}/${SESSION_ID}.json"

# Build stash entry
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

jq -n \
    --arg timestamp "$TIMESTAMP" \
    --arg tool_name "$TOOL_NAME" \
    --arg subject "$TASK_SUBJECT" \
    --arg description "$TASK_DESCRIPTION" \
    --arg status "$TASK_STATUS" \
    --arg task_id "$TASK_ID" \
    '{
        timestamp: $timestamp,
        tool_name: $tool_name,
        subject: $subject,
        description: $description,
        status: $status,
        task_id: $task_id
    }' >> "$STASH_FILE"

exit 0
