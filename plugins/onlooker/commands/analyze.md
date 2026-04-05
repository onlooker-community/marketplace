---
name: analyze
description: Analyze your agent metrics
disable-model-invocation: false
argument-hint: [metric] [timeframe]
---

# Analyze Agent Metrics

Analyze collected metrics from your agents.

## Usage examples

- `/onlooker:analyze cost weekly` - Weekly cost analysis
- `/onlooker:analyze performance today` - Today's performance
- `/onlooker:analyze errors this-week` - Error analysis
- `/onlooker:analyze tools all-time` - All-time tool usage

## What gets analyzed

- Invocation counts & success rates
- Average & p95 latency
- Token usage & costs
- Tool usage patterns
- Error types & frequency
- Trends & improvements

Results are printed to the terminal and can be exported.
