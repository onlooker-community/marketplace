#!/usr/bin/env bash
set -euo pipefail

# Warden content scanner — PostToolUse hook for WebFetch and Read.
# Scans retrieved content for indirect prompt injection patterns.
# On detection: closes the gate, logs the event, emits telemetry.
# Must never block or crash — fail open on errors.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source Onlooker's shared utilities for health monitoring
ONLOOKER_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT%/*}/../onlooker/0.5.0"
if [[ -f "$ONLOOKER_PLUGIN_ROOT/hooks/validate-path.sh" ]]; then
  # shellcheck source=/dev/null
  source "$ONLOOKER_PLUGIN_ROOT/hooks/validate-path.sh"
else
  ensure_dir_exists() { mkdir -p "$1" 2>/dev/null; }
  ensure_file_exists() { local d; d=$(dirname "$1"); mkdir -p "$d" 2>/dev/null && touch "$1" 2>/dev/null; }
  hook_register() { :; }
  hook_set_context() { :; }
  hook_success() { :; }
  hook_failure() { :; }
  safe_emit() { :; }
fi

# Source Warden utilities
source "$CLAUDE_PLUGIN_ROOT/scripts/utils.sh"

hook_register "warden-scan"

INPUT=$(cat)
hook_set_context "$INPUT"

# ============================================================================
# CHECK IF ENABLED
# ============================================================================

CONFIG=$(warden_get_config)
ENABLED=$(warden_config_get "$CONFIG" '.enabled' 'true')
if [[ "$ENABLED" != "true" ]]; then
    hook_success
    exit 0
fi

# ============================================================================
# EXTRACT TOOL OUTPUT
# ============================================================================

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null) || TOOL_NAME=""
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null) || SESSION_ID="unknown"

# Get file path if this was a Read operation
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null) || FILE_PATH=""

# Check safe paths — skip scanning content from safe locations
if [[ -n "$FILE_PATH" ]] && warden_is_safe_path "$FILE_PATH"; then
    hook_success
    exit 0
fi

# Extract the content that was retrieved (tool response)
CONTENT=$(echo "$INPUT" | jq -r '.tool_response // ""' 2>/dev/null) || CONTENT=""

if [[ -z "$CONTENT" ]]; then
    hook_success
    exit 0
fi

# Truncate content to configured max scan size
MAX_BYTES=$(warden_config_get "$CONFIG" '.max_content_scan_bytes' '102400')
CONTENT="${CONTENT:0:$MAX_BYTES}"

# ============================================================================
# SCAN CONTENT AGAINST PATTERNS
# ============================================================================

PATTERNS=$(warden_load_patterns)
MATCHES=$(warden_scan_content "$CONTENT" "$PATTERNS")
MATCH_COUNT=$(echo "$MATCHES" | jq 'length')

if [[ "$MATCH_COUNT" -eq 0 ]]; then
    # No injection detected — update state to record last fetch tool
    STATE=$(warden_read_state)
    STATE=$(echo "$STATE" | jq --arg tool "$TOOL_NAME" '. + {lastFetchedTool: $tool}')
    warden_write_state "$STATE"

    warden_audit_write "scan" "$TOOL_NAME" "allow" "" "${FILE_PATH:-url}"
    hook_success
    exit 0
fi

# ============================================================================
# INJECTION DETECTED — CLOSE THE GATE
# ============================================================================

TOP_MATCH=$(warden_highest_severity "$MATCHES")
PATTERN_ID=$(echo "$TOP_MATCH" | jq -r '.id // "unknown"')
PATTERN_DESC=$(echo "$TOP_MATCH" | jq -r '.description // "Injection pattern matched"')
SEVERITY=$(echo "$TOP_MATCH" | jq -r '.severity // "high"')

# Read current config for cooldown
COOLDOWN_TURNS=$(warden_config_get "$CONFIG" '.cooldown_turns' '0')

# Close the gate
STATE=$(jq -n \
    --arg tool "$TOOL_NAME" \
    --arg pattern "$PATTERN_ID" \
    --arg source "${FILE_PATH:-url}" \
    --argjson cooldown "$COOLDOWN_TURNS" \
    '{
        lastFetchedTool: $tool,
        injectionSignalDetected: true,
        injectionPattern: $pattern,
        injectionSource: $source,
        gateOpen: false,
        cooldownRemaining: $cooldown
    }')
warden_write_state "$STATE"

# Audit log
warden_audit_write "scan" "$TOOL_NAME" "block" "$PATTERN_ID" "$PATTERN_DESC"

# Emit telemetry for Onlooker
safe_emit "warden_gate_event" "$(jq -nc \
    --arg tool "$TOOL_NAME" \
    --arg decision "block" \
    --arg pattern "$PATTERN_ID" \
    --arg severity "$SEVERITY" \
    --argjson cooldown "$COOLDOWN_TURNS" \
    '{tool: $tool, gate_decision: $decision, injection_signal: $pattern, severity: $severity, cooldown_remaining: $cooldown}')" 2>/dev/null || true

# Print warning to stderr (visible to user)
echo "WARNING: Warden detected a potential prompt injection pattern in content from ${TOOL_NAME}." >&2
echo "Pattern: ${PATTERN_ID} — ${PATTERN_DESC}" >&2
echo "The content gate is now CLOSED. Write, Edit, and Bash operations are blocked." >&2
echo "Run /warden:gate clear to re-open after reviewing the content." >&2

hook_success
exit 0
