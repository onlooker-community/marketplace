# 0002 — Command naming to avoid slash command namespace collision

Date: 2026-04-02
Status: Accepted

## Context and Problem Statement

Claude Code plugins namespace all components under the plugin name. A command file named `tribunal.md` in a plugin named `tribunal` produces the slash command `/tribunal:tribunal` — redundant and awkward to type.

The plugin needs a primary slash command that is natural to invoke, tab-completable, and clearly communicates its purpose without the namespace stutter.

## Decision Drivers

- Claude Code automatically prepends the plugin name as a namespace to all commands: `<plugin-name>:<command-name>`.
- The command name should read naturally after the namespace prefix.
- The primary action of the plugin is dispatching a task through the quality pipeline, so the command name should reflect that action.
- Short commands are typed more often — brevity matters.

## Considered Options

- **`tribunal.md`** → `/tribunal:tribunal` — redundant, awkward
- **`run.md`** → `/tribunal:run` — clear, action-oriented, reads naturally
- **`eval.md`** → `/tribunal:eval` — short, distinct, but less immediately readable
- **`gate.md`** → `/tribunal:gate` — conceptually accurate but less action-oriented
- **`judge.md`** → `/tribunal:judge` — collides with the agent name `tribunal-judge`

## Decision Outcome

Chosen: **`run.md`** → `/tribunal:run`.

`/tribunal:run` reads as a natural imperative ("run tribunal on this task") and is consistent with how similar CLI tools name their primary action. Subcommands (`status`, `pause`, `resume`, `verdict`, `config`) remain as arguments to `run` or as standalone invocations of the same command file via `$ARGUMENTS` parsing.

### Consequences

- Good: `/tribunal:run <task>` is natural to type and clearly communicates intent.
- Good: Avoids the namespace stutter of `/tribunal:tribunal`.
- Good: Tab autocomplete surfaces `/tribunal:run` immediately after typing `/tribunal:`.
- Neutral: All documentation and examples must use `/tribunal:run`, not `/tribunal`.
- Note: The plugin name itself (`tribunal`) cannot be used as a bare slash command without a subcommand name — this is a Claude Code platform constraint, not a Tribunal design choice.

## Links

- Claude Code slash commands reference: https://platform.claude.com/docs/en/agent-sdk/slash-commands
- Plugins reference (namespacing): https://code.claude.com/docs/en/plugins-reference#required-fields
