#!/usr/bin/env bash
# instructions-loaded.sh — InstructionsLoaded hook (synchronous).
#
# Reads the most recent Cartographer audit for the current cwd and injects
# a brief summary of active issues as additionalContext. Recommends running
# /cartographer:audit run if the audit is stale or files have changed.
#
# The full audit runs asynchronously via the agent hook. This script only
# surfaces prior findings — it never performs the analysis itself.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cartographer-utils.sh
source "$SCRIPT_DIR/cartographer-utils.sh"

hook_register "cartographer-instructions-loaded"

INPUT="$(cat)"
hook_set_context "$INPUT"

main() {
  cart_enabled || return 0

  local cwd
  cwd="$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)" || return 0
  [[ -z "$cwd" ]] && return 0

  local state
  state="$(cart_read_state)"

  local state_cwd last_audit_at health_score high medium
  state_cwd="$(echo "$state" | jq -r '.cwd // empty' 2>/dev/null)" || state_cwd=""
  last_audit_at="$(echo "$state" | jq -r '.last_audit_at // empty' 2>/dev/null)" || last_audit_at=""
  health_score="$(echo "$state" | jq -r '.health_score // empty' 2>/dev/null)" || health_score=""
  high="$(echo "$state" | jq -r '.issue_count.high // 0' 2>/dev/null)" || high=0
  medium="$(echo "$state" | jq -r '.issue_count.medium // 0' 2>/dev/null)" || medium=0

  # No prior audit or audit is for a different cwd — nothing to inject yet
  if [[ -z "$last_audit_at" || "$state_cwd" != "$cwd" ]]; then
    return 0
  fi

  # Check if the audit is stale
  local ttl_hours
  ttl_hours="$(cart_config_value '.audit_ttl_hours' '24')"
  local is_stale=false
  local now_epoch last_epoch age_hours

  if [[ "$(uname)" == "Darwin" ]]; then
    now_epoch="$(date -u +%s)"
    last_epoch="$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_audit_at" +%s 2>/dev/null)" || last_epoch=0
  else
    now_epoch="$(date -u +%s)"
    last_epoch="$(date -u -d "$last_audit_at" +%s 2>/dev/null)" || last_epoch=0
  fi

  age_hours=$(( (now_epoch - last_epoch) / 3600 ))
  [[ $age_hours -gt $ttl_hours ]] && is_stale=true

  # Also stale if hash was invalidated by ConfigChange
  local stored_hash
  stored_hash="$(echo "$state" | jq -r '.instruction_hash // "x"' 2>/dev/null)" || stored_hash="x"
  [[ -z "$stored_hash" ]] && is_stale=true

  # No issues and not stale — nothing worth injecting
  local min_sev
  min_sev="$(cart_config_value '.min_severity_to_inject' 'medium')"
  local has_issues=false
  if [[ "$min_sev" == "high" && $high -gt 0 ]]; then
    has_issues=true
  elif [[ "$min_sev" == "medium" && ( $high -gt 0 || $medium -gt 0 ) ]]; then
    has_issues=true
  elif [[ "$min_sev" == "low" ]]; then
    has_issues=true
  fi

  if [[ "$is_stale" == "false" && "$has_issues" == "false" ]]; then
    return 0
  fi

  # Build the injection message
  local lines=()

  if [[ "$has_issues" == "true" ]]; then
    lines+=("Cartographer: instruction health ${health_score} — ${high} high, ${medium} medium issues in CLAUDE.md/rules.")

    # Read the audit file for top issues
    local audit_file
    audit_file="$(echo "$state" | jq -r '.audit_file // empty' 2>/dev/null)" || audit_file=""
    if [[ -n "$audit_file" && -f "$audit_file" ]]; then
      local max_inject
      max_inject="$(cart_config_value '.max_issues_to_inject' '3')"
      local top_issues
      top_issues="$(jq -r --argjson max "$max_inject" --arg min "$min_sev" '
        .issues
        | map(select(
            if $min == "high" then .severity == "high"
            elif $min == "medium" then (.severity == "high" or .severity == "medium")
            else true end
          ))
        | sort_by(if .severity == "high" then 0 elif .severity == "medium" then 1 else 2 end)
        | .[:$max]
        | .[]
        | "  [" + .severity + "] " + .description
      ' "$audit_file" 2>/dev/null)" || top_issues=""

      if [[ -n "$top_issues" ]]; then
        while IFS= read -r line; do
          lines+=("$line")
        done <<< "$top_issues"
      fi
    fi

    lines+=("Run /cartographer:audit view for the full report.")
  fi

  if [[ "$is_stale" == "true" ]]; then
    lines+=("Cartographer: audit is stale (${age_hours}h old). Run /cartographer:audit run to refresh.")
  fi

  [[ ${#lines[@]} -eq 0 ]] && return 0

  local briefing
  briefing="$(printf '%s\n' "${lines[@]}")"

  jq -cn --arg briefing "$briefing" '{ additionalContext: $briefing }'

  # Emit health metric if Onlooker available
  if [[ -n "${health_score:-}" ]]; then
    safe_emit "instruction_health" "$(jq -nc \
      --arg cwd "$cwd" \
      --arg score "$health_score" \
      --argjson high "$high" \
      --argjson medium "$medium" \
      '{cwd: $cwd, health_score: ($score | tonumber), issue_count: {high: $high, medium: $medium}}')" \
      2>/dev/null || true
  fi
}

main

hook_success
exit 0
