---
name: analyze-metrics
description: Analyze Onlooker metrics to identify patterns, improvements, and anomalies in agent behavior
allowed-tools: Read Bash Grep
context: fork
agent: Explore
---

# Analyze Metrics Skill

Query and analyze agent metrics from the JSONL event log.

## Data location

Events are stored at: ~/.claude/logs/agent-events.jsonl
Each line is a JSON object with: timestamp, agent_id, event_type, payload

## Analysis tasks

For "$ARGUMENTS", analyze:

1. **Invocation metrics**
   - Total invocations
   - Success vs error rate
   - Trends over time

2. **Performance**
   - Average latency
   - P95 latency
   - Tokens per invocation

3. **Cost**
   - Cost per invocation
   - Total weekly cost
   - Cost trends

4. **Tools**
   - Most used tools
   - Tool success rates
   - Tool failure patterns

5. **Errors**
   - Error types
   - Error frequency
   - When errors occur

Use `jq` and `grep` to query the JSONL file. Provide specific numbers and charts.
