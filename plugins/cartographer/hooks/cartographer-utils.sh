#!/usr/bin/env bash
# cartographer-utils.sh — Shared utilities for Cartographer hooks.
#
# Source this in Cartographer hooks:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/cartographer-utils.sh"

[[ -n "${_CARTOGRAPHER_UTILS_LOADED:-}" ]] && return 0
_CARTOGRAPHER_UTILS_LOADED=1

set -uo pipefail

# ============================================================================
# ONLOOKER INTEGRATION (with fallback stubs)
# ============================================================================

_CART_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONLOOKER_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT%/*}/../onlooker/0.5.0"

if [[ -f "$ONLOOKER_PLUGIN_ROOT/hooks/validate-path.sh" ]]; then
  # shellcheck source=/dev/null
  source "$ONLOOKER_PLUGIN_ROOT/hooks/validate-path.sh"
else
  ensure_dir_exists()  { mkdir -p "$1" 2>/dev/null; }
  ensure_file_exists() { local d; d="$(dirname "$1")"; mkdir -p "$d" 2>/dev/null && touch "$1" 2>/dev/null; }
  hook_register()      { :; }
  hook_set_context()   { :; }
  hook_success()       { :; }
  hook_failure()       { :; }
  safe_emit()          { :; }
fi

# ============================================================================
# CONFIG
# ============================================================================

_CART_CONFIG_FILE="${CLAUDE_PLUGIN_ROOT}/config.json"

cart_config_value() {
  local key="$1"
  local default="${2:-}"
  if [[ -f "$_CART_CONFIG_FILE" ]]; then
    local val
    val="$(jq -r "${key} // empty" "$_CART_CONFIG_FILE" 2>/dev/null)" || true
    if [[ -n "${val:-}" && "$val" != "null" ]]; then
      echo "$val"
      return 0
    fi
  fi
  echo "$default"
}

cart_enabled() {
  [[ "$(cart_config_value '.enabled' 'true')" == "true" ]]
}

# ============================================================================
# STORAGE
# ============================================================================

cart_storage_path() {
  local raw
  raw="$(cart_config_value '.storage_path' "$HOME/.claude/cartographer")"
  echo "${raw/#\~/$HOME}"
}

cart_state_file() {
  echo "$(cart_storage_path)/state.json"
}

cart_audits_dir() {
  echo "$(cart_storage_path)/audits"
}

# ============================================================================
# STATE HELPERS
# ============================================================================

# Read the last audit state JSON, or emit empty object.
cart_read_state() {
  local sf
  sf="$(cart_state_file)"
  if [[ -f "$sf" ]]; then
    jq '.' "$sf" 2>/dev/null || echo '{}'
  else
    echo '{}'
  fi
}

# Clear the instruction hash in state so the next InstructionsLoaded triggers a fresh audit.
cart_invalidate_hash() {
  local sf
  sf="$(cart_state_file)"
  ensure_dir_exists "$(cart_storage_path)" || return 0

  if [[ -f "$sf" ]]; then
    local tmp
    tmp="$(mktemp)" || return 0
    if jq '.instruction_hash = "" | .invalidated_at = $ts' \
        --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        "$sf" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$sf" 2>/dev/null || rm -f "$tmp" 2>/dev/null
    else
      rm -f "$tmp" 2>/dev/null
    fi
  fi
}
