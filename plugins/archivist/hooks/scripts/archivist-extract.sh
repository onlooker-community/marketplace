#!/usr/bin/env bash
# Archivist extraction script.
# Invoked by the PreCompact hook (via command fallback) or SessionEnd (--finalize).
# Reads hook input from stdin, writes structured session JSON to storage.
# Must never raise exceptions or block compaction/session end.
#
# Usage:
#   echo "$INPUT" | archivist-extract.sh            # extract from stdin
#   archivist-extract.sh --finalize                 # mark most recent session complete

set -uo pipefail  # No -e: we must never exit non-zero and block Claude

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=archivist-utils.sh
source "$SCRIPT_DIR/archivist-utils.sh"

# ----------------------------------------------------------------------------
# finalize_session
# Finds the most recently modified session JSON and marks it complete.
# ----------------------------------------------------------------------------
finalize_session() {
  local storage_dir
  storage_dir=$(archivist_get_storage_path)
  [[ -d "$storage_dir" ]] || return 0

  # Find most recently modified .json file
  local session_file
  session_file=$(find "$storage_dir" -maxdepth 1 -name "*.json" -type f \
    -exec ls -t {} + 2>/dev/null | head -1)

  [[ -z "$session_file" || ! -f "$session_file" ]] && return 0

  # Skip if already complete
  local already_complete
  already_complete=$(jq -r '.complete // false' "$session_file" 2>/dev/null) || return 0
  [[ "$already_complete" == "true" ]] && return 0

  local completed_at
  completed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Write updated file atomically via temp file
  local tmp
  tmp=$(mktemp) || return 0
  jq --arg completed_at "$completed_at" \
    '.complete = true | .completed_at = $completed_at' \
    "$session_file" > "$tmp" 2>/dev/null \
    && mv "$tmp" "$session_file" 2>/dev/null \
    || rm -f "$tmp" 2>/dev/null

  return 0
}

# ----------------------------------------------------------------------------
# extract_from_stdin
# Reads JSON from stdin and writes a structured session file to storage.
# ----------------------------------------------------------------------------
extract_from_stdin() {
  local raw
  raw=$(cat) || return 0
  [[ -z "${raw// }" ]] && return 0  # empty/whitespace-only input

  # Validate JSON and require session_id
  local session_id
  session_id=$(echo "$raw" | jq -r '.session_id // empty' 2>/dev/null) || return 0
  [[ -z "$session_id" ]] && return 0

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build the session document:
  # - Use existing timestamp if present, otherwise inject one
  # - Ensure all required category arrays exist (defaulting to [])
  # - Set complete: false
  local session_json
  session_json=$(echo "$raw" | jq \
    --arg timestamp "$timestamp" \
    '
      . as $input |
      {
        session_id: $input.session_id,
        timestamp:  ($input.timestamp // $timestamp),
        decisions:      ($input.decisions      // []),
        files:          ($input.files          // []),
        dead_ends:      ($input.dead_ends      // []),
        open_questions: ($input.open_questions // []),
        complete: false
      }
      + (del($input.session_id, $input.timestamp,
             $input.decisions, $input.files,
             $input.dead_ends, $input.open_questions) | $input)
    ' 2>/dev/null) || return 0

  archivist_write_session "$session_id" "$session_json" > /dev/null
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
if [[ "${1:-}" == "--finalize" ]]; then
  finalize_session
else
  extract_from_stdin
fi

exit 0
