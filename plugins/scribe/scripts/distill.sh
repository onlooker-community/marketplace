#!/usr/bin/env bash
# Scribe distillation engine.
#
# Reads capture entries, optionally enriches with Archivist context,
# and produces documentation artifacts in the configured output directory.
#
# Invoked by Stop/SessionEnd hooks or manually via /scribe:distill.
# Must never raise exceptions or block session end.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
# shellcheck source=lore-invoke.sh
if [[ -f "$SCRIPT_DIR/lore-invoke.sh" ]]; then
    source "$SCRIPT_DIR/lore-invoke.sh"
else
    lore_cli_run() { :; }
    lore_enabled_default_true() { [[ "${1:-true}" != "false" ]]; }
fi

slugify() {
    local text="$1"
    text="${text,,}"
    text="${text//[^a-z0-9 _-]/ }"
    text="$(echo "$text" | tr -s '[:space:]_' '-')"
    text="$(echo "$text" | sed 's/^-//;s/-$//')"
    echo "${text:0:60}"
}

build_change_log() {
    local session_id="$1"
    local captures="$2"
    local archivist_session="$3"
    local cwd="$4"

    local date
    date="$(date -u +"%Y-%m-%d")"
    local session_short="${session_id:0:8}"
    local capture_count
    capture_count="$(echo "$captures" | jq 'length')"

    local output=""
    output+="# Changes: $date"$'\n\n'
    output+="_Session: $session_short - $capture_count files - ${cwd}_"$'\n\n'

    local seen_files=""
    local i
    for (( i=0; i<capture_count; i++ )); do
        local cap
        cap="$(echo "$captures" | jq -c ".[$i]")"
        local file_path
        file_path="$(echo "$cap" | jq -r '.file // "unknown"')"

        if echo "$seen_files" | grep -qF "$file_path"; then
            continue
        fi
        seen_files+="$file_path"$'\n'

        local intent decision tradeoffs
        intent="$(echo "$cap" | jq -r '.intent // ""')"
        decision="$(echo "$cap" | jq -r '.decision // empty' 2>/dev/null)" || decision=""
        tradeoffs="$(echo "$cap" | jq -r '.tradeoffs // empty' 2>/dev/null)" || tradeoffs=""

        if [[ -n "$intent" ]]; then
            output+="**\`$file_path\`** - $intent"$'\n'
            [[ -n "$decision" ]] && output+="  Decision: $decision"$'\n'
            [[ -n "$tradeoffs" ]] && output+="  Tradeoffs: $tradeoffs"$'\n'
            output+=$'\n'
        fi
    done

    if [[ "$archivist_session" != "null" ]]; then
        local dead_end_count
        dead_end_count="$(echo "$archivist_session" | jq '.dead_ends // [] | length')"
        if [[ "$dead_end_count" -gt 0 ]]; then
            output+="## Approaches tried and abandoned"$'\n\n'
            local j
            for (( j=0; j<dead_end_count; j++ )); do
                local approach why
                approach="$(echo "$archivist_session" | jq -r ".dead_ends[$j].approach // \"\"")"
                why="$(echo "$archivist_session" | jq -r ".dead_ends[$j].why_failed // \"\"")"
                [[ -n "$approach" ]] && output+="- **$approach** - $why"$'\n'
            done
            output+=$'\n'
        fi
    fi

    output+="## Files changed"$'\n\n'
    for (( i=0; i<capture_count; i++ )); do
        local cap
        cap="$(echo "$captures" | jq -c ".[$i]")"
        local file_path intent
        file_path="$(echo "$cap" | jq -r '.file // "unknown"')"
        intent="$(echo "$cap" | jq -r '.intent // ""')"
        output+="- \`$file_path\` - $intent"$'\n'
    done
    output+=$'\n'

    echo "$output"
}

extract_decisions() {
    local captures="$1"
    local archivist_session="$2"

    local decisions="[]"
    local capture_count
    capture_count="$(echo "$captures" | jq 'length')"

    local i
    for (( i=0; i<capture_count; i++ )); do
        local cap
        cap="$(echo "$captures" | jq -c ".[$i]")"
        local decision tradeoffs
        decision="$(echo "$cap" | jq -r '.decision // empty' 2>/dev/null)" || decision=""
        tradeoffs="$(echo "$cap" | jq -r '.tradeoffs // empty' 2>/dev/null)" || tradeoffs=""

        if [[ -n "$decision" && -n "$tradeoffs" ]]; then
            decisions="$(echo "$decisions" | jq \
                --arg file "$(echo "$cap" | jq -r '.file // ""')" \
                --arg decision "$decision" \
                --arg tradeoffs "$tradeoffs" \
                --arg intent "$(echo "$cap" | jq -r '.intent // ""')" \
                '. + [{file: $file, decision: $decision, tradeoffs: $tradeoffs, intent: $intent}]')"
        fi
    done

    if [[ "$archivist_session" != "null" ]]; then
        local arch_decisions
        arch_decisions="$(echo "$archivist_session" | jq -c '.decisions // []')"
        local arch_count
        arch_count="$(echo "$arch_decisions" | jq 'length')"

        local j
        for (( j=0; j<arch_count; j++ )); do
            local confidence
            confidence="$(echo "$arch_decisions" | jq -r ".[$j].confidence // \"\"")"
            if [[ "$confidence" == "high" ]]; then
                decisions="$(echo "$decisions" | jq \
                    --arg rule "$(echo "$arch_decisions" | jq -r ".[$j].rule // \"\"")" \
                    --arg rationale "$(echo "$arch_decisions" | jq -r ".[$j].rationale // \"\"")" \
                    '. + [{file: "", decision: $rule, tradeoffs: $rationale, intent: "Archivist-captured decision", source: "archivist"}]')"
            fi
        done
    fi

    echo "$decisions"
}

