---
description: >
  Tribunal quality pipeline. Dispatches a task through Actor → Judge Panel →
  Meta-Judge with configurable quality gates. Supports manual task dispatch,
  session pause/resume, and verdict inspection.
allowed-tools: Read, Bash
---

You are running the Tribunal quality pipeline command.

Read the Tribunal config at `${CLAUDE_PLUGIN_ROOT}/config.json` to get
current settings (passingScore, maxIterations, panel size, defaultRubric).

Parse the arguments provided in $ARGUMENTS and execute the appropriate
subcommand below.

---

## Subcommands

### `run [--rubric <path>] [--iterations <n>] [--score <threshold>] <task>`

Dispatch a task through the full Tribunal pipeline:

1. Spawn `tribunal-actor` with the task description. If a prior failed gate
   exists in this session, include the Meta-Judge's `refinedFeedback` as
   additional context.

2. After the Actor completes, invoke `tribunal-judge` with:
   - The Actor's output
   - The rubric (from `--rubric` flag, or `defaultRubric` from config)
   - The task description for reference

3. After the Judge returns a verdict, invoke `tribunal-meta-judge` with:
   - The Judge's full verdict JSON
   - The rubric
   - The Actor's output

4. Evaluate the gate:
   - If `metaVerdict.adjustedScore >= passingScore` AND
     `metaVerdict.approved == true`: gate passes → return the Actor's output
     as the final result with a summary of the score and iteration count.
   - If the gate fails AND iterations < maxIterations: start the next
     iteration with the `refinedFeedback` injected into the Actor prompt.
   - If the gate fails AND iterations == maxIterations: return the best
     output found so far with a warning that the maximum iterations were
     reached and the final score.

**Flags:**
- `--rubric <path>`: path to rubric file, relative to plugin root
- `--iterations <n>`: override maxIterations for this run
- `--score <threshold>`: override passingScore for this run (0.0–1.0)

---

### `status`

Display current Tribunal configuration and session state:
- Current config values (passingScore, maxIterations, panel size, defaultRubric)
- Whether auto-hook is active for this session
- Last verdict summary if one exists (score, pass/fail, iteration count)

Read config from `${CLAUDE_PLUGIN_ROOT}/config.json`.

---

### `pause`

Disable Tribunal's auto-hook for the current session. Tribunal will no longer
automatically evaluate file writes and edits. Manual `/tribunal run` still works.

Acknowledge with: "Tribunal auto-hook paused for this session."

---

### `resume`

Re-enable Tribunal's auto-hook for the current session.

Acknowledge with: "Tribunal auto-hook resumed."

---

### `verdict`

Show the full structured verdict from the most recent Tribunal evaluation in
this session, including:
- Final score and pass/fail
- Judge strengths and weaknesses
- Any bias flags raised by the Meta-Judge
- The refined feedback used (or that would be used) for the next iteration

If no verdict exists yet this session, say so.

---

### `config`

Open `${CLAUDE_PLUGIN_ROOT}/config.json` for editing and show current values.

---

If no subcommand is recognized or $ARGUMENTS is empty, show a brief usage
summary listing the available subcommands.
