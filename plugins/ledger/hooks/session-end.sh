#!/usr/bin/env bash
# session-end.sh — SessionEnd hook.
#
# Finalizes the session ledger entry and appends a summary line to the
# all-sessions log. Runs async — never blocks session shutdown.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ledger-utils.sh
source "$SCRIPT_DIR/ledger-utils.sh"

INPUT="$(cat)"

if ! ledger_enabled; then
  exit 0
fi

SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)" || SESSION_ID="unknown"

state="$(ledger_read_session "$SESSION_ID")"

# Mark session as finalized with an ended_at timestamp
finalized="$(echo "$state" | jq \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '.ended_at = $ts | .finalized = true')"

echo "$finalized" | ledger_write_session "$SESSION_ID" || true

# Optionally append to all-sessions log for cross-session analysis
log_all="$(ledger_config_value '.log_all_sessions' 'true')"
if [[ "$log_all" == "true" ]]; then
  ledger_ensure_file "$LEDGER_ALL_SESSIONS_LOG" || exit 0

  # Compute total cost for the summary line
  main_cost="$(echo "$finalized" | jq -r '.estimated_cost_usd // 0' 2>/dev/null)" || main_cost="0"
  sub_cost="$(echo "$finalized" | jq -r '.subagent_cost_usd // 0' 2>/dev/null)" || sub_cost="0"
  total_cost="$(awk -v a="$main_cost" -v b="$sub_cost" 'BEGIN { printf "%.6f", a + b }')"

  jq -cn \
    --arg sid "$SESSION_ID" \
    --arg started "$(echo "$finalized" | jq -r '.started_at // ""')" \
    --arg ended "$(echo "$finalized" | jq -r '.ended_at // ""')" \
    --argjson input_tokens "$(echo "$finalized" | jq '.input_tokens // 0')" \
    --argjson output_tokens "$(echo "$finalized" | jq '.output_tokens // 0')" \
    --argjson subagent_count "$(echo "$finalized" | jq '.subagent_count // 0')" \
    --argjson stop_count "$(echo "$finalized" | jq '.stop_count // 0')" \
    --arg total_cost "$total_cost" \
    '{
      session_id: $sid,
      started_at: $started,
      ended_at: $ended,
      input_tokens: $input_tokens,
      output_tokens: $output_tokens,
      subagent_count: $subagent_count,
      stop_count: $stop_count,
      total_cost_usd: ($total_cost | tonumber)
    }' >> "$LEDGER_ALL_SESSIONS_LOG" 2>/dev/null || true
fi

exit 0