build_decision_doc() {
    local decision_json="$1"
    local date="$2"
    local session_short="$3"

    local decision tradeoffs intent file_path
    decision="$(echo "$decision_json" | jq -r '.decision // ""')"
    tradeoffs="$(echo "$decision_json" | jq -r '.tradeoffs // ""')"
    intent="$(echo "$decision_json" | jq -r '.intent // ""')"
    file_path="$(echo "$decision_json" | jq -r '.file // ""')"

    local output=""
    output+="## $date (Session: $session_short)"$'\n\n'
    output+="**Decision:** $decision"$'\n\n'
    [[ -n "$tradeoffs" ]] && { output+="**Tradeoffs:** $tradeoffs"$'\n\n'; }
    [[ -n "$intent" ]] && { output+="**Context:** $intent"$'\n\n'; }
    [[ -n "$file_path" ]] && { output+="**File:** \`$file_path\`"$'\n\n'; }

    echo "$output"
}

distill_session() {
    local session_id="$1"
    local cwd="$2"
    local trigger="${3:-manual}"

    local config
    config="$(get_config)"
    local captures
    captures="$(read_captures "$session_id")"
    local capture_count
    capture_count="$(echo "$captures" | jq 'length')"

    [[ "$capture_count" -eq 0 ]] && return

    if [[ "$trigger" == "stop" ]]; then
        local min_captures
        min_captures="$(scribe_config_get "$config" '.min_captures_for_stop_distill' '3')"
        [[ "$capture_count" -lt "$min_captures" ]] && return
    fi

    local archivist_session
    archivist_session="$(find_archivist_session "$session_id")"

    local change_log
    change_log="$(build_change_log "$session_id" "$captures" "$archivist_session" "$cwd")"

    local date
    date="$(date -u +"%Y-%m-%d")"
    local session_short="${session_id:0:8}"

    local output_dir
    output_dir="$(get_output_dir "$cwd")"
    echo "$change_log" > "$output_dir/changes/$date-$session_short.md" 2>/dev/null || true

    local decisions
    decisions="$(extract_decisions "$captures" "$archivist_session")"
    local decision_count
    decision_count="$(echo "$decisions" | jq 'length')"

    local i
    for (( i=0; i<decision_count; i++ )); do
        local dec
        dec="$(echo "$decisions" | jq -c ".[$i]")"
        local decision_text
        decision_text="$(echo "$dec" | jq -r '.decision // ""')"
        [[ -z "$decision_text" ]] && continue

        local slug
        slug="$(slugify "${decision_text:0:50}")"
        [[ -z "$slug" ]] && continue

        local decision_path="$output_dir/decisions/$slug.md"
        local doc_section
        doc_section="$(build_decision_doc "$dec" "$date" "$session_short")"

        if [[ -f "$decision_path" ]]; then
            printf '\n---\n\n%s' "$doc_section" >> "$decision_path" 2>/dev/null || true
        else
            printf '# %s\n\n%s' "${decision_text:0:80}" "$doc_section" > "$decision_path" 2>/dev/null || true
        fi
    done

    local index_path="$output_dir/index.md"
    local summary
    summary="$(echo "$captures" | jq -r '.[0].intent // "Session changes"')"

    if [[ ! -f "$index_path" ]]; then
        printf '# Scribe Documentation Index\n\n' > "$index_path" 2>/dev/null || true
    fi
    printf -- '- [%s - %s](changes/%s-%s.md)\n' "$date" "$summary" "$date" "$session_short" >> "$index_path" 2>/dev/null || true

    mark_session_distilled "$session_id"

    local lore_on
    lore_on="$(scribe_config_get "$config" '.lore_enabled' 'true')"
    if lore_enabled_default_true "$lore_on"; then
        local tmp
        tmp="$(mktemp)" || true
        if [[ -n "$tmp" ]]; then
            jq -n \
                --arg sid "$session_id" \
                --arg cwd "$cwd" \
                --argjson caps "$captures" \
                '{session_id: $sid, cwd: $cwd, captures: $caps}' > "$tmp" 2>/dev/null \
                && lore_cli_run ingest --format scribe-session --file "$tmp" 2>/dev/null || true
            rm -f "$tmp" 2>/dev/null || true
        fi
    fi
}

main() {
    local trigger="manual"
    local session_id=""
    local distill_all=false
    local cwd
    cwd="$(pwd)"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --trigger) trigger="$2"; shift 2 ;;
            --session) session_id="$2"; shift 2 ;;
            --all) distill_all=true; shift ;;
            --cwd) cwd="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ "$distill_all" == "true" ]]; then
        local sessions
        sessions="$(find_undistilled_sessions)"
        local count
        count="$(echo "$sessions" | jq 'length')"
        local i
        for (( i=0; i<count; i++ )); do
            local sid
            sid="$(echo "$sessions" | jq -r ".[$i]")"
            distill_session "$sid" "$cwd" "$trigger"
        done
    elif [[ -n "$session_id" ]]; then
        distill_session "$session_id" "$cwd" "$trigger"
    else
        local sessions
        sessions="$(find_undistilled_sessions)"
        local count
        count="$(echo "$sessions" | jq 'length')"
        if [[ "$count" -gt 0 ]]; then
            local last_sid
            last_sid="$(echo "$sessions" | jq -r '.[-1]')"
            distill_session "$last_sid" "$cwd" "$trigger"
        fi
    fi
}

main "$@" 2>/dev/null || true
