#!/usr/bin/env bash
# config-change.sh — ConfigChange hook (async).
#
# Claude Code configuration changed — plugin installed/removed, settings updated.
# Invalidates the cached instruction hash so the next InstructionsLoaded triggers
# a fresh audit. Config changes can affect which plugin references are valid or
# which tools are in the expected toolchain.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cartographer-utils.sh
source "$SCRIPT_DIR/cartographer-utils.sh"

hook_register "cartographer-config-change"

INPUT="$(cat)"
hook_set_context "$INPUT"

if ! cart_enabled; then
  hook_success
  exit 0
fi

# Invalidate hash — next InstructionsLoaded will trigger a fresh audit
cart_invalidate_hash

# Emit telemetry
safe_emit "cartographer_invalidated" "$(jq -nc \
  --arg reason "ConfigChange" \
  '{reason: $reason}')" 2>/dev/null || true

hook_success
exit 0
