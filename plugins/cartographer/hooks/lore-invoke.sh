#!/usr/bin/env bash
# lore-invoke.sh — resolve how to run the Lore CLI (synced from tools/lore/scripts/lore-invoke.sh).

lore_find_monorepo_cli() {
	local start="$1"
	local d="$start"
	local i
	for i in 1 2 3 4 5 6; do
		if [[ -f "$d/tools/lore/bin/cli.ts" ]]; then
			echo "$d/tools/lore/bin/cli.ts"
			return 0
		fi
		local parent
		parent="$(dirname "$d")"
		[[ "$parent" == "$d" ]] && break
		d="$parent"
	done
	return 1
}

lore_cli_run() {
	if [[ -n "${LORE_CLI:-}" ]]; then
		# shellcheck disable=SC2086
		$LORE_CLI "$@"
		return $?
	fi
	local _here
	_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	local _mono
	if _mono="$(lore_find_monorepo_cli "$_here")"; then
		if [[ -f "$_mono" ]]; then
			bun "$_mono" "$@"
			return $?
		fi
	fi
	if command -v lore >/dev/null 2>&1; then
		lore "$@"
		return $?
	fi
	bunx @onlooker-community/lore "$@" 2>/dev/null || true
	return 0
}

lore_enabled_default_true() {
	local v="${1:-true}"
	[[ "$v" != "false" ]]
}
