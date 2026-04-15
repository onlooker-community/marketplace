#!/usr/bin/env bash
# archivist-utils.sh - Shared utilities for Archivist scripts.
# Source this file; do not execute directly.
#
# Usage:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/archivist-utils.sh"

# Guard against double-sourcing
[[ -n "${_ARCHIVIST_UTILS_LOADED:-}" ]] && return 0
_ARCHIVIST_UTILS_LOADED=1

# ============================================================================
# CONFIG
# ============================================================================

# Locate config.json relative to this script (mirrors Path(__file__).parent.parent)
_ARCHIVIST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ARCHIVIST_DEFAULT_CONFIG="$_ARCHIVIST_SCRIPT_DIR/../config.json"

# Config defaults (mirrors Python defaults dict)
_ARCHIVIST_DEFAULT_STORAGE_PATH="$HOME/.claude/archivist/sessions"
_ARCHIVIST_DEFAULT_MAX_INJECTION_WORDS=400
_ARCHIVIST_DEFAULT_INJECT_ON_START="true"
_ARCHIVIST_DEFAULT_EXTRACT_ON_COMPACT="true"
_ARCHIVIST_DEFAULT_EXTRACT_ON_END="true"
_ARCHIVIST_DEFAULT_MIN_CONFIDENCE="medium"
_ARCHIVIST_DEFAULT_LORE_ENABLED="true"
_ARCHIVIST_DEFAULT_LORE_RANKING="false"

# archivist_get_config_value <key>
# Returns the config value for <key>, falling back to the default.
archivist_get_config_value() {
  local key="$1"
  local config_file="${ARCHIVIST_CONFIG:-$_ARCHIVIST_DEFAULT_CONFIG}"

  local default
  case "$key" in
    storage_path)              default="$_ARCHIVIST_DEFAULT_STORAGE_PATH" ;;
    max_injection_words)       default="$_ARCHIVIST_DEFAULT_MAX_INJECTION_WORDS" ;;
    inject_on_start)           default="$_ARCHIVIST_DEFAULT_INJECT_ON_START" ;;
    extract_on_compact)        default="$_ARCHIVIST_DEFAULT_EXTRACT_ON_COMPACT" ;;
    extract_on_end)            default="$_ARCHIVIST_DEFAULT_EXTRACT_ON_END" ;;
    min_confidence_to_inject)  default="$_ARCHIVIST_DEFAULT_MIN_CONFIDENCE" ;;
    lore_enabled)              default="$_ARCHIVIST_DEFAULT_LORE_ENABLED" ;;
    lore_ranking)              default="$_ARCHIVIST_DEFAULT_LORE_RANKING" ;;
    *)                         default="" ;;
  esac

  if [[ -f "$config_file" ]]; then
    local val
    val=$(jq -r --arg key "$key" --arg default "$default" \
      '.[$key] // $default' "$config_file" 2>/dev/null) \
      && echo "$val" \
      || echo "$default"
  else
    echo "$default"
  fi
}

# archivist_get_storage_path
# Resolves and creates the storage directory. Prints the path.
archivist_get_storage_path() {
  local raw_path
  raw_path=$(archivist_get_config_value "storage_path")

  # Expand ~ manually (handles cases where the value comes from JSON)
  local expanded="${raw_path/#\~/$HOME}"

  mkdir -p "$expanded" 2>/dev/null
  echo "$expanded"
}

# ============================================================================
# SESSION I/O
# ============================================================================

# archivist_session_file_path <session_id>
# Prints the full path for a session file.
archivist_session_file_path() {
  local session_id="$1"
  local storage
  storage=$(archivist_get_storage_path)
  echo "$storage/${session_id}.json"
}

# archivist_read_session <file_path>
# Prints the session JSON, or nothing on any error.
archivist_read_session() {
  local path="$1"
  [[ -f "$path" && -r "$path" ]] || return 0
  jq '.' "$path" 2>/dev/null || true
}

# archivist_write_session <session_id> <json_data>
# Writes session JSON to storage atomically. Prints the file path.
archivist_write_session() {
  local session_id="$1"
  local data="$2"

  local path
  path=$(archivist_session_file_path "$session_id")

  local tmp
  tmp=$(mktemp) || return 1
  echo "$data" | jq '.' > "$tmp" 2>/dev/null \
    && mv "$tmp" "$path" 2>/dev/null \
    || { rm -f "$tmp" 2>/dev/null; return 1; }

  echo "$path"
}

