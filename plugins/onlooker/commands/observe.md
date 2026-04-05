---
name: observe
description: Set up Onlooker observation for an agent
disable-model-invocation: false
argument-hint: [agent-name]
---

# Observe an Agent

Set up Onlooker hooks for the agent named "$ARGUMENTS".

## What will happen

1. Your agent config will be read
2. Hooks will be added (if not present)
3. A JSONL log file will be created at ~/.claude/logs/agent-events.jsonl
4. Events will automatically log when your agent runs

## Next steps

After this, just run your agent normally. Events will emit automatically.

For help, run `/onlooker:help` or see ~/.claude/onlooker/docs/
