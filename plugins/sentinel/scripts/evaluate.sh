#!/usr/bin/env bash
# Sentinel deterministic evaluation fallback.
#
# Reads a Bash command from stdin JSON, matches against patterns/*.json,
# and returns a hook-compatible JSON decision. Used in CI/CD contexts
# where LLM evaluation is unavailable.
#
# Exit codes:
#   0 — allow or log (command proceeds)
#   2 — block (command rejected, stderr has reason)
#
# Must produce identical decisions for exact pattern matches regardless
# of environment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# ---------------------------------------------------------------------------
# Pattern matching
# ---------------------------------------------------------------------------

match_patterns() {
    local command="$1"
    local patterns="$2"
    local matches="[]"
    local count
    count="$(echo "$patterns" | jq 'length')"

    local i=0
    while [[ $i -lt $count ]]; do
        local regex
        regex="$(echo "$patterns" | jq -r ".[$i].regex // empty")"
        if [[ -n "$regex" ]]; then
            # Case-insensitive regex match
            if echo "$command" | grep -iqE "$regex" 2>/dev/null; then
                matches="$(echo "$patterns" | jq --argjson idx "$i" --argjson m "$matches" '$m + [.[$idx]]')"
            fi
        fi
        ((i++))
    done

    echo "$matches"
}

# ---------------------------------------------------------------------------
# Highest risk selection
# ---------------------------------------------------------------------------

highest_risk() {
    local matches="$1"
    local count
    count="$(echo "$matches" | jq 'length')"

    if [[ "$count" -eq 0 ]]; then
        echo "null"
        return
    fi

    # Sort by risk level: critical=0, high=1, medium=2, low=3
    echo "$matches" | jq '
        def risk_order:
            if . == "critical" then 0
            elif . == "high" then 1
            elif . == "medium" then 2
            else 3
            end;
        sort_by(.risk_level | risk_order) | first
    '
}

# ---------------------------------------------------------------------------
# Evaluation
# ---------------------------------------------------------------------------

evaluate() {
    local command="$1"
    local config
    config="$(get_config)"

    # Check if enabled
    local enabled
    enabled="$(sentinel_config_get "$config" '.enabled' 'true')"
    if [[ "$enabled" != "true" ]]; then
        echo '{"decision":"allow"}'
        return
    fi

    # Check safe paths first
    if is_safe_path "$command"; then
        echo '{"decision":"allow"}'
        return
    fi

    local patterns
    patterns="$(load_patterns)"
    local matches
    matches="$(match_patterns "$command" "$patterns")"

    local match_count
    match_count="$(echo "$matches" | jq 'length')"
    if [[ "$match_count" -eq 0 ]]; then
        echo '{"decision":"allow"}'
        return
    fi

    # Elevate risk if targeting protected paths
    if is_protected_path "$command"; then
        matches="$(echo "$matches" | jq '[.[] | .risk_level = "critical"]')"
    fi

    local top
    top="$(highest_risk "$matches")"
    if [[ "$top" == "null" ]]; then
        echo '{"decision":"allow"}'
        return
    fi

    local risk
    risk="$(echo "$top" | jq -r '.risk_level // "low"')"

    # Check session overrides
    local pattern_id
    pattern_id="$(echo "$top" | jq -r '.id // empty')"
    local behavior=""
    if [[ -n "$pattern_id" ]]; then
        local override
        override="$(echo "$config" | jq -r --arg id "$pattern_id" '.session_overrides[$id] // empty')"
        if [[ -n "$override" ]]; then
            behavior="$override"
        fi
    fi

    # Fall back to default behavior for risk level
    if [[ -z "$behavior" ]]; then
        behavior="$(echo "$config" | jq -r --arg r "$risk" '.default_behaviors[$r] // "log"')"
    fi

    local description
    description="$(echo "$top" | jq -r '.description // "Matched a dangerous pattern"')"
    local safer_alternative
    safer_alternative="$(echo "$top" | jq -r '.safer_alternative // "Review the command manually before executing"')"

    case "$behavior" in
        block)
            jq -n \
                --arg risk "$risk" \
                --arg reason "$description" \
                --arg safer "$safer_alternative" \
                --arg pattern "$pattern_id" \
                '{decision:"block", risk_level:$risk, reason:$reason, safer_alternative:$safer, pattern_matched:$pattern}'
            ;;
        review)
            jq -n \
                --arg risk "$risk" \
                --arg reason "$description" \
                --arg context "$safer_alternative" \
                --arg pattern "$pattern_id" \
                '{decision:"ask", risk_level:$risk, reason:$reason, context:$context, pattern_matched:$pattern}'
            ;;
        log)
            jq -n \
                --arg risk "$risk" \
                --arg summary "$description" \
                --arg pattern "$pattern_id" \
                '{decision:"log", risk_level:$risk, summary:$summary, pattern_matched:$pattern}'
            ;;
        *)
            echo '{"decision":"allow"}'
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Main — read command from stdin JSON and output decision
# ---------------------------------------------------------------------------

main() {
    local raw
    raw="$(cat)" || true

    if [[ -z "${raw// /}" ]]; then
        echo '{"decision":"allow"}'
        exit 0
    fi

    local command=""
    command="$(echo "$raw" | jq -r '.command // .input // empty' 2>/dev/null)" || true

    if [[ -z "$command" ]]; then
        echo '{"decision":"allow"}'
        exit 0
    fi

    local decision
    decision="$(evaluate "$command")"

    local decision_type
    decision_type="$(echo "$decision" | jq -r '.decision')"

    if [[ "$decision_type" == "block" ]]; then
        local reason
        reason="$(echo "$decision" | jq -r '.reason // "Blocked"')"
        local safer
        safer="$(echo "$decision" | jq -r '.safer_alternative // ""')"
        echo "Blocked: $reason. $safer" >&2
        exit 2
    else
        echo "$decision"
    fi
}

# Never crash — fail open
main 2>/dev/null || echo '{"decision":"allow"}'
