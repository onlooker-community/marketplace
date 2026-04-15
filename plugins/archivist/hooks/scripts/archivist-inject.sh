#!/usr/bin/env bash
# Archivist injection script.
# Invoked by the SessionStart hook (command fallback).
# Reads cwd from stdin JSON, finds the most recent session extract,
# and returns additionalContext JSON on stdout.
# Must never raise exceptions or block session start.

set -uo pipefail  # No -e: must never block session start

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=archivist-utils.sh
source "$SCRIPT_DIR/archivist-utils.sh"

# ----------------------------------------------------------------------------
# build_summary <session_json> <min_confidence> <max_words>
# Builds a concise injection summary from a session JSON string.
# ----------------------------------------------------------------------------
build_summary() {
  local session_json="$1"
  local min_confidence="$2"
  local max_words="$3"
  local min_conf_val

  # Map confidence level to int for jq
  case "$min_confidence" in
    high)   min_conf_val=3 ;;
    medium) min_conf_val=2 ;;
    low)    min_conf_val=1 ;;
    *)      min_conf_val=2 ;;
  esac

  # Build summary using jq — all sorting/filtering/truncation in one pass
  echo "$session_json" | jq -r \
    --argjson min_conf "$min_conf_val" \
    --argjson max_words "$max_words" \
    '
    def level_value:
      if . == "high" then 3
      elif . == "medium" then 2
      elif . == "low" then 1
      else 0 end;

    # Open questions: top 3 by priority, then by sessions_unresolved (mounting urgency)
    (.open_questions // []
      | sort_by(
          (.priority // "low" | level_value) * 100 + (.sessions_unresolved // 0)
        )
      | reverse
      | .[:3]) as $questions |

    # Decisions: filter by min confidence, top 3
    (.decisions // []
      | map(select((.confidence // "low" | level_value) >= $min_conf))
      | sort_by(.confidence // "low" | level_value)
      | reverse
      | .[:3]) as $decisions |

    # Dead ends: top 2
    (.dead_ends // [] | .[:2]) as $dead_ends |

    # Build lines
    ["Continuing from last session:"]

    + (if ($questions | length) > 0 then
        [""]
        + ($questions | map("- [\(.priority // "medium")] \(.question): \(.context // "")"))
      else [] end)

    + (if ($decisions | length) > 0 then
        [""]
        + ($decisions | map("- Rule: \(.rule) (\(.confidence // "medium") confidence)"))
      else [] end)

    + (if ($dead_ends | length) > 0 then
        [""]
        + ($dead_ends | map("- Avoid: \(.approach) — \(.why_failed // "did not work")"))
      else [] end)

    | join("\n")

    # Truncate to max_words
    | split(" ")
    | if length > $max_words then
        .[:$max_words] | join(" ") + "..."
      else
        join(" ")
      end
    ' 2>/dev/null
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
main() {
  local raw
  raw=$(cat) || return 0
  [[ -z "${raw// }" ]] && return 0

  # Extract cwd from input
  local cwd
  cwd=$(echo "$raw" | jq -r '.cwd // empty' 2>/dev/null) || return 0
  [[ -z "$cwd" ]] && return 0

  # Load config via utils
  local inject_on_start min_confidence max_words
  inject_on_start=$(archivist_get_config_value "inject_on_start")
  min_confidence=$(archivist_get_config_value "min_confidence_to_inject")
  max_words=$(archivist_get_config_value "max_injection_words")

  [[ "$inject_on_start" == "false" ]] && return 0

  # Find most recent session for this cwd (with prefix matching)
  local session_json
  session_json=$(archivist_find_most_recent_session "$cwd") || return 0
  [[ -z "$session_json" ]] && return 0

  # Build summary and emit additionalContext
  local summary
  summary=$(build_summary "$session_json" "$min_confidence" "$max_words") || return 0
  [[ -z "$summary" ]] && return 0

  local lore_block
  lore_block="$(archivist_lore_context_block "$cwd" "$max_words")" || lore_block=""
  if [[ -n "${lore_block// }" ]]; then
    summary=$(printf '%s\n\n%s' "$summary" "$lore_block")
  fi

  jq -cn --arg summary "$summary" '{ additionalContext: $summary }'
}

main

exit 0
