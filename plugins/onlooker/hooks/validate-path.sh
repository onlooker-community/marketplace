#!/usr/bin/env bash
# validate-path.sh - Shared path validation utilities for Onlooker hooks.
#
# Source this file in hooks to get consistent path handling:
# source "$CLAUDE_PLUGIN_ROOT/hooks/validate-path.sh"
#
# All validation functions return 0 (success) or 1 (failure), never exit.
# All ensure functions create resources if needed and return 0/1.


# ============================================================================
# PATH CONSTANTS (exported for use by scripts that source this file)
# ============================================================================

export CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
export ONLOOKER_EVENTS_LOG="$CLAUDE_HOME/logs/onlooker-events.jsonl"
export ONLOOKER_HOOK_HEALTH_LOG="$CLAUDE_PLUGIN_ROOT/logs/hook-health.jsonl"
export ONLOOKER_EMIT="$CLAUDE_PLUGIN_ROOT/hooks/onlooker-emit.sh"

# ============================================================================
# HOOK HEALTH MONITORING
# ============================================================================

# These functions provide observability into hook execution.
# Usage:
#   source validate-path.sh
#   hook_register "my-hook-name" # Call at start of hook
#   # ... hook logic ...
#   hook_success                 # Call on successful completion (or let trap handle failure)

# Current hook content (set by hook_register)
_HOOK_NAME=""
_HOOK_START_TIME=""

# Extended context (set by hook_set_context)
_HOOK_SESSION_ID=""
_HOOK_EVENT=""
_HOOK_TOOL_NAME=""

# Detect hook event from script path
# Looks for known event directory names in the call stack
_detect_hook_event() {
  local script_path="${BASH_SOURCE[2]:-${BASH_SOURCE[1]:-}}"

  # Known Claude Code hook events
  local events="PreToolUse|PostToolUse|PostToolUseFailure|PermissionRequest|PermissionDenied|SessionStart|SessionEnd|Notification|SubagentStart|PreCompact|PostCompact|SubagentStop|ConfigChange|CwdChanged|FileChanged|StopFailure|InstructionsLoaded|Elicitation|ElicitationResult|UserPromptSubmit|Stop|TeammateIdle|TaskCreated|TaskCompleted|WorktreeCreate|WorktreeRemove"

  if [[ "$script_path" =~ /($events)/ ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo ""
  fi
}

# Set extended context from hook input JSON
# Call this after reading stdin to capture session/tool context
# Usage: hook_set_context "$INPUT"
#    OR: hook_set_context "$INPUT" "PostToolUse"  # explicit event override
hook_set_context() {
  local input="${1:-}"
  local event_override="${2:-}"

  [[ -z "$input" ]] && return 0

  # Extract context from JSON input
  _HOOK_SESSION_ID=$(echo "$input" | jq -r '.session_id // ""' 2>/dev/null) || _HOOK_SESSION_ID=""
  _HOOK_TOOL_NAME=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null) || _HOOK_TOOL_NAME=""

  # Use explicit event or auto-detect from script path
  if [[ -n "$event_override" ]]; then
    _HOOK_EVENT="$event_override"
  else
    _HOOK_EVENT=$(_detect_hook_event)
  fi
}

# Register hook execution start
# Usage: hook_register "hook-name"
hook_register() {
  _HOOK_NAME="${1:-unknown}"
  # Get time in milliseconds (macOS compatible)
  if [[ "$(uname)" == "Darwin" ]]; then
    _HOOK_START_TIME=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || date +%s)
  else
    _HOOK_START_TIME=$(date +%s%3N 2>/dev/null || date +%s)
  fi

  # Set up trap to catch failures
  trap '_hook_on_exit $?' EXIT
}

# Log hook success (call explicitly or let trap determine)
hook_success() {
  _hook_log "success" ""
  trap - EXIT  # Clear trap since we're handling it
}

# Log hook failure with optional error message
# Usage: hook_failure "error message"
hook_failure() {
  local error_msg="${1:-}"
  _hook_log "failure" "$error_msg"
  trap - EXIT
}

# Internal: called by EXIT trap
_hook_on_exit() {
  local exit_code="$1"
  if [[ $exit_code -eq 0 ]]; then
    _hook_log "success" ""
  else
    _hook_log "failure" "exit_code=$exit_code"
  fi
  trap - EXIT
}

