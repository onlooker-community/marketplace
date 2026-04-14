---
description: Edit an existing cue's triggers or content
arguments:
  - name: name
    description: Cue name to edit
    required: true
---

# Edit Cue

Edit an existing cue's triggers or guidance content.

## Arguments

- **name**: The cue name to edit (e.g., `commit`, `api-design`)

## Instructions

1. **Find the cue** in order of priority:
   - Project: `.claude/cues/{{name}}/cue.md`
   - User: `~/.claude/cues/{{name}}/cue.md`

2. **If not found**, suggest using `/create-cue` instead

3. **Read and display current cue**:
   - Show current triggers (pattern, commands, files, vocabulary, description)
   - Show current scope
   - Show current content
   - Note if macro.sh exists

4. **Ask what to edit**:
   - Triggers (pattern, commands, files, vocabulary, description)
   - Scope (agent, subagent, or both)
   - Content (the guidance text)
   - Macro (add, edit, or remove macro.sh)

5. **Apply changes** using the Edit tool to modify `cue.md`

6. **Confirm changes** and show the updated cue

## Example

```txt
Editing cue: commit
Location: ~/.claude/cues/commit/cue.md

Current triggers:
- pattern: commit|push
- commands: git (commit|push)
- vocabulary: commit, push, merge
- scope: agent

What would you like to edit?
1. Triggers
2. Scope
3. Content
4. Macro
```

## Notes

- Changes take effect immediately for new sessions
- Current session markers are not affected (cue won't re-fire if already fired)
- To test changes, start a new session or clear markers with `/clear-cue-markers`
