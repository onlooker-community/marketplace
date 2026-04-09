#!/usr/bin/env bash
set -euo pipefail

# Warden gate — PreToolUse hook for Write, Edit, and Bash.
# Checks the gate state and blocks action if an injection signal is active.
# Requires explicit user clearance (/warden:gate clear) to re-open.
# Must never crash — fail open on errors.

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

hook_register "warden-gate"

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
# READ GATE STATE
# ============================================================================

STATE=$(warden_read_state)
GATE_OPEN=$(echo "$STATE" | jq -r '.gateOpen // true')
INJECTION_DETECTED=$(echo "$STATE" | jq -r '.injectionSignalDetected // false')
COOLDOWN=$(echo "$STATE" | jq -r '.cooldownRemaining // 0')

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null) || TOOL_NAME=""

# ============================================================================
# CHECK AUTO-CLEAR / COOLDOWN
# ============================================================================

AUTO_CLEAR=$(warden_config_get "$CONFIG" '.auto_clear' 'false')

if [[ "$GATE_OPEN" == "true" ]]; then
    # Gate is open — decrement cooldown if active, allow through
    if [[ "$COOLDOWN" -gt 0 ]]; then
        NEW_COOLDOWN=$((COOLDOWN - 1))
        STATE=$(echo "$STATE" | jq --argjson cd "$NEW_COOLDOWN" '.cooldownRemaining = $cd')
        warden_write_state "$STATE"
    fi

    warden_audit_write "gate" "$TOOL_NAME" "allow"
    hook_success
    exit 0
fi

# ============================================================================
# GATE IS CLOSED — BLOCK THE ACTION
# ============================================================================

PATTERN_ID=$(echo "$STATE" | jq -r '.injectionPattern // "unknown"')
INJECTION_SOURCE=$(echo "$STATE" | jq -r '.injectionSource // "unknown"')

# Emit telemetry
safe_emit "warden_gate_event" "$(jq -nc \
    --arg tool "$TOOL_NAME" \
    --arg decision "block" \
    --arg pattern "$PATTERN_ID" \
    '{tool: $tool, gate_decision: $decision, injection_signal: $pattern, cooldown_remaining: 0}')" 2>/dev/null || true

# Audit log
warden_audit_write "gate" "$TOOL_NAME" "block" "$PATTERN_ID" "Gate closed — injection signal active from $INJECTION_SOURCE"

# Block the action
REASON="Warden gate is CLOSED. A prompt injection pattern (${PATTERN_ID}) was detected in content from ${INJECTION_SOURCE}. Run /warden:gate clear to re-open after reviewing the content."
echo "$REASON" >&2
exit 2
