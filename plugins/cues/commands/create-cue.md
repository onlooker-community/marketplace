---
description: Create a new cue with triggers and guidance content
arguments:
  - name: name
    description: Cue name (kebab-case)
    required: true
  - name: scope
    description: Where to create the cue (user or project)
    required: false
---

# Create Cue

Create a new cue that injects contextual guidance when triggers match.

## Arguments

- **name**: The cue name in kebab-case (e.g., `commit-guidance`, `api-design`)
- **scope**: Where to create the cue:
  - `user` (default): `~/.claude/cues/<name>/cue.md`
  - `project`: `.claude/cues/<name>/cue.md` in current project

## Instructions

1. **Validate the name** is kebab-case (lowercase, hyphens only)

2. **Determine the target directory**:
   - User scope: `~/.claude/cues/{{name}}/`
   - Project scope: `.claude/cues/{{name}}/` (relative to project root)

3. **Check if cue already exists** at that location. If so, ask user to confirm overwrite or choose a different name.

4. **Gather trigger configuration** by asking the user:

   **Required (at least one):**
   - `pattern`: Regex to match user prompts (e.g., `commit|push|merge`)
   - `commands`: Regex to match Bash commands (e.g., `git (commit|push)`)
   - `files`: Regex to match file paths (e.g., `\.md$|README`)
   - `vocabulary`: Keywords that trigger the cue (list of words)
   - `description`: Text for semantic matching via Gzip NCD

   **Optional:**
   - `scope`: `agent`, `subagent`, or both (default: `agent`)
   - `macro`: `prepend` or `append` (if dynamic content needed)

5. **Gather the cue content** - the guidance text that will be injected when triggered

6. **Create the cue file** with this structure:

```markdown
---
pattern: <regex if provided>
commands: <regex if provided>
files: <regex if provided>
vocabulary:
  - keyword1
  - keyword2
description: <description for semantic matching>
scope: agent
---

<cue content here>
```

1. **If macro was specified**, also create `macro.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# Dynamic content script for {{name}} cue
# Output will be prepended/appended to the cue body

echo "Dynamic content here"
```

1. **Confirm creation** and show the user:
   - Full path to created cue
   - Summary of triggers configured
   - How to test: explain that the cue will fire when triggers match

## Example Cue

A commit guidance cue at `~/.claude/cues/commit/cue.md`:

```markdown
---
pattern: commit|push
commands: git (commit|push|merge)
vocabulary:
  - commit
  - push
  - merge
  - pr
description: Guidance for git commits and pushes
scope: agent
---

# Commit / Push Cue

- Prefer **conventional commits**: `type(scope): message`
- Keep subject under 72 characters
- Ensure tests pass before pushing
```

## Notes

- Cues fire at most once per session (markers in `/tmp/.claude-cue-*`)
- Project cues take priority over user cues with the same name
- Use `vocabulary` for simple keyword matching, `pattern` for precise regex control
- The `description` field enables semantic matching using Gzip NCD similarity
