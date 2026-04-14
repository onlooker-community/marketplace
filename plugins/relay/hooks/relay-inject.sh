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

  jq -cn --arg briefing "$briefing" '{ additionalContext: $briefing }'
}

main

exit 0
