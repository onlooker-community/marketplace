#!/usr/bin/env bash
# cartographer-lore-sync.sh — SessionEnd (async). Pushes Cartographer contradiction
# findings into Lore as CONTRADICTS edges. Never blocks; stderr only on failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cartographer-utils.sh
source "$SCRIPT_DIR/cartographer-utils.sh"
# shellcheck source=lore-invoke.sh
[[ -f "$SCRIPT_DIR/lore-invoke.sh" ]] && source "$SCRIPT_DIR/lore-invoke.sh"

main() {
	cart_enabled || exit 0
	[[ "$(cart_config_value '.lore_sync_enabled' 'true')" == "false" ]] && exit 0
	type lore_cli_run >/dev/null 2>&1 || exit 0

	local state audit_file
	state="$(cart_read_state)"
	audit_file="$(echo "$state" | jq -r '.audit_file // empty' 2>/dev/null)" || audit_file=""
	[[ -z "$audit_file" || ! -f "$audit_file" ]] && exit 0

	lore_cli_run sync-cartographer --file "$audit_file" 2>/dev/null || true
}

main
exit 0
