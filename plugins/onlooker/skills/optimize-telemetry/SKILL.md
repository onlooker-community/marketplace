---
name: optimize-telemetry
description: Optimize what metrics Onlooker tracks based on usage patterns
allowed-tools: Read Grep Bash
context: fork
agent: Explore
---

# Optimize Telemetry Skill

Analyze current telemetry and suggest optimizations.

## Analysis

1. Review ~/.claude/logs/agent-events.jsonl
2. Check which metrics are actually used
3. Identify unused hooks or metrics
4. Check for missing metrics that would be valuable
5. Suggest optimizations

## Recommendations

Provide:

- Which hooks can be removed (unused)
- Which metrics could be added (missing)
- How often events are emitted
- Total log file size trends
- Performance impact

## Output

A clear optimization plan:

- What to remove
- What to add
- How it improves observability
