---
description: List all available cues with their triggers
arguments:
  - name: scope
    description: Filter by scope (user, project, or all)
    required: false
---

# List Cues

List all available cues showing their triggers and recent activity.

## Arguments

- **scope**: Filter which cues to show:
  - `all` (default): Both user and project cues
  - `user`: Only `~/.claude/cues/`
  - `project`: Only `.claude/cues/` in current project

## Instructions

1. **Scan cue directories**:
   - User cues: `~/.claude/cues/*/cue.md`
   - Project cues: `.claude/cues/*/cue.md` (if in a project)

2. **For each cue found**, extract from YAML frontmatter:
   - Name (directory name)
   - Triggers: pattern, commands, files, vocabulary, description
   - Scope: agent/subagent
   - Has macro: yes/no

3. **Check recent activity** from `~/.claude/cues/cue-events.jsonl`:
   - Count fires in last 24 hours
   - Last fired timestamp

4. **Display as a table**:

```txt
| Cue Name | Location | Triggers | Fires (24h) | Last Fired |
|----------|----------|----------|-------------|------------|
| commit   | user     | pattern, vocab | 3      | 2h ago     |
| api-design | project | files    | 0          | never      |
```

1. **Show summary**:
   - Total cues found
   - Most active cue
   - Any dormant cues (never fired or not fired in 7+ days)

## Trigger Summary Format

Show abbreviated trigger types:

- `P` = pattern (prompt regex)
- `C` = commands (bash regex)
- `F` = files (file path regex)
- `V` = vocabulary (keyword list)
- `S` = semantic (description for NCD matching)
- `M` = macro (has macro.sh)

Example: `P,V,M` means pattern + vocabulary + macro

## Example Output

```txt
Cues (3 total)

| Name        | Loc     | Triggers | 24h | Last Fired |
|-------------|---------|----------|-----|------------|
| commit      | user    | P,C,V    | 5   | 1h ago     |
| api-design  | project | F,S      | 2   | 3h ago     |
| testing     | user    | P,V,M    | 0   | 3d ago     |

Summary:
- Most active: commit (5 fires)
- Dormant: testing (3 days since last fire)
```

## Notes

- Project cues override user cues with the same name
- Dormant cues may need trigger adjustments
- High-fire cues may be too sensitive
