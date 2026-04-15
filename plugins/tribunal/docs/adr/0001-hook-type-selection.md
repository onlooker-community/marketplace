# 0001 - Hook type selection for quality gate events

Date: 2026-04-02
Status: Accepted

## Context and Problem Statement

Tribunal uses two hooks to wire up its automatic quality gate:

1. A `PostToolUse` hook that fires after every `Write|Edit` tool call to evaluate the file that was just written.
2. A `SubagentStop` hook that fires when the Actor agent completes, to run Meta-Judge evaluation on the Judge's verdict.

Claude Code plugin hooks support four handler types: `command`, `http`, `prompt`, and `agent`. Choosing the wrong type produces an invalid `hooks.json` that silently fails or prevents the plugin from loading.

The first scaffold used `type: "agent"` with an `agent` key and a `background` key — neither of which exist in the hook handler schema. This was discovered only after attempting to install and run the plugin.

## Decision Drivers

- `PostToolUse` needs to read the file that was just written and evaluate its content against a rubric — this requires tool access (Read, Grep, Glob), ruling out `type: "prompt"` which is single-turn with no tools.
- `SubagentStop` needs to evaluate a Judge verdict that is already present in context — this is a single-turn reasoning task with no file access required, making `type: "prompt"` sufficient and cheaper.
- `async: true` is only valid on `type: "command"` hooks. Agent and prompt hooks are always synchronous — they block until the evaluation completes, which is correct behavior for a quality gate.
- Plugin agent names are namespaced (`tribunal:tribunal-judge`), not bare (`tribunal-judge`). Hook matchers for `SubagentStop` must use the namespaced form.

## Considered Options

- **Option A:** `type: "agent"` for both hooks with named agent references
- **Option B:** `type: "agent"` for PostToolUse, `type: "prompt"` for SubagentStop
- **Option C:** `type: "command"` for both, shelling out to a script

## Decision Outcome

Chosen: **Option B**.

`PostToolUse` uses `type: "agent"` with an inline `prompt` field, giving the evaluator tool access to read the written file. `SubagentStop` uses `type: "prompt"` with an inline `prompt` field for single-turn verdict review.

Option A was invalid — there is no `agent` key on hook handlers; the correct field is `prompt` for both `agent` and `prompt` types. Option C was rejected because it would require bundling shell scripts and managing execution permissions, adding complexity without benefit over the native hook types.

### Consequences

- Good: The `PostToolUse` agent hook can read files using the Read tool, enabling rubric-grounded evaluation of actual file content.
- Good: The `SubagentStop` prompt hook is cheaper and faster for verdict review, which requires no file access.
- Bad: The inline `prompt` field in `hooks.json` duplicates logic that also lives in `agents/judge.md` and `agents/meta-judge.md`. Changes to judge behavior must be reflected in both places.
- Note: The `background` field does not exist on any hook handler type. Async execution uses `async: true` and is only valid on `type: "command"` hooks.

## Links

- Claude Code hooks reference: https://code.claude.com/docs/en/hooks
- Plugins reference: https://code.claude.com/docs/en/plugins-reference
- Supersedes: initial scaffold `hooks.json` (pre-0001)
