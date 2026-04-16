# Troubleshooting

Common issues when installing and using Onlooker Marketplace plugins.

## Installation

### Plugin hooks aren't firing

**Symptoms:** A plugin is installed but its hooks never seem to run.

**Causes and fixes:**

1. **Plugin is in the wrong directory.** Claude Code loads plugins from `~/.claude/plugins/` (user scope) or `.claude/plugins/` (project scope). Verify the plugin is in one of these locations, not a subdirectory of them.

   ```bash
   ls ~/.claude/plugins/          # user-scope plugins
   ls .claude/plugins/            # project-scope plugins
   ```

2. **Session wasn't restarted after installation.** Hooks are registered at session start. If you installed a plugin mid-session, start a new session.

3. **Plugin doesn't have a `.claude-plugin/plugin.json`.** Claude Code uses this file to discover the plugin. Check it exists:

   ```bash
   cat .claude/plugins/<name>/.claude-plugin/plugin.json
   ```

### Slash commands aren't available

**Symptom:** `/plugin:command` returns "command not found" or doesn't appear in autocomplete.

**Fix:** The command file must be listed in `plugin.json` under `"commands"`. Verify the path in `plugin.json` matches the actual file:

```json
{
  "commands": ["./commands/my-command.md"]
}
```

Check that `commands/my-command.md` exists relative to the plugin root.

---

## Archivist

### Session memory isn't being injected on startup

**Possible causes:**

- No session extract exists for the current working directory yet. Archivist builds memory over time — on first install there's nothing to inject.
- The storage path doesn't exist or isn't writable. Check: `~/.claude/archivist/sessions/`
- The `PreCompact` hook didn't fire (no compaction happened in previous sessions).

Run `/archivist:memory status` to check the config and whether any sessions are stored.

### Memory from a different project is being injected

Archivist keys sessions by working directory. If you're getting the wrong context, the `cwd` stored in the extract doesn't match the current directory. Run `/archivist:memory forget --cwd` to clear it and start fresh.

---

## Ledger

### Budget is always zero / not tracking costs

Ledger reads token counts from Claude's usage data at the `Stop` event. If costs show as zero, the hook may not have access to the usage fields. Check the hook script for any permission or parsing errors by running `/ledger:budget status` directly.

### Subagent spawning is blocked unexpectedly

Ledger blocks `SubagentStart` when the session budget is exceeded. Run `/ledger:budget status` to see current spend and `/ledger:budget reset` to clear the session if you want to continue.

---

## Oracle

### Oracle is interrupting too often

Oracle fires on `UserPromptSubmit` and on high-consequence `PreToolUse` calls. If it's too aggressive, raise the confidence thresholds:

```
/oracle:calibrate threshold
```

Or disable it for the session:

```
/oracle:calibrate disable
```

You can also add patterns to `skip_patterns` in `config.json` to exempt specific command types.

### Oracle is never firing

Check that `confidence_threshold.flag` isn't set too low (near 0). If it's at 0, nothing will ever trigger the escalation path. Run `/oracle:calibrate show` to see current thresholds.

---

## Sentinel

### Sentinel is blocking a command that should be allowed

Run the dry-run evaluation to understand why it matched:

```
/sentinel:guard review <your-command>
```

To temporarily allow the matched pattern for this session:

```
/sentinel:guard allow --pattern <pattern-id>
```

To permanently add an exemption, edit the relevant pattern file in `plugins/sentinel/patterns/` and remove or narrow the matching rule.

### A dangerous command ran without triggering Sentinel

Sentinel uses an `if` condition on the `PreToolUse` hook. If the command doesn't match a pattern in any of the five pattern files (filesystem, git, environment, database, process), it won't be caught. Add a new pattern to the appropriate file in `plugins/sentinel/patterns/`.

---

## Warden

### The content gate closed and won't reopen

This is by design. Warden requires explicit clearance:

```
/warden:gate clear
```

Review the flagged content first with `/warden:gate audit` to understand what triggered it. If it was a false positive, you can then clear the gate.

### Warden is flagging legitimate content as injection

Review the active patterns with `/warden:gate patterns`. If a pattern is too broad, edit `plugins/warden/patterns/` to narrow the match. You can also add paths to `safe_paths` in `config.json` to exempt trusted sources (e.g., your own documentation).

