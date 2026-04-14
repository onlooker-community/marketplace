#!/usr/bin/env bash
set -euo pipefail

# match-cues.sh - Core cue matching logic
# Matches query against cues using: pattern/commands/files regex → vocabulary → semantic (Gzip NCD)
#
# Usage: match-cues.sh <trigger_type> <query>
#   trigger_type: prompt | command | file
#   query: The text to match against
#
# Output: JSON array of matched cue paths, sorted by priority

TRIGGER_TYPE="${1:-prompt}"
QUERY="${2:-}"

if [[ -z "$QUERY" ]]; then
    echo "[]"
    exit 0
fi

# Cue directories to search (project cues take priority)
CUE_DIRS=()
if [[ -n "${CLAUDE_PROJECT_ROOT:-}" && -d "${CLAUDE_PROJECT_ROOT}/.claude/cues" ]]; then
    CUE_DIRS+=("${CLAUDE_PROJECT_ROOT}/.claude/cues")
fi
if [[ -d "$HOME/.claude/cues" ]]; then
    CUE_DIRS+=("$HOME/.claude/cues")
fi

if [[ ${#CUE_DIRS[@]} -eq 0 ]]; then
    echo "[]"
    exit 0
fi

# Calculate Gzip NCD (Normalized Compression Distance) for semantic matching
calculate_ncd() {
    local str1="$1"
    local str2="$2"

    # Get compressed sizes
    local c1 c2 c12
    c1=$(printf '%s' "$str1" | gzip -c | wc -c)
    c2=$(printf '%s' "$str2" | gzip -c | wc -c)
    c12=$(printf '%s%s' "$str1" "$str2" | gzip -c | wc -c)

    # NCD = (C(x,y) - min(C(x), C(y))) / max(C(x), C(y))
    local min_c max_c
    if [[ $c1 -lt $c2 ]]; then
        min_c=$c1
        max_c=$c2
    else
        min_c=$c2
        max_c=$c1
    fi

    if [[ $max_c -eq 0 ]]; then
        echo "1.0"
        return
    fi

    # Return NCD as a decimal (lower = more similar)
    awk "BEGIN {printf \"%.4f\", ($c12 - $min_c) / $max_c}"
}

# Extract YAML frontmatter field
extract_field() {
    local file="$1"
    local field="$2"

    # Extract value after "field:" from YAML frontmatter
    sed -n '/^---$/,/^---$/p' "$file" 2>/dev/null | \
        grep -E "^${field}:" | \
        sed "s/^${field}:[[:space:]]*//" | \
        tr -d '"'"'" || true
}

# Extract array field (one item per line)
extract_array_field() {
    local file="$1"
    local field="$2"

    sed -n '/^---$/,/^---$/p' "$file" 2>/dev/null | \
        sed -n "/^${field}:/,/^[a-z]/p" | \
        grep -E '^[[:space:]]*-' | \
        sed 's/^[[:space:]]*-[[:space:]]*//' | \
        tr -d '"'"'" || true
}

# Check if cue should fire based on scope
check_scope() {
    local file="$1"
    local scope
    scope=$(extract_field "$file" "scope")

    # Default scope is "agent"
    if [[ -z "$scope" ]]; then
        scope="agent"
    fi

    local is_subagent="${CLAUDE_IS_SUBAGENT:-false}"

    if [[ "$is_subagent" == "true" && "$scope" != *"subagent"* ]]; then
        return 1
    fi

    if [[ "$is_subagent" != "true" && "$scope" != *"agent"* ]]; then
        return 1
    fi

    return 0
}

# Check if cue has already fired this session
check_not_fired() {
    local cue_id="$1"
    local marker="/tmp/.claude-cue-${cue_id}-${CLAUDE_SESSION_ID:-default}"

    if [[ -f "$marker" ]]; then
        return 1
    fi
    return 0
}

# Match cue against query
# Returns: priority (0=regex match, 1=vocabulary, 2=semantic) or empty if no match
match_cue() {
    local cue_file="$1"
    local cue_id
    cue_id=$(basename "$(dirname "$cue_file")")

    # Check scope and once-per-session gating
    if ! check_scope "$cue_file"; then
        return
    fi

    if ! check_not_fired "$cue_id"; then
        return
    fi

    # Priority 0: Regex pattern match
    case "$TRIGGER_TYPE" in
        prompt)
            local pattern
            pattern=$(extract_field "$cue_file" "pattern")
            if [[ -n "$pattern" ]] && echo "$QUERY" | grep -qE "$pattern" 2>/dev/null; then
                echo "0"
                return
            fi
            ;;
        command)
            local commands
            commands=$(extract_field "$cue_file" "commands")
            if [[ -n "$commands" ]] && echo "$QUERY" | grep -qE "$commands" 2>/dev/null; then
                echo "0"
                return
            fi
            ;;
        file)
            local files
            files=$(extract_field "$cue_file" "files")
            if [[ -n "$files" ]] && echo "$QUERY" | grep -qE "$files" 2>/dev/null; then
                echo "0"
                return
            fi
            ;;
    esac

    # Priority 1: Vocabulary match (any word in vocabulary appears in query)
    local vocab
    vocab=$(extract_array_field "$cue_file" "vocabulary")
    if [[ -n "$vocab" ]]; then
        local query_lower
        query_lower=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')
        while IFS= read -r word; do
            word_lower=$(echo "$word" | tr '[:upper:]' '[:lower:]')
            if [[ -n "$word_lower" && "$query_lower" == *"$word_lower"* ]]; then
                echo "1"
                return
            fi
        done <<< "$vocab"
    fi

    # Priority 2: Semantic match using Gzip NCD
    local description
    description=$(extract_field "$cue_file" "description")
    if [[ -n "$description" ]]; then
        local ncd
        ncd=$(calculate_ncd "$QUERY" "$description")
        # Threshold: NCD < 0.9 indicates similarity
        if awk "BEGIN {exit !($ncd < 0.9)}"; then
            echo "2:$ncd"
            return
        fi
    fi
}

# Collect all matches
declare -A MATCHES

for cue_dir in "${CUE_DIRS[@]}"; do
    while IFS= read -r -d '' cue_file; do
        cue_id=$(basename "$(dirname "$cue_file")")

        # Skip if already matched (project cues take priority)
        if [[ -n "${MATCHES[$cue_id]:-}" ]]; then
            continue
        fi

        result=$(match_cue "$cue_file")
        if [[ -n "$result" ]]; then
            MATCHES[$cue_id]="$result|$cue_file"
        fi
    done < <(find "$cue_dir" -name "cue.md" -print0 2>/dev/null || true)
done

# Sort by priority and output as JSON array
{
    for cue_id in "${!MATCHES[@]}"; do
        echo "${MATCHES[$cue_id]}|$cue_id"
    done
} | sort -t'|' -k1,1n | while IFS='|' read -r _priority path _cue_id; do
    echo "$path"
done | jq -R -s 'split("\n") | map(select(length > 0))'
