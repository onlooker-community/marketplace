#!/usr/bin/env bash
set -euo pipefail

# cue-followup-tracker.sh - Track followups after tool use
# Detects patterns in tool results that may warrant cue-driven guidance
#
# Called by: PostToolUse hook
# Input: Hook input JSON via stdin
# Output: hookSpecificOutput.context with followup suggestions if applicable

# Read hook input
INPUT=$(cat)

if [[ -z "$INPUT" ]]; then
    exit 0
fi

# Extract tool info
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TOOL_RESULT=$(echo "$INPUT" | jq -r '.tool_result // empty')

if [[ -z "$TOOL_NAME" ]]; then
    exit 0
fi

# Track events to events file
EVENTS_FILE="$HOME/.claude/cues/cue-events.jsonl"
mkdir -p "$(dirname "$EVENTS_FILE")"

# Detect patterns that warrant tracking

# Pattern 1: File operations with potential issues
followup_context=""

case "$TOOL_NAME" in
    "Write"|"Edit")
        # Check for file creation/modification
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')
        if [[ -n "$FILE_PATH" ]]; then
            # Track file modification
            event=$(jq -n \
                --arg event_type "file_modified" \
                --arg tool_name "$TOOL_NAME" \
                --arg file_path "$FILE_PATH" \
                --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                '{event_type: $event_type, timestamp: $timestamp, payload: {tool_name: $tool_name, file_path: $file_path}}')
            echo "$event" >> "$EVENTS_FILE"
        fi
        ;;

    "Bash")
        COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
        EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_result.exit_code // 0')

        # Track command failures
        if [[ "$EXIT_CODE" != "0" ]]; then
            event=$(jq -n \
                --arg event_type "command_failed" \
                --arg command "$COMMAND" \
                --argjson exit_code "$EXIT_CODE" \
                --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                '{event_type: $event_type, timestamp: $timestamp, payload: {command: $command, exit_code: $exit_code}}')
            echo "$event" >> "$EVENTS_FILE"

            # Check for common failure patterns
            result_lower=$(echo "$TOOL_RESULT" | tr '[:upper:]' '[:lower:]')

            if [[ "$result_lower" == *"file not found"* || "$result_lower" == *"no such file"* ]]; then
                followup_context="# File Not Found Pattern

The command failed with a file-not-found error. Consider:
- Verify the file path with Glob before operating
- Check if the file was created by a previous step
- Ensure you're in the correct directory"
            elif [[ "$result_lower" == *"permission denied"* ]]; then
                followup_context="# Permission Denied Pattern

The command failed due to permissions. Consider:
- Check if the path is in an allowed directory
- Verify file/directory ownership
- Ask the user if elevated access is needed"
            elif [[ "$result_lower" == *"command not found"* ]]; then
                followup_context="# Missing Command Pattern

The command was not found. Consider:
- Check if the tool is installed
- Verify the PATH includes the tool's location
- Suggest installation if appropriate"
            fi
        fi

        # Track git operations
        if [[ "$COMMAND" == *"git "* ]]; then
            event=$(jq -n \
                --arg event_type "git_operation" \
                --arg command "$COMMAND" \
                --argjson exit_code "${EXIT_CODE:-0}" \
                --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                '{event_type: $event_type, timestamp: $timestamp, payload: {command: $command, exit_code: $exit_code}}')
            echo "$event" >> "$EVENTS_FILE"
        fi
        ;;

    "Task"*)
        # Track task operations
        TASK_ID=$(echo "$INPUT" | jq -r '.tool_input.taskId // empty')
        STATUS=$(echo "$INPUT" | jq -r '.tool_input.status // empty')

        if [[ -n "$STATUS" ]]; then
            event=$(jq -n \
                --arg event_type "task_status_change" \
                --arg task_id "$TASK_ID" \
                --arg status "$STATUS" \
                --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                '{event_type: $event_type, timestamp: $timestamp, payload: {task_id: $task_id, status: $status}}')
            echo "$event" >> "$EVENTS_FILE"
        fi
        ;;
esac

# Output followup context if any
if [[ -n "$followup_context" ]]; then
    jq -n --arg context "$followup_context" '{hookSpecificOutput: {context: $context}}'
fi

exit 0
