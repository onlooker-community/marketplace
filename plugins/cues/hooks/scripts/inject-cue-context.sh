#!/usr/bin/env bash
set -euo pipefail

# inject-cue-context.sh - Inject cue system context on session start
# Provides Claude with information about available cues
#
# Called by: SessionStart hook
# Output: hookSpecificOutput.context with cue system overview

# Cue directories to scan
CUE_DIRS=()
if [[ -n "${CLAUDE_PROJECT_ROOT:-}" && -d "${CLAUDE_PROJECT_ROOT}/.claude/cues" ]]; then
    CUE_DIRS+=("${CLAUDE_PROJECT_ROOT}/.claude/cues")
fi
if [[ -d "$HOME/.claude/cues" ]]; then
    CUE_DIRS+=("$HOME/.claude/cues")
fi

if [[ ${#CUE_DIRS[@]} -eq 0 ]]; then
    exit 0
fi

# Count available cues
cue_count=0
cue_names=()

for cue_dir in "${CUE_DIRS[@]}"; do
    while IFS= read -r -d '' cue_file; do
        cue_id=$(basename "$(dirname "$cue_file")")
        cue_names+=("$cue_id")
        ((cue_count++))
    done < <(find "$cue_dir" -name "cue.md" -print0 2>/dev/null || true)
done

if [[ $cue_count -eq 0 ]]; then
    exit 0
fi

# Build context output
context="# Cue System Active

${cue_count} cues available. Cues inject contextual guidance when triggers match prompts, commands, or files.

Available cues: $(IFS=', '; echo "${cue_names[*]}")

Cues fire automatically based on:
- **pattern:** Regex match on user prompts
- **commands:** Regex match on Bash commands
- **files:** Regex match on file paths (Write/Edit)
- **vocabulary:** Keyword presence in query
- **description:** Semantic similarity (Gzip NCD)

Each cue fires at most once per session."

# Output for hook system
jq -n --arg context "$context" '{hookSpecificOutput: {context: $context}}'
