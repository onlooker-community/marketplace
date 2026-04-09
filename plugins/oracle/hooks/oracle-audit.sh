#!/usr/bin/env bash
set -euo pipefail

# Oracle audit logger — records every Oracle invocation to the audit JSONL.
# Runs as a command hook alongside Oracle's prompt hooks.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source Onlooker's shared utilities for health monitoring and path helpers
ONLOOKER_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT%/*}/../onlooker/0.4.0"
if [[ -f "$ONLOOKER_PLUGIN_ROOT/hooks/validate-path.sh" ]]; then
  # shellcheck source=/dev/null
  source "$ONLOOKER_PLUGIN_ROOT/hooks/validate-path.sh"
else
  # Minimal fallbacks if Onlooker isn't installed
  ensure_dir_exists() { mkdir -p "$1" 2>/dev/null; }
  ensure_file_exists() { local d; d=$(dirname "$1"); mkdir -p "$d" 2>/dev/null && touch "$1" 2>/dev/null; }
  hook_register() { :; }
  hook_set_context() { :; }
  hook_success() { :; }
  hook_failure() { :; }
  safe_emit() { :; }
fi

hook_register "oracle-audit"

INPUT=$(cat)
hook_set_context "$INPUT"

# ============================================================================
# EXTRACT EVENT METADATA
# ============================================================================

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null) || SESSION_ID="unknown"
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null) || TOOL_NAME=""
HOOK_EVENT="${_HOOK_EVENT:-unknown}"

# Determine trigger label
if [[ -n "$TOOL_NAME" ]]; then
  TRIGGER="PreToolUse:${TOOL_NAME}"
else
  TRIGGER="UserPromptSubmit"
fi

# Extract a brief input summary (first 200 chars of arguments, for context)
INPUT_SUMMARY=$(echo "$INPUT" | jq -r '
  (.tool_input // .input // .arguments // "") | tostring | .[0:200]
' 2>/dev/null) || INPUT_SUMMARY=""

# ============================================================================
# RESOLVE AUDIT LOG PATH FROM CONFIG
# ============================================================================

CONFIG_FILE="$CLAUDE_PLUGIN_ROOT/config.json"
AUDIT_LOG_RAW=$(jq -r '.audit_log // "~/.claude/oracle/audit.jsonl"' "$CONFIG_FILE" 2>/dev/null) || AUDIT_LOG_RAW="~/.claude/oracle/audit.jsonl"

# Expand ~ to $HOME
AUDIT_LOG="${AUDIT_LOG_RAW/#\~/$HOME}"

ensure_dir_exists "$(dirname "$AUDIT_LOG")" || {
  hook_failure "Failed to create audit log directory"
  exit 0
}

ensure_file_exists "$AUDIT_LOG" || {
  hook_failure "Failed to create audit log file"
  exit 0
}

# ============================================================================
# WRITE AUDIT ENTRY
# ============================================================================

jq -nc \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg sid "$SESSION_ID" \
  --arg trigger "$TRIGGER" \
  --arg tool "$TOOL_NAME" \
  --arg summary "$INPUT_SUMMARY" \
  '{
    timestamp: $ts,
    session_id: $sid,
    trigger: $trigger,
    tool_name: (if $tool == "" then null else $tool end),
    input_summary: (if $summary == "" then null else $summary end)
  }' >> "$AUDIT_LOG" 2>/dev/null || {
  hook_failure "Failed to write audit entry"
  exit 0
}

# Emit telemetry event for Onlooker aggregation
safe_emit "oracle_invocation" "$(jq -nc \
  --arg trigger "$TRIGGER" \
  --arg tool "$TOOL_NAME" \
  '{trigger: $trigger, tool_name: $tool}')" 2>/dev/null || true

hook_success
exit 0
