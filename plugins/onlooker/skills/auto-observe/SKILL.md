---
name: auto-observe
description: Automatically configure Onlooker hooks for an agent. Claude analyzes the agent config and sets up complete observation.
allowed-tools:
  - Read
  - Write
  - Grep

context: fork
agent: general-purpose
---

# Auto-Observe Skill

Automatically configure Onlooker observation for an agent.

## Steps

1. Read the agent config from ~/.claude/agents/$ARGUMENTS.yml
2. Check if hooks are already configured
3. If not, add hook references to the config
4. Verify hooks exist at ~/.claude/onlooker/hooks/
5. Summarize what was set up

## Expected output

- Agent config is updated with hook references
- Confirmation that hooks are ready
- Path to the event log file
- Instructions for viewing metrics

If the agent already has hooks, skip to verification.
