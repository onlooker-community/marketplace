#!/usr/bin/env bash
set -euo pipefail

# Counsel schedule check — SessionStart hook.
# Checks if enough time has passed since the last brief and notifies
# the user if a new brief is due. Does NOT auto-generate — just nudges.
# Must never block or crash.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source Onlooker's shared utilities for health monitoring
ONLOOKER_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT%/*}/../onlooker/0.5.0"
if [[ -f "$ONLOOKER_PLUGIN_ROOT/hooks/validate-path.sh" ]]; then
  # shellcheck source=/dev/null
  source "$ONLOOKER_PLUGIN_ROOT/hooks/validate-path.sh"
else
  ensure_dir_exists() { mkdir -p "$1" 2>/dev/null; }
  ensure_file_exists() { local d; d=$(dirname "$1"); mkdir -p "$d" 2>/dev/null && touch "$1" 2>/dev/null; }
  hook_register() { :; }
  hook_set_context() { :; }
  hook_success() { :; }
  hook_failure() { :; }
  safe_emit() { :; }
fi

# Source Counsel utilities
source "$CLAUDE_PLUGIN_ROOT/scripts/utils.sh"

hook_register "counsel-check"

INPUT=$(cat)
hook_set_context "$INPUT"

# ============================================================================
# CHECK IF ENABLED
# ============================================================================

CONFIG=$(counsel_get_config)
ENABLED=$(counsel_config_get "$CONFIG" '.enabled' 'true')
if [[ "$ENABLED" != "true" ]]; then
    hook_success
    exit 0
fi

# ============================================================================
# CHECK IF BRIEF IS DUE
# ============================================================================

if counsel_should_run; then
    echo "Counsel: A weekly improvement brief is due. Run /counsel:brief generate to create one." >&2

    # Emit telemetry
    safe_emit "counsel_brief_due" "$(jq -nc '{status: "due"}')" 2>/dev/null || true
fi

hook_success
exit 0
