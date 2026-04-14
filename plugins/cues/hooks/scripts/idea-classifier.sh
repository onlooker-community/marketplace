#!/usr/bin/env bash
set -euo pipefail

# idea-classifier.sh - Classify ideas in user prompts
# Detects when users express ideas that should be captured
#
# Called by: UserPromptSubmit hook
# Input: CLAUDE_USER_PROMPT
# Output: hookSpecificOutput.context with classification hint if detected

PROMPT="${CLAUDE_USER_PROMPT:-}"

if [[ -z "$PROMPT" ]]; then
    exit 0
fi

# Lowercase for matching
prompt_lower=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Idea indicators
IDEA_PATTERNS=(
    "what if"
    "we could"
    "we should"
    "i was thinking"
    "idea:"
    "maybe we"
    "how about"
    "wouldn't it be"
    "it would be nice"
    "future:"
    "todo:"
    "note to self"
    "remember to"
    "later:"
)

# Check for idea patterns
matched_pattern=""
for pattern in "${IDEA_PATTERNS[@]}"; do
    if [[ "$prompt_lower" == *"$pattern"* ]]; then
        matched_pattern="$pattern"
        break
    fi
done

if [[ -z "$matched_pattern" ]]; then
    exit 0
fi

# Determine idea type based on context
idea_type="general"

if [[ "$prompt_lower" == *"bug"* || "$prompt_lower" == *"fix"* || "$prompt_lower" == *"broken"* ]]; then
    idea_type="bug"
elif [[ "$prompt_lower" == *"feature"* || "$prompt_lower" == *"add"* || "$prompt_lower" == *"implement"* ]]; then
    idea_type="feature"
elif [[ "$prompt_lower" == *"refactor"* || "$prompt_lower" == *"clean"* || "$prompt_lower" == *"improve"* ]]; then
    idea_type="improvement"
elif [[ "$prompt_lower" == *"doc"* || "$prompt_lower" == *"readme"* || "$prompt_lower" == *"comment"* ]]; then
    idea_type="documentation"
fi

context="# Idea Detected

This prompt contains what appears to be an idea or future consideration (matched: \"${matched_pattern}\").

**Type:** ${idea_type}

Consider:
- Should this be captured in a task list?
- Is this actionable now or deferred?
- Does it relate to existing work?"

jq -n --arg context "$context" '{hookSpecificOutput: {context: $context}}'
