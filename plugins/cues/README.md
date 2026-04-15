# cues plugin

Cues inject contextual guidance when triggers match prompts, commands, or files.

Cues live in `~/.claude/cues/<name>/cue.md` (and optionally `$PROJECT/.claude/cues`). They are declarative guidance that fires when triggers match. Matching is done by a script (`match-cues.sh`) in priority order:

1. Regex match from `pattern:`, `commands:`, or `files:` fields.
2. Vocabulary matching (any word in `vocabulary:` appears in the query)
3. Semantic matching (using Gzip NCD to match similarity of query to `description:`)

## Trigger Flow

```txt
┌──────────────────────────────────────────────────────────────────────────────┐
│                            Cue Trigger Flow                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   User Prompt ──▶ pattern: regex ──┐                                         │
│   Bash Command ─▶ commands: regex ─┼──▶ match-cues.sh ──▶ show-cue.sh        │
│   File Path ────▶ files: regex ────┘         │                │              │
│                                              │                ▼              │
│                  vocabulary: keywords ───────┼──▶ Semantic   Macro           │
│                  description: text ──────────┘    Match      Execution       │
│                                                     │            │           │
│                                                     └─────┬──────┘           │
│                                                           ▼                  │
│                                              hookSpecificOutput.context      │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Scope Filtering

| Scope | Fires For |
| --- | --- |
| `agent` | Main agent only (default) |
| `subagent` | Spawned subagents only |
| `agent`, `subagent` | Both contexts |

## Macros

Cues with `macro: prepend|append` and a `macro.sh` script get dynamic content injected before/after the cue body.

## Once-Per-Session Gating

Each cue fires at most once per session. Markers in `/tmp/.claude-cue-*` track fired cues. `clear-cue-markers.sh` resets on `SessionStart`.

## Engagement Tracking

When a cue fires, `show-cue.sh` emits a `cue_fired` event to `~/.claude/cues/cue-events.jsonl`.

```json
{
    "event_type": "cue_fired",
    "payload": {
        "cue_id": "commit",
        "trigger_type": "prompt",
        "has_macro": false
    }
}
```

Use this data to show:

- Which cues are actively providing guidance
- Trigger patterns (prompt vs bash vs file)]
- Dormant cues that may need better triggers

## Commands

| Command | Description |
| --- | --- |
| `/create-cue` | Create a new cue with triggers and guidance content |
| `/list-cues` | List all available cues with their triggers and activity |
| `/edit-cue` | Edit an existing cue's triggers or content |

## Hooks

1. `SessionStart`: Hooks clear markers, inject context, escalate friction.
2. `UserPromptSubmit`: Cue injector matches prompt to cues
3. `PreToolUse`: Cue injector matches commands/files; layering guard validates
4. `PostToolUse`: Hooks extract impact, detect patterns, emit events
