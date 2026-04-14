#!/usr/bin/env bash
# subagent-stop.sh — SubagentStop hook.
#
# Accumulates token usage and cost from a completed subagent into the
# session ledger. Runs async so it never blocks Claude's response.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ledger-utils.sh
source "$SCRIPT_DIR/ledger-utils.sh"

INPUT="$(cat)"

if ! ledger_enabled; then
  exit 0
fi

SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)" || SESSION_ID="unknown"
MODEL="$(echo "$INPUT" | jq -r '.model // "unknown"' 2>/dev/null)" || MODEL="unknown"
[[ "$MODEL" == "null" ]] && MODEL="${CLAUDE_MODEL:-unknown}"

INPUT_TOKENS="$(echo "$INPUT" | jq -r '.usage.input_tokens // .input_tokens // 0' 2>/dev/null)" || INPUT_TOKENS=0
OUTPUT_TOKENS="$(echo "$INPUT" | jq -r '.usage.output_tokens // .output_tokens // 0' 2>/dev/null)" || OUTPUT_TOKENS=0
CACHE_READ="$(echo "$INPUT" | jq -r '.usage.cache_read_input_tokens // 0' 2>/dev/null)" || CACHE_READ=0
CACHE_CREATE="$(echo "$INPUT" | jq -r '.usage.cache_creation_input_tokens // 0' 2>/dev/null)" || CACHE_CREATE=0

# Skip if no usage reported
if [[ "$INPUT_TOKENS" == "0" && "$OUTPUT_TOKENS" == "0" ]]; then
  exit 0
fi

COST="$(ledger_compute_cost "$MODEL" "$INPUT_TOKENS" "$OUTPUT_TOKENS" "$CACHE_READ" "$CACHE_CREATE")"

state="$(ledger_read_session "$SESSION_ID")"

updated_state="$(echo "$state" | jq \
  --argjson input "$INPUT_TOKENS" \
  --argjson output "$OUTPUT_TOKENS" \
  --argjson cache_read "$CACHE_READ" \
  --argjson cache_create "$CACHE_CREATE" \
  --argjson cost "$COST" \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '.subagent_input_tokens  += $input       |
   .subagent_output_tokens += $output      |
   .subagent_cost_usd      += $cost        |
   .updated_at              = $ts')"

echo "$updated_state" | ledger_write_session "$SESSION_ID" || true

exit 0
