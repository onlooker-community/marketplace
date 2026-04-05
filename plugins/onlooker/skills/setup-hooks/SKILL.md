---
name: setup-hooks
description: Help set up custom Onlooker hooks for specific use cases
allowed-tools: Read Write
context: fork
agent: general-purpose
---

# Setup Custom Hooks Skill

Help the user create custom hooks for their specific needs.

## Hook types

1. **PostToolUse** - Run after a tool succeeds
2. **PreToolUse** - Block or modify a tool before it runs
3. **SessionStart** - Run when a session starts
4. **ConfigChange** - React to config file changes
5. **Stop** - Run when Claude finishes

## Process

1. Understand what the user wants to track
2. Suggest appropriate hook event type
3. Provide example hook code
4. Help integrate into ~/.claude/onlooker/hooks/hooks.json
5. Verify it works

## Example use cases

- Format files after edits
- Block dangerous commands
- Alert on completion
- Track specific metrics
- Validate outputs
