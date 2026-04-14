#!/usr/bin/env bash
# ledger-utils.sh — Shared utilities for Ledger hooks.
#
# Source this file in Ledger hooks:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/ledger-utils.sh"

set -euo pipefail

# ============================================================================
# PATH CONSTANTS
# ============================================================================

export CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
export LEDGER_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"

# Config is next to this script's parent (hooks/../config.json)
_LEDGER_CONFIG_FILE="${LEDGER_PLUGIN_ROOT}/config.json"

# Resolve storage path from config, defaulting to $HOME/.claude/ledger
_raw_storage_path() {
  if [[ -f "$_LEDGER_CONFIG_FILE" ]]; then
    jq -r ".storage_path // \"$HOME/.claude/ledger\"" "$_LEDGER_CONFIG_FILE" 2>/dev/null \
      || echo "$HOME/.claude/ledger"
  else
    echo "$HOME/.claude/ledger"
  fi
}

# Expand ~ in path (handles values read from config that may contain a literal ~)
_expand_path() {
  local p="$1"
  echo "${p/#\~/$HOME}"
}

export LEDGER_DIR
LEDGER_DIR="$(_expand_path "$(_raw_storage_path)")"
export LEDGER_SESSIONS_DIR="${LEDGER_DIR}/sessions"
export LEDGER_ALL_SESSIONS_LOG="${LEDGER_DIR}/all-sessions.jsonl"

# ============================================================================
# FILESYSTEM HELPERS
# ============================================================================

ledger_ensure_dir() {
  local path="$1"
  [[ -z "$path" ]] && return 1
  [[ -d "$path" ]] && return 0
  mkdir -p "$path" 2>/dev/null
}

ledger_ensure_file() {
  local path="$1"
  [[ -z "$path" ]] && return 1
  [[ -f "$path" ]] && return 0
  local parent
  parent="$(dirname "$path")"
  ledger_ensure_dir "$parent" || return 1
  touch "$path" 2>/dev/null
}

# ============================================================================
# CONFIG HELPERS
# ============================================================================

# Usage: ledger_config_value ".budgets.session_cost_usd" "2.00"
ledger_config_value() {
  local key="$1"
  local default="${2:-}"
  if [[ -f "$_LEDGER_CONFIG_FILE" ]]; then
    local val
    val="$(jq -r "${key} // empty" "$_LEDGER_CONFIG_FILE" 2>/dev/null)" || true
    if [[ -n "$val" && "$val" != "null" ]]; then
      echo "$val"
      return 0
    fi
  fi
  echo "$default"
}

ledger_enabled() {
  local enabled
  enabled="$(ledger_config_value '.enabled' 'true')"
  [[ "$enabled" == "true" ]]
}

# ============================================================================
# PRICING TABLE (per 1M tokens) — Updated 2026-03
# ============================================================================

# Sets IN_RATE, OUT_RATE, CACHE_READ_RATE, CACHE_CREATE_RATE based on model
ledger_set_pricing() {
  local model="${1:-}"
  case "$model" in
    *haiku*3.5*|*haiku*3-5*)
      IN_RATE=0.80; OUT_RATE=4.00; CACHE_READ_RATE=0.08; CACHE_CREATE_RATE=1.00 ;;
    *haiku*3*)
      IN_RATE=0.25; OUT_RATE=1.25; CACHE_READ_RATE=0.03; CACHE_CREATE_RATE=0.30 ;;
    *haiku*)
      IN_RATE=1.00; OUT_RATE=5.00; CACHE_READ_RATE=0.10; CACHE_CREATE_RATE=1.25 ;;
    *sonnet*)
      IN_RATE=3.00; OUT_RATE=15.00; CACHE_READ_RATE=0.30; CACHE_CREATE_RATE=3.75 ;;
    *opus*4.1*|*opus*4-1*|*opus*4.0*|*opus*4-0*)
      IN_RATE=15.00; OUT_RATE=75.00; CACHE_READ_RATE=1.50; CACHE_CREATE_RATE=18.75 ;;
    *opus*)
      IN_RATE=5.00; OUT_RATE=25.00; CACHE_READ_RATE=0.50; CACHE_CREATE_RATE=6.25 ;;
    *)
      IN_RATE=3.00; OUT_RATE=15.00; CACHE_READ_RATE=0.30; CACHE_CREATE_RATE=3.75 ;;
  esac
}

