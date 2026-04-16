#!/bin/bash
# Query Onlooker events

LOGFILE="$HOME/.claude/logs/agent-events.jsonl"

if [ ! -f "$LOGFILE" ]; then
    echo "No events logged yet. Run an agent with hooks configured."
    exit 1
fi

case "$1" in
    count)
        wc -l < "$LOGFILE"
        ;;
    recent)
        tail -n "${2:-10}" "$LOGFILE" | jq '.'
        ;;
    by-type)
        jq -r '.event_type' "$LOGFILE" | sort | uniq -c
        ;;
    by-agent)
        jq -r '.agent_id // .session_id' "$LOGFILE" | sort | uniq -c
        ;;
    *)
        echo "Usage: $0 {count|recent|by-type|by-agent}"
        exit 1
        ;;
esac
