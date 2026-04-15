#!/usr/bin/env bash
# relay-inject.sh — SessionStart hook.
#
# Finds the most recent handoff for the current working directory and injects
# it as an operational briefing via additionalContext. Must never block session
# start — all errors exit cleanly with no output.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=relay-utils.sh
source "$SCRIPT_DIR/relay-utils.sh"
# shellcheck source=lore-invoke.sh
[[ -f "$SCRIPT_DIR/lore-invoke.sh" ]] && source "$SCRIPT_DIR/lore-invoke.sh"

main() {
  relay_enabled || return 0
  relay_inject_on_start || return 0

  local raw
  raw="$(cat)" || return 0
  [[ -z "${raw// }" ]] && return 0

  local cwd
  cwd="$(echo "$raw" | jq -r '.cwd // empty' 2>/dev/null)" || return 0
  [[ -z "$cwd" ]] && return 0

  local handoff
  handoff="$(relay_most_recent_handoff "$cwd")" || return 0
  [[ -z "$handoff" ]] && return 0

  # Skip if the task was completed — no need to inject a finished handoff
  local status
  status="$(echo "$handoff" | jq -r '.task.status // ""' 2>/dev/null)" || status=""
  [[ "$status" == "complete" ]] && return 0

  local max_words
  max_words="$(relay_max_words)"

  local briefing
  briefing="$(relay_format_briefing "$handoff" "$max_words")" || return 0
  [[ -z "$briefing" ]] && return 0

  local inject_lore lore_words lore_extra
  inject_lore="$(_relay_config_value 'inject_lore' 'false')"
  lore_words="$(_relay_config_value 'lore_max_words' '80')"
  lore_extra=""
  if [[ "$inject_lore" == "true" ]] && type lore_cli_run >/dev/null 2>&1; then
    lore_extra="$(lore_cli_run context-for-inject --cwd "$cwd" --max-words "$lore_words" 2>/dev/null)" || lore_extra=""
  fi
  if [[ -n "${lore_extra// }" ]]; then
    briefing=$(printf '%s\n\n%s' "$briefing" "$lore_extra")
  fi

  jq -cn --arg briefing "$briefing" '{ additionalContext: $briefing }'
}

main

exit 0