# Compute cost (USD) for given token counts and model.
# Usage: cost=$(ledger_compute_cost "$model" "$input" "$output" "$cache_read" "$cache_create")
ledger_compute_cost() {
  local model="$1"
  local input_tokens="${2:-0}"
  local output_tokens="${3:-0}"
  local cache_read="${4:-0}"
  local cache_create="${5:-0}"

  ledger_set_pricing "$model"

  awk -v it="$input_tokens" -v ir="$IN_RATE" \
      -v ot="$output_tokens" -v or_="$OUT_RATE" \
      -v cr="$cache_read" -v crr="$CACHE_READ_RATE" \
      -v cc="$cache_create" -v ccr="$CACHE_CREATE_RATE" \
    'BEGIN { printf "%.6f", (it * ir + ot * or_ + cr * crr + cc * ccr) / 1000000 }'
}

# ============================================================================
# SESSION LEDGER
# ============================================================================

# Returns path to session JSON file.
# Usage: sf=$(ledger_session_file "$session_id")
ledger_session_file() {
  local session_id="${1:-unknown}"
  echo "${LEDGER_SESSIONS_DIR}/${session_id}.json"
}

# Read current session JSON, or emit a zero-baseline object.
# Usage: state=$(ledger_read_session "$session_id")
ledger_read_session() {
  local session_id="${1:-unknown}"
  local sf
  sf="$(ledger_session_file "$session_id")"
  if [[ -f "$sf" ]]; then
    cat "$sf" 2>/dev/null
  else
    jq -cn \
      --arg sid "$session_id" \
      --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      '{
        session_id: $sid,
        started_at: $ts,
        updated_at: $ts,
        input_tokens: 0,
        output_tokens: 0,
        cache_read_tokens: 0,
        cache_creation_tokens: 0,
        estimated_cost_usd: 0.0,
        subagent_count: 0,
        subagent_input_tokens: 0,
        subagent_output_tokens: 0,
        subagent_cost_usd: 0.0,
        stop_count: 0
      }'
  fi
}

# Atomically write session JSON.
# Usage: echo "$new_json" | ledger_write_session "$session_id"
ledger_write_session() {
  local session_id="${1:-unknown}"
  local sf
  sf="$(ledger_session_file "$session_id")"
  ledger_ensure_dir "$LEDGER_SESSIONS_DIR" || return 1

  local tmp
  tmp="$(mktemp "${LEDGER_SESSIONS_DIR}/.tmp.XXXXXX")" || return 1
  cat > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$sf" 2>/dev/null || { rm -f "$tmp"; return 1; }
}

# ============================================================================
# BUDGET CHECK
# ============================================================================

# Returns: "ok", "warning:<pct>", or "exceeded:<pct>"
# Usage: status=$(ledger_check_budget "$estimated_cost_usd")
ledger_check_budget() {
  local current_cost="${1:-0}"

  local budget_cost warning_pct reserve_pct
  budget_cost="$(ledger_config_value '.budgets.session_cost_usd' '0')"
  warning_pct="$(ledger_config_value '.budgets.warning_threshold_pct' '80')"
  reserve_pct="$(ledger_config_value '.reserve_buffer_pct' '12')"

  # If no cost budget set (0), skip cost check
  if [[ "$budget_cost" == "0" || "$budget_cost" == "0.0" || "$budget_cost" == "0.00" ]]; then
    echo "ok"
    return 0
  fi

  # Effective limit includes reserve buffer: budget * (1 - reserve_pct/100)
  # The reserve means we block before fully exhausting the budget
  awk -v cost="$current_cost" \
      -v budget="$budget_cost" \
      -v warn_pct="$warning_pct" \
      -v reserve_pct="$reserve_pct" \
    'BEGIN {
      pct = (cost / budget) * 100
      effective_limit = budget * (1 - reserve_pct / 100)
      if (cost >= effective_limit) {
        printf "exceeded:%.0f\n", pct
      } else if (pct >= warn_pct) {
        printf "warning:%.0f\n", pct
      } else {
        print "ok"
      }
    }'
}