# Internal: write to health log
_hook_log() {
  local hook_status="$1"
  local error_msg="$2"

  [[ -z "$_HOOK_NAME" ]] && return 0

  local end_time duration_ms timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Get end time in milliseconds (macOS compatible)
  if [[ "$(uname)" == "Darwin" ]]; then
    end_time=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || date +%s)
  else
    end_time=$(date +%s%3N 2>/dev/null || date +%s)
  fi

  # Calculate duration (handle both ms and s timestamps)
  if [[ ${#_HOOK_START_TIME} -gt 10 && ${#end_time} -gt 10 ]]; then
    duration_ms=$((end_time - _HOOK_START_TIME))
  else
    # Fallback to seconds-based calculation
    duration_ms=0
  fi

  ensure_file_exists "$ONLOOKER_HOOK_HEALTH_LOG" || return 0

  jq -cn \
    --arg ts "$timestamp" \
    --arg hook "$_HOOK_NAME" \
    --arg hook_status "$hook_status" \
    --arg error "$error_msg" \
    --argjson duration "$duration_ms" \
    --arg session_id "$_HOOK_SESSION_ID" \
    --arg hook_event "$_HOOK_EVENT" \
    --arg tool_name "$_HOOK_TOOL_NAME" \
    '{
      timestamp: $ts,
      hook: $hook,
      status: $hook_status,
      duration_ms: $duration,
      error: (if $error == "" then null else $error end),
      session_id: (if $session_id == "" then null else $session_id end),
      hook_event: (if $hook_event == "" then null else $hook_event end),
      tool_name: (if $tool_name == "" then null else $tool_name end)
    }' \
    >> "$ONLOOKER_HOOK_HEALTH_LOG" 2>/dev/null

  # Reset context
  _HOOK_NAME=""
  _HOOK_START_TIME=""
  _HOOK_SESSION_ID=""
  _HOOK_EVENT=""
  _HOOK_TOOL_NAME=""
}

# Get hook health summary for last N hours
# Usage: health=$(hook_health_summary 24)
# Returns JSON with success/failure counts per hook
hook_health_summary() {
  local hours="${1:-24}"
  local cutoff_time

  if ! validate_file_readable "$ONLOOKER_HOOK_HEALTH_LOG"; then
    echo '{}'
    return 0
  fi

  # Calculate cutoff timestamp
  if [[ "$(uname)" == "Darwin" ]]; then
    cutoff_time=$(date -u -v-"${hours}"H +"%Y-%m-%dT%H:%M:%SZ")
  else
    cutoff_time=$(date -u -d "$hours hours ago" +"%Y-%m-%dT%H:%M:%SZ")
  fi

  jq -s --arg cutoff "$cutoff_time" '
    map(select(.timestamp >= $cutoff))
    | group_by(.hook)
    | map({
        hook: .[0].hook,
        total: length,
        success: map(select(.status == "success")) | length,
        failure: map(select(.status == "failure")) | length,
        avg_duration_ms: (map(.duration_ms) | add / length | floor),
        last_error: (map(select(.error != null)) | last | .error // null)
      })
    | sort_by(-.failure)
  ' "$ONLOOKER_HOOK_HEALTH_LOG" 2>/dev/null || echo '[]'
}

# ============================================================================
# HOOK COMPOSITION BUS
# ============================================================================
# Lightweight mechanism for hooks within the same event invocation to share
# structured JSON findings. Each tool call gets a unique bus directory;
# hooks write named JSON files that later hooks can read.
#
# IMPORTANT: Hooks within the same `hooks` array run in PARALLEL.
# For reliable producer→consumer flow, place them in separate matcher
# entries in hooks.jsonc (matcher entries run sequentially).
#
# Usage (producer):
#   hook_bus_init "$INPUT"
#   hook_bus_put "secret-scanner" '{"found": true, "patterns": ["AWS key"]}'
#
# Usage (consumer):
#   hook_bus_init "$INPUT"
#   if hook_bus_has "secret-scanner"; then
#     result=$(hook_bus_get "secret-scanner")
#   fi

# Current bus directory (set by hook_bus_init)
_HOOK_BUS_DIR=""

# Portable short hash (macOS md5 vs Linux md5sum)
_short_hash() {
  local input="$1"
  if command -v md5sum &>/dev/null; then
    printf '%s' "$input" | md5sum 2>/dev/null | cut -c1-8
  elif command -v md5 &>/dev/null; then
    printf '%s' "$input" | md5 2>/dev/null | cut -c1-8
  else
    # Fallback: use cksum (always available)
    printf '%s' "$input" | cksum | cut -d' ' -f1
  fi
}

# Initialize the hook bus for this invocation
# Derives a unique directory from session + tool + input content
# Usage: hook_bus_init "$INPUT"
hook_bus_init() {
  local input_json="${1:-}"

  local session_id="${_HOOK_SESSION_ID:-unknown}"
  local tool_name="${_HOOK_TOOL_NAME:-unknown}"

  # Hash the tool_input portion for uniqueness within session+tool
  local input_hash
  local tool_input
  tool_input=$(printf '%s' "$input_json" | jq -r '.tool_input // ""' 2>/dev/null) || tool_input=""
  input_hash=$(_short_hash "${tool_input}")

  _HOOK_BUS_DIR="/tmp/.onlooker-hook-bus-${session_id}-${tool_name}-${input_hash}"
  ensure_dir_exists "$_HOOK_BUS_DIR" || {
    _HOOK_BUS_DIR=""  # Signal bus unavailable so hook_bus_put noops
    return 1
  }
}

# Write a named finding to the bus
# Usage: hook_bus_put "secret-scanner" '{"found": true}'
hook_bus_put() {
  local name="$1"
  local json_payload="$2"
  [[ -z "$_HOOK_BUS_DIR" || ! -d "$_HOOK_BUS_DIR" ]] && return 1
  printf '%s\n' "$json_payload" > "${_HOOK_BUS_DIR}/${name}.json" 2>/dev/null
}

# Read a named finding from the bus
# Returns JSON payload, or empty string if not found
# Usage: result=$(hook_bus_get "secret-scanner")
hook_bus_get() {
  local name="$1"
  local path="${_HOOK_BUS_DIR}/${name}.json"
  if [[ -f "$path" ]]; then
    cat "$path" 2>/dev/null
  fi
}

# Check if a named finding exists on the bus
# Usage: if hook_bus_has "secret-scanner"; then ...
hook_bus_has() {
  local name="$1"
  [[ -n "$_HOOK_BUS_DIR" && -f "${_HOOK_BUS_DIR}/${name}.json" ]]
}

# List all finding names on the bus
# Returns newline-separated names (without .json extension)
hook_bus_list() {
  [[ -z "$_HOOK_BUS_DIR" || ! -d "$_HOOK_BUS_DIR" ]] && return 0
  local f
  for f in "$_HOOK_BUS_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    basename "$f" .json
  done
}

# Clean up expired bus directories (older than 5 minutes)
# Call from SessionEnd or periodically
hook_bus_cleanup() {
  # Resolve /tmp symlink (macOS: /tmp -> /private/tmp) so find works
  local tmp_dir
  tmp_dir="$(cd /tmp && pwd -P)"
  find "$tmp_dir" -maxdepth 1 -name ".onlooker-hook-bus-*" -type d -mmin +5 -exec rm -rf {} + 2>/dev/null || true
}

# ============================================================================
# VALIDATION FUNCTIONS (return 0/1, never exit)
# ============================================================================

# Check if file exists
# Usage: validate_file_exists "/path/to/file" && echo "exists"
validate_file_exists() {
  local path="$1"
  [[ -n "$path" && -f "$path" ]]
}

# Check if file exists and is readable
# Usage: validate_file_readable "/path/to/file" && cat "$file"
validate_file_readable() {
  local path="$1"
  [[ -n "$path" && -f "$path" && -r "$path" ]]
}

# Check if parent directory is writable (for creating/appending to file)
# Usage: validate_file_writable "/path/to/new/file" && echo "data" >> "$file"
validate_file_writable() {
  local path="$1"
  [[ -z "$path" ]] && return 1
  local parent
  parent=$(dirname "$path")
  [[ -d "$parent" && -w "$parent" ]]
}

# Check if directory exists
# Usage: validate_dir_exists "/path/to/dir" && ls "$dir"
validate_dir_exists() {
  local path="$1"
  [[ -n "$path" && -d "$path" ]]
}

# ============================================================================
# ENSURE FUNCTIONS (create if needed, return 0/1)
# ============================================================================

# Create directory if it doesn't exist (mkdir -p wrapper)
# Usage: ensure_dir_exists "/path/to/dir" && echo "ready"
ensure_dir_exists() {
  local path="$1"
  [[ -z "$path" ]] && return 1
  [[ -d "$path" ]] && return 0
  mkdir -p "$path" 2>/dev/null
}

# Create file if it doesn't exist (creates parent dirs too)
# Usage: ensure_file_exists "/path/to/file" && echo "data" >> "$file"
ensure_file_exists() {
  local path="$1"
  [[ -z "$path" ]] && return 1
  [[ -f "$path" ]] && return 0
  local parent
  parent=$(dirname "$path")
  ensure_dir_exists "$parent" || return 1
  touch "$path" 2>/dev/null
}

# ============================================================================
# CONVENIENCE FUNCTIONS
# ============================================================================

# Safely read last N lines from file (returns empty if file missing)
# Usage: recent=$(safe_tail "/path/to/file" 5)
safe_tail() {
  local path="$1"
  local lines="${2:-10}"
  if validate_file_readable "$path"; then
    tail -n "$lines" "$path" 2>/dev/null
  fi
}

# Safely append to file (creates file if needed)
# Usage: echo "data" | safe_append "/path/to/file"
# Or:    safe_append "/path/to/file" "data to append"
safe_append() {
  local path="$1"
  local data="$2"
  ensure_file_exists "$path" || return 1
  if [[ -n "$data" ]]; then
    printf '%s\n' "$data" >> "$path" 2>/dev/null
  else
    cat >> "$path" 2>/dev/null
  fi
}

# Safely emit dev-os event (validates emit script exists)
# Usage: echo "$INPUT" | safe_emit "event_type" '{"key":"value"}'
safe_emit() {
  local event_type="$1"
  local payload="$2"
  if validate_file_exists "$ONLOOKER_EMIT"; then
    "$ONLOOKER_EMIT" "$event_type" "$payload"
  else
    # Fallback: write directly to events log
    ensure_file_exists "$ONLOOKER_EVENTS_LOG" || return 1
    local timestamp session_id
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    session_id=$(jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
    jq -cn \
      --arg ts "$timestamp" \
      --arg sid "$session_id" \
      --arg type "$event_type" \
      --argjson payload "$payload" \
      '{timestamp: $ts, session_id: $sid, event_type: $type, payload: $payload}' >> "$ONLOOKER_EVENTS_LOG"
  fi
}
