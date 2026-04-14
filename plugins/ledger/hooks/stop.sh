#!/usr/bin/env bash
# stop.sh — Stop hook.
#
# Accumulates token usage and cost from the Stop event into the session ledger.
# Emits a budget warning to stderr if approaching or at the threshold.
# Runs synchronously so warnings surface before the next turn.

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
[[ "$MODEL" == "null" || "$MODEL" == "unknown" ]] && MODEL="${CLAUDE_MODEL:-unknown}"

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
  '.input_tokens        += $input       |
   .output_tokens       += $output      |
   .cache_read_tokens   += $cache_read  |
   .cache_creation_tokens += $cache_create |
   .estimated_cost_usd  += $cost        |
   .stop_count          += 1            |
   .updated_at           = $ts')"

echo "$updated_state" | ledger_write_session "$SESSION_ID" || true

# Check budget against total accumulated cost (main + subagent)
main_cost="$(echo "$updated_state" | jq -r '.estimated_cost_usd // 0' 2>/dev/null)" || main_cost="0"
sub_cost="$(echo "$updated_state" | jq -r '.subagent_cost_usd // 0' 2>/dev/null)" || sub_cost="0"
total_cost="$(awk -v a="$main_cost" -v b="$sub_cost" 'BEGIN { printf "%.6f", a + b }')"

budget_status="$(ledger_check_budget "$total_cost")"

case "$budget_status" in
  exceeded:*)
    pct="${budget_status#exceeded:}"
    budget_limit="$(ledger_config_value '.budgets.session_cost_usd' '0')"
    echo "Ledger: Session budget exceeded — ${pct}% of \$${budget_limit} (total: \$${total_cost}). Next subagent spawn will be blocked." >&2
    ;;
  warning:*)
    pct="${budget_status#warning:}"
    budget_limit="$(ledger_config_value '.budgets.session_cost_usd' '0')"
    echo "Ledger: Session budget at ${pct}% of \$${budget_limit} (total: \$${total_cost})." >&2
    ;;
  ok)
    ;;
esac

exit 0
