# Plugins

The Onlooker Marketplace contains 13 plugins. Each plugin is self-contained in `plugins/<name>/` and ships with its own README, commands, hooks, and agents.

## All plugins

| Plugin | Description |
|--------|-------------|
| [archivist](#archivist) | Structured session memory across context truncation |
| [cartographer](#cartographer) | Instruction health audits for CLAUDE.md and rules files |
| [counsel](#counsel) |  Weekly synthesis and improvement briefs from your observability stack |
| [cues](#cues) | Contextual guidance injection based on trigger matching |
| [echo](#echo) | Prompt regression testing and CI for agent files |
| [ledger](#ledger) | Token and cost tracking with session budget enforcement |
| [onlooker](#onlooker) | Core observability — JSONL event emission for agent activity |
| [oracle](#oracle) | Confidence calibration before action |
| [relay](#relay) | Session continuity — captures task state and reinjects it on resume |
| [scribe](#scribe) | Intent documentation captured from agent activity |
| [sentinel](#sentinel) | Pre-flight safety gate for destructive Bash operations |
| [tribunal](#tribunal) | Multi-agent execution with LLM-as-Judge quality gates |
| [warden](#warden) | Prompt injection detection on fetched and read content |

---

## archivist

**`plugins/archivist/`**

Structured session memory across context truncation. Before context is compacted, an extractor agent reads the session and produces a structured extract — decisions (reusable rules), files touched, dead ends (failed approaches), and open questions. On session start, the most recent extract is injected as a concise summary (max 400 words).

**Lifecycle hooks:** `PreCompact`, `SessionEnd`, `SessionStart`

**Commands:** `/archivist:memory show|forget|status`

**Full docs:** [`plugins/archivist/README.md`](../../plugins/archivist/README.md)

---

## cartographer

**`plugins/cartographer/`**

Periodic audit of `CLAUDE.md` and `.claude/rules/` files. The only proactive plugin in the ecosystem — it surfaces problems in your instruction layer before they cause agent misbehavior. Detects contradictions, stale file references, orphaned plugin commands, dead tools, duplicate rules, and hierarchy conflicts between project and user-level instructions.

**Lifecycle hooks:** `InstructionsLoaded`, `ConfigChange`, `SessionEnd`

**Commands:** `/cartographer:audit view|run|history|issues|config`

**Full docs:** See `plugins/cartographer/` — no top-level README yet; refer to [`plugins/cartographer/.claude-plugin/plugin.json`](../../plugins/cartographer/.claude-plugin/plugin.json) and ADRs in `plugins/cartographer/docs/adr/`.

---

## counsel

**`plugins/counsel/`**

Weekly synthesis agent. Reads from Onlooker events, Tribunal verdicts, Echo regressions, Sentinel audit logs, Warden gate events, Oracle calibration decisions, and Archivist session extracts. Produces a structured improvement brief with layer-attributed friction findings and one concrete recommendation per layer. Turns your observability stack from a dashboard into a coach.

**Lifecycle hooks:** Runs on-demand and on a weekly schedule

**Commands:** `/counsel:brief generate|latest|history|sources`

**Full docs:** See `plugins/counsel/README.md`

---

## cues

**`plugins/cues/`**

Contextual guidance injection. Cues are declarative Markdown files with trigger conditions (regex patterns on prompts, commands, or file paths). When a trigger matches, the cue's guidance is injected into context. Cues can be scoped to the main agent, subagents, or both. Supports macro execution and semantic matching via vocabulary keywords.

**Lifecycle hooks:** `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`

**Commands:** `/create-cue`, `/list-cues`, `/edit-cue`

**Full docs:** See `plugins/cues/README.md`

---

## echo

**`plugins/echo/`**

Prompt regression testing. When an agent prompt changes (e.g., `agents/judge.md` in Tribunal is modified), Echo runs a suite of test cases through the Tribunal evaluation pipeline and reports whether the change improved, degraded, or had no measurable effect on output quality. Any degraded result exits non-zero and generates a regression report.

**Lifecycle hooks:** Runs as a CI step, not via lifecycle hooks

**Commands:** `/echo:regression run|record|status|add|list|report|diff`

**Full docs:** See `plugins/echo/README.md`

---

## ledger

**`plugins/ledger/`**

Resource governance and budget enforcement. Tracks token consumption and estimated cost across all plugin activity — including Tribunal judge panel runs, Echo regression suites, and Archivist extraction calls. Surfaces a structured warning as budgets are approached and blocks subagent spawning when the budget is exceeded.

**Lifecycle hooks:** `Stop`, `SubagentStop`, `SubagentStart`, `SessionEnd`

**Commands:** `/ledger:budget status|report|config|set-budget|reset`

**Full docs:** See `plugins/ledger/README.md`

---

## onlooker

**`plugins/onlooker/`**

Core observability for the ecosystem. Emits JSONL events for every significant agent action to `~/.claude/logs/onlooker-events.jsonl`. Tracks costs, reads, session starts, and skill usage. The data source that counsel, ledger, and the dashboard tool read from.

**Lifecycle hooks:** All major hooks (`SessionStart`, `PostToolUse`, `Stop`, etc.)

**Commands:** `/onlooker:observe`, `/onlooker:analyze`

**Full docs:** See `plugins/onlooker/` — no top-level README; refer to plugin.json and hook scripts directly.

---

## oracle

**`plugins/oracle/`**

Confidence calibration before action. Catches the failure mode that no other plugin addresses: an agent proceeding confidently on a misunderstood task. Fires on `UserPromptSubmit` to assess whether a request is clear enough to proceed, and on `PreToolUse` (Write, Bash) to check alignment confidence before high-consequence actions. Uses a convergence sampling heuristic: would re-deriving the action from scratch produce the same result?

**Lifecycle hooks:** `UserPromptSubmit`, `PreToolUse`

**Commands:** `/oracle:calibrate show|audit|stats|threshold|disable|enable`

**Relationship to Sentinel:** Sentinel blocks *dangerous* operations; Oracle catches *misaligned* operations.

**Full docs:** [`plugins/oracle/README.md`](../../plugins/oracle/README.md)

---

## relay

**`plugins/relay/`**

Session continuity bridge. At `SessionEnd`, captures the current task state — what you were doing, what's next, what's blocking, critical context. At `SessionStart`, injects this as an operational briefing. Eliminates the 5–10 turns at the start of every session re-establishing what was already known. Skips injection if the last handoff is marked complete.

**Lifecycle hooks:** `SessionEnd`, `SessionStart`

**Commands:** `/relay:handoff status|show|clear|config`

**Full docs:** See `plugins/relay/README.md`

---

## scribe

**`plugins/scribe/`**

Intent documentation from agent activity. Git logs record what changed; Scribe records *why*. After each file operation, a lightweight prompt extracts the intent behind the change while the agent still has its reasoning in context. Captures are later distilled into readable Markdown documentation artifacts — decision logs and change narratives.

**Lifecycle hooks:** `PostToolUse` (Write|Edit), `Stop`, `SessionEnd`

**Commands:** `/scribe:intent status|distill|show|open|captures|config`

**Full docs:** See `plugins/scribe/README.md`

---

## sentinel

**`plugins/sentinel/`**

Pre-flight safety gate for destructive Bash operations. Pattern-matched risk evaluation — the LLM evaluation layer only activates when a dangerous pattern matches, keeping it fast for normal operations. Three behaviors per pattern: block, review (pause for confirmation), or log. Ships with pattern libraries for filesystem, git, environment, database, and process operations.

**Lifecycle hooks:** `PreToolUse` (Bash)

**Commands:** `/sentinel:guard show|audit|patterns|review|allow|block`

**Relationship to Warden:** Sentinel blocks dangerous operations you initiate; Warden blocks malicious instructions arriving through content.

**Full docs:** See `plugins/sentinel/README.md`

---

## tribunal

**`plugins/tribunal/`**

Multi-agent execution framework with LLM-as-a-Judge quality gates. Three-tier evaluation loop: an **Actor** executes the task, a **Judge** evaluates output against a rubric, a **Meta-Judge** reviews the evaluation itself for common LLM judge biases (positional, verbosity, self-enhancement). A gate passes only when the Judge panel score meets the threshold AND the Meta-Judge approves evaluation quality.

**Architecture:** `Task → Actor(s) [parallel] → Judge Panel [parallel] → Meta-Judge → Pass/Fail`

**Commands:** `/tribunal:run [task]`, `/tribunal:run status|pause|resume|verdict|config`

**Rubrics:** Ships with `code.md`, `default.md`, `sql.md`, `writing.md`

**Full docs:** See `plugins/tribunal/README.md`

---

## warden

**`plugins/warden/`**

Prompt injection detection on retrieved content. Scans content from WebFetch and Read operations for injection patterns (instruction overrides, data exfiltration attempts, action hijacking). When a threat is detected, the content gate closes and blocks Write, Edit, and Bash operations until you explicitly clear it with `/warden:gate clear`. Gate does not auto-clear — this is a deliberate security decision.

**Lifecycle hooks:** `PostToolUse` (WebFetch|Read), `PreToolUse` (Write|Edit|Bash)

**Commands:** `/warden:gate status|audit|clear|block|patterns`

**Grounded in:** Meta's Agents Rule of Two — when untrusted content contains injection patterns, Warden removes the agent's ability to take external actions.

**Full docs:** [`plugins/warden/README.md`](../../plugins/warden/README.md)