# ============================================================================
# SESSION LOOKUP (with prefix-matching)
# ============================================================================

# archivist_find_sessions_for_cwd <cwd>
# Finds all sessions whose cwd is the same as or a parent of <cwd>.
# A session from /project matches a query for /project/src.
# Prints a newline-separated list of session file paths, newest first.
archivist_find_sessions_for_cwd() {
  local cwd="$1"
  local storage
  storage=$(archivist_get_storage_path)

  [[ -d "$storage" ]] || return 0

  # Resolve the query cwd to an absolute path
  local resolved_cwd
  resolved_cwd=$(cd "$cwd" 2>/dev/null && pwd -P) || resolved_cwd="$cwd"

  # Collect matching session files with their timestamps for sorting
  local -a matches=()
  local -a timestamps=()

  local f session_cwd session_cwd_resolved timestamp
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue

    session_cwd=$(jq -r '.cwd // ""' "$f" 2>/dev/null) || continue
    [[ -z "$session_cwd" ]] && continue

    session_cwd_resolved=$(cd "$session_cwd" 2>/dev/null && pwd -P) || session_cwd_resolved="$session_cwd"

    # Prefix match: resolved_cwd starts with session_cwd_resolved
    # (mirrors Python's cwd_path.relative_to(session_cwd))
    if [[ "$resolved_cwd" == "$session_cwd_resolved" || \
          "$resolved_cwd" == "$session_cwd_resolved"/* ]]; then
      timestamp=$(jq -r '.timestamp // ""' "$f" 2>/dev/null) || timestamp=""
      matches+=("$f")
      timestamps+=("$timestamp")
    fi
  done < <(find "$storage" -maxdepth 1 -name "*.json" -type f 2>/dev/null)

  # Sort by timestamp descending (ISO8601 sorts lexicographically)
  local n=${#matches[@]}
  if [[ $n -gt 1 ]]; then
    # Pair up and sort: "timestamp\tpath", sort -r, extract path
    local i
    for (( i=0; i<n; i++ )); do
      printf '%s\t%s\n' "${timestamps[$i]}" "${matches[$i]}"
    done | sort -r -t$'\t' -k1 | cut -f2
  elif [[ $n -eq 1 ]]; then
    echo "${matches[0]}"
  fi
}

# archivist_lore_maybe_ingest <session_json_path>
# Non-blocking: fails silently if Lore is unavailable.
archivist_lore_maybe_ingest() {
  local path="$1"
  local le
  le=$(archivist_get_config_value "lore_enabled")
  [[ "$le" == "false" ]] && return 0
  [[ -z "$path" || ! -f "$path" ]] && return 0
  # shellcheck source=lore-invoke.sh
  source "$_ARCHIVIST_SCRIPT_DIR/lore-invoke.sh" 2>/dev/null || return 0
  lore_cli_run ingest --format archivist-session --file "$path" 2>/dev/null || true
}

# archivist_lore_context_block <cwd> <max_words>
# Prints extra context from Lore (may be empty).
archivist_lore_context_block() {
  local cwd="$1"
  local max_words="$2"
  local lr
  lr=$(archivist_get_config_value "lore_ranking")
  [[ "$lr" != "true" ]] && return 0
  [[ -z "$cwd" ]] && return 0
  # shellcheck source=lore-invoke.sh
  source "$_ARCHIVIST_SCRIPT_DIR/lore-invoke.sh" 2>/dev/null || return 0
  lore_cli_run context-for-inject --cwd "$cwd" --max-words "$max_words" 2>/dev/null || true
}

# archivist_find_most_recent_session <cwd>
# Prints the JSON of the most recent matching session, or nothing.
archivist_find_most_recent_session() {
  local cwd="$1"
  local most_recent
  most_recent=$(archivist_find_sessions_for_cwd "$cwd" | head -1) || return 0
  [[ -z "$most_recent" ]] && return 0
  archivist_read_session "$most_recent"
}
