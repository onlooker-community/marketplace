#!/usr/bin/env bash
# relay-utils.sh — Shared utilities for Relay hooks.
#
# Source this file in Relay hooks:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/relay-utils.sh"

# Guard against double-sourcing
[[ -n "${_RELAY_UTILS_LOADED:-}" ]] && return 0
_RELAY_UTILS_LOADED=1

set -uo pipefail

# ============================================================================
# CONFIG
# ============================================================================

_RELAY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_RELAY_CONFIG_FILE="${CLAUDE_PLUGIN_ROOT:-$_RELAY_SCRIPT_DIR/..}/config.json"

_relay_config_value() {
  local key="$1"
  local default="${2:-}"
  if [[ -f "$_RELAY_CONFIG_FILE" ]]; then
    local val
    val="$(jq -r --arg k "$key" '.[$k] // empty' "$_RELAY_CONFIG_FILE" 2>/dev/null)" || true
    if [[ -n "${val:-}" && "$val" != "null" ]]; then
      echo "$val"
      return 0
    fi
  fi
  echo "$default"
}

relay_enabled() {
  local v
  v="$(_relay_config_value 'enabled' 'true')"
  [[ "$v" == "true" ]]
}

relay_inject_on_start() {
  local v
  v="$(_relay_config_value 'inject_on_start' 'true')"
  [[ "$v" == "true" ]]
}

relay_storage_path() {
  local raw
  raw="$(_relay_config_value 'storage_path' "$HOME/.claude/relay/handoffs")"
  echo "${raw/#\~/$HOME}"
}

relay_max_words() {
  _relay_config_value 'max_injection_words' '500'
}

# ============================================================================
# STORAGE
# ============================================================================

relay_ensure_storage() {
  local path
  path="$(relay_storage_path)"
  [[ -d "$path" ]] && return 0
  mkdir -p "$path" 2>/dev/null
}

# relay_find_handoffs_for_cwd <cwd>
# Prints handoff file paths for <cwd> or any parent of it, newest first.
relay_find_handoffs_for_cwd() {
  local cwd="$1"
  local storage
  storage="$(relay_storage_path)"
  [[ -d "$storage" ]] || return 0

  local resolved_cwd
  resolved_cwd="$(cd "$cwd" 2>/dev/null && pwd -P)" || resolved_cwd="$cwd"

  local -a matches=()
  local -a timestamps=()
  local f handoff_cwd handoff_cwd_resolved ts

  while IFS= read -r f; do
    [[ -f "$f" ]] || continue

    handoff_cwd="$(jq -r '.cwd // ""' "$f" 2>/dev/null)" || continue
    [[ -z "$handoff_cwd" ]] && continue

    handoff_cwd_resolved="$(cd "$handoff_cwd" 2>/dev/null && pwd -P)" \
      || handoff_cwd_resolved="$handoff_cwd"

    # Prefix match: current cwd is the same as or under the handoff's cwd
    if [[ "$resolved_cwd" == "$handoff_cwd_resolved" || \
          "$resolved_cwd" == "$handoff_cwd_resolved"/* ]]; then
      ts="$(jq -r '.captured_at // ""' "$f" 2>/dev/null)" || ts=""
      matches+=("$f")
      timestamps+=("$ts")
    fi
  done < <(find "$storage" -maxdepth 1 -name "*.json" -type f 2>/dev/null)

  local n=${#matches[@]}
  if [[ $n -eq 0 ]]; then
    return 0
  elif [[ $n -eq 1 ]]; then
    echo "${matches[0]}"
  else
    local i
    for (( i=0; i<n; i++ )); do
      printf '%s\t%s\n' "${timestamps[$i]}" "${matches[$i]}"
    done | sort -r -t$'\t' -k1 | cut -f2
  fi
}

# relay_most_recent_handoff <cwd>
# Prints JSON of the most recent handoff, or nothing.
relay_most_recent_handoff() {
  local cwd="$1"
  local f
  f="$(relay_find_handoffs_for_cwd "$cwd" | head -1)" || return 0
  [[ -z "$f" || ! -f "$f" ]] && return 0
  jq '.' "$f" 2>/dev/null || true
}

# ============================================================================
# INJECTION FORMATTING
# ============================================================================

# relay_format_briefing <handoff_json> <max_words>
# Produces a terse operational briefing for SessionStart injection.
relay_format_briefing() {
  local handoff_json="$1"
  local max_words="${2:-500}"

  jq -r --argjson max_words "$max_words" '
    def nonempty: . != null and . != "" and (if type == "array" then length > 0 else true end);

    [ "RELAY HANDOFF — " + (.captured_at // "unknown time") ]

    + [ "" ]
    + [ "Task: " + (.task.summary // "unknown") + " [" + (.task.status // "unknown") + "]" ]
    + [ "Next: " + (.next_action // "(no next action recorded)") ]

    + (if ((.files_in_flight // []) | length) > 0 then
        [ "" ]
        + [ "In flight:" ]
        + [ .files_in_flight[]
            | "  • " + .path + " (" + (.state // "partial") + ")"
              + (if (.notes // "" | . != "") then " — " + .notes else "" end) ]
      else [] end)

    + (if ((.blocking_questions // []) | length) > 0 then
        [ "" ]
        + [ "Blocking:" ]
        + [
            # Sort by sessions_unresolved desc; handle both string and object format
            (.blocking_questions
             | map(if type == "string" then { question: ., sessions_unresolved: 0 } else . end)
             | sort_by(-.sessions_unresolved)
             | .[]
             | "  • "
               + (if .sessions_unresolved >= 2 then "[urgent x\(.sessions_unresolved)] " else "" end)
               + .question)
          ]
      else [] end)

    + (if ((.critical_context // []) | length) > 0 then
        [ "" ]
        + [ "Do not forget:" ]
        + [ .critical_context[] | "  • " + . ]
      else [] end)

    + (if (.last_intent // "" | . != "") then
        [ "" ]
        + [ "Last intent: " + .last_intent ]
      else [] end)

    | join("\n")
    | split(" ")
    | if length > $max_words then
        .[:$max_words] | join(" ") + " [truncated]"
      else
        join(" ")
      end
  ' <<< "$handoff_json" 2>/dev/null
}
