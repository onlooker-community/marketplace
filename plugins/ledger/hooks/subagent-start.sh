#!/usr/bin/env bash
# subagent-start.sh — SubagentStart hook.
#
# Checks the current session budget before allowing a subagent to spawn.
# Exits 2 to block spawning if the session budget is exceeded.
# Emits a warning to stderr if the budget is approaching the threshold.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ledger-utils.sh
source "$SCRIPT_DIR/ledger-utils.sh"

INPUT="$(cat)"

# Exit cleanly if Ledger is disabled
if ! ledger_enabled; then
  exit 0
fi

SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)" || SESSION_ID="unknown"

# Read current session state
state="$(ledger_read_session "$SESSION_ID")"
current_cost="$(echo "$state" | jq -r '.estimated_cost_usd // 0' 2>/dev/null)" || current_cost="0"
subagent_cost="$(echo "$state" | jq -r '.subagent_cost_usd // 0' 2>/dev/null)" || subagent_cost="0"

# Total cost = main session + subagent costs
total_cost="$(awk -v a="$current_cost" -v b="$subagent_cost" 'BEGIN { printf "%.6f", a + b }')"

budget_status="$(ledger_check_budget "$total_cost")"

case "$budget_status" in
  exceeded:*)
    pct="${budget_status#exceeded:}"
    budget_limit="$(ledger_config_value '.budgets.session_cost_usd' '0')"
    block_on_exceeded="$(ledger_config_value '.block_on_budget_exceeded' 'true')"

    if [[ "$block_on_exceeded" == "true" ]]; then
      echo "Ledger: Session budget exceeded (${pct}% of \$${budget_limit}). Total cost: \$${total_cost}. Blocking subagent spawn. Use /ledger:ledger status to review." >&2
      exit 2
    else
      echo "Ledger: Session budget exceeded (${pct}% of \$${budget_limit}). Total cost: \$${total_cost}. block_on_budget_exceeded is false — allowing spawn." >&2
    fi
    ;;
  warning:*)
    pct="${budget_status#warning:}"
    budget_limit="$(ledger_config_value '.budgets.session_cost_usd' '0')"
    echo "Ledger: Session budget at ${pct}% of \$${budget_limit} (total: \$${total_cost}). Continuing." >&2
    ;;
  ok)
    ;;
esac

# Increment subagent_count in session file
updated_state="$(echo "$state" | jq \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '.subagent_count += 1 | .updated_at = $ts')"

echo "$updated_state" | ledger_write_session "$SESSION_ID" || true

exit 0