---

## Tribunal

### Actor output never passes the quality gate

Check the passing score threshold in `config.json`. If it's set very high (e.g., 9.0 out of 10), most outputs will fail. Run `/tribunal:run verdict` to see the full score breakdown from the last evaluation — the Judge's feedback will indicate what's falling short.

### Meta-Judge is rejecting valid evaluations

The Meta-Judge checks for LLM judge biases. If it's consistently rejecting evaluations, the Judge's rubric application may be inconsistent. Check whether the rubric in use matches the task type — using the `code.md` rubric on a writing task will produce inconsistent scores.

### Tribunal is spending too much on evaluations

Tribunal spawns multiple subagents per evaluation (Actor + Judge panel + Meta-Judge). Install **ledger** to track and cap this spend. Reduce `maxIterations` and `judgeCount` in `config.json` if costs are too high.

---

## Echo

### Regression tests are failing after an expected improvement

A test result is `degraded` if the new score is lower than the baseline, even by a small amount. If you intentionally changed the agent and expect scores to change, re-record the baselines:

```
/echo:regression record
```

Commit the updated baselines to version control.

### Baselines don't exist yet

If this is a first install, run:

```
/echo:regression record
```

This runs the test suite once and stores the scores as the reference point for future comparisons.

---

## Relay

### The wrong handoff is being injected

Relay matches handoffs by working directory. If you're getting a stale or irrelevant handoff, clear it:

```
/relay:handoff clear
```

Or check what's stored with `/relay:handoff show --all` and identify the stale entry.

### Relay is injecting context for a completed task

Set `task.status: "complete"` in the handoff (or run the task to completion in a session where Relay fires). Relay skips injection when the last handoff is marked complete. Alternatively, `/relay:handoff clear` removes the handoff entirely.

---

## Counsel

### Counsel brief shows "no data" for most plugins

Counsel reads from plugin-specific output files. If a plugin isn't generating data (hooks not firing, storage paths wrong), Counsel has nothing to synthesize. Run `/counsel:brief sources` to check which data sources are available and their freshness.

### Brief isn't running on schedule

Counsel's weekly schedule depends on your Claude Code session lifecycle. If you don't start a session on the scheduled day, the brief won't run. Generate it manually anytime with `/counsel:brief generate`.

---

## Cues

### A cue isn't triggering when expected

Check the trigger conditions in the cue file (`~/.claude/cues/<name>/cue.md`). The `pattern` field is a regex matched against the user prompt. Test it locally:

```bash
echo "your prompt here" | grep -P "<your-pattern>"
```

Run `/list-cues` to confirm the cue is loaded and see its trigger configuration.

### A cue is triggering too broadly

Narrow the `pattern` regex in the cue file, or add a `files` or `commands` trigger to make it more specific. Use `/edit-cue` to modify it.

---

## Cartographer

### Cartographer reports a contradiction that isn't real

Cartographer uses an LLM to detect contradictions, so it can produce false positives for rules that are technically compatible. Review the reported contradiction with `/cartographer:audit issues --severity high`. If it's a false positive, you can add a comment to the relevant rule to clarify the intent, which will typically resolve it on the next audit.

### Audit isn't running

Cartographer audits on `InstructionsLoaded`, which fires when Claude Code loads your instruction files at session start. If no audit appears, check that the plugin is installed and the session was started after installation.

---

## General

### `~/.claude/` paths don't exist

Some plugins write to `~/.claude/` subdirectories on first run. If the parent directory doesn't exist:

```bash
mkdir -p ~/.claude
```

The plugins create their own subdirectories (`~/.claude/archivist/`, `~/.claude/relay/`, etc.) on first write.

### Hook scripts aren't executable

If you cloned the repository and hooks aren't running, the shell scripts may have lost their execute bit:

```bash
chmod +x plugins/<name>/hooks/*.sh
chmod +x plugins/<name>/scripts/*.sh
```

### mise: bun version not found

This repository uses `mise` to manage the Bun runtime. If `bun` isn't available:

```bash
mise install    # installs the version in mise.toml
```

If `mise` itself isn't installed, see [mise-en-place.jdx.dev](https://mise-en-place.jdx.dev).
