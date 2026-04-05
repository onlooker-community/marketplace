# 0008 — Optional Onlooker integration for verdict telemetry

Date: 2026-04-02
Status: Proposed

## Context and Problem Statement

Tribunal's quality gate produces rich structured data on every run: scores per
judge persona, bias flags, iteration counts, rubric applied, pass/fail outcome,
and the Meta-Judge's reasoning. In standalone mode this data surfaces in the
terminal and informs the next Actor iteration, but it is never persisted or
aggregated. Each run is ephemeral.

This means Tribunal cannot answer questions that only emerge from aggregated
data over time:

- Which files or task types consistently fail quality gates?
- Are scores improving week-over-week as rubrics and agent prompts are refined?
- Which judge personas are flagging bias most frequently — and against which rubrics?
- Is the judge panel discovering new issue categories (score–coverage dissociation)
  or has discovery saturated?
- Which rubric criteria are the most common failure points?

These are observability questions, not gate questions. Answering them requires
a persistence layer and a dashboard — neither of which belongs inside a Claude
Code plugin.

Onlooker (onlooker.dev) is a local-first agent observability tool that ingests
structured events from agent invocations, stores them in PostgreSQL, and serves
them to a Grafana dashboard. Its event schema already captures tokens, latency,
cost, and status per agent call. Tribunal's verdict data maps naturally onto
this schema with a custom `tribunal_verdict` event type.

The question is how to integrate the two systems without making Onlooker a hard
dependency — Tribunal must remain fully functional without it.

## Decision Drivers

* Tribunal verdict data is more semantically rich than generic agent traces:
  it includes per-persona scores, bias flags, rubric identity, and iteration
  counts that Onlooker's generic schema cannot represent without extension.
* Onlooker is local-first and optional by design — its architecture explicitly
  supports being absent without breaking the instrumented system.
* The integration should be zero-friction when Onlooker is not installed:
  no errors, no degraded performance, no configuration required.
* When Onlooker is present, the integration should require minimal configuration:
  one endpoint URL and a workspace ID in `config.json`.
* The verdict event schema must be stable enough to build Grafana panels against
  — adding fields is fine, removing or renaming fields is a breaking change.
* Tribunal should emit events whether or not anything is listening. The emitter
  is Tribunal's responsibility; the consumer is Onlooker's.

## Considered Options

* **Option A: No integration — Tribunal stays ephemeral**
  - Verdict data surfaces in the terminal only.
  - No persistence, no trends, no dashboard.
  - Simplest implementation, zero external dependencies.
  - Cannot answer any observability questions.

* **Option B: Tribunal writes verdict logs to a local file**
  - Append structured JSON to `~/.claude/tribunal/verdicts.jsonl`.
  - No external dependency, fully local.
  - Requires users to build their own tooling to query or visualize.
  - Solves persistence but not observability.

* **Option C: Hard Onlooker integration**
  - Tribunal requires Onlooker to be running to emit verdicts.
  - Fails or degrades if Onlooker is not present.
  - Creates a hard dependency that conflicts with standalone value proposition.

* **Option D: Optional Onlooker integration with graceful fallback**
  - Tribunal emits verdict events to an Onlooker endpoint if configured.
  - If endpoint is absent or unreachable, Tribunal continues silently.
  - Configuration is opt-in via `config.json`.
  - Onlooker receives a custom `tribunal_verdict` event type it can store
    and route to Grafana.

## Decision Outcome

Chosen: **Option D** — optional Onlooker integration with graceful fallback.

Tribunal emits a structured `tribunal_verdict` event at the end of each pipeline
run (after Meta-Judge evaluation). If `onlooker.enabled` is `true` in `config.json`
and the endpoint is reachable, the event is POSTed to the Onlooker ingest API.
If the endpoint is absent, unreachable, or returns an error, Tribunal logs a
debug message and continues. The gate decision is never blocked by telemetry
emission.

### Verdict event schema

```json
{
  "event_type": "tribunal_verdict",
  "timestamp": "2026-04-02T14:32:15Z",
  "workspace_id": "tribunal",
  "session_id": "abc123",
  "task_summary": "Write a function that validates email addresses",
  "rubric": "rubrics/code.md",
  "iterations": 2,
  "final_score": 0.85,
  "pass": true,
  "threshold": 0.80,
  "judge_verdicts": [
    {
      "judge": "tribunal:tribunal-judge",
      "persona": "default",
      "score": 0.87,
      "pass": true,
      "bias_flags": ["weak_reasoning"]
    }
  ],
  "meta_verdict": {
    "approved": true,
    "adjusted_score": 0.85,
    "bias_flags": ["weak_reasoning"],
    "override": false
  },
  "file_paths": ["/project/src/validator.py"],
  "latency_ms": 12400,
  "actor_model": "claude-sonnet-4-6",
  "judge_model": "claude-sonnet-4-6"
}
```

The `judge_verdicts` array will contain one entry per panel member once
ADR-0005 (multi-persona panel) is implemented. In the interim it contains
a single entry for the default judge.

### config.json integration

```json
{
  "passingScore": 0.80,
  "maxIterations": 3,
  "onlooker": {
    "enabled": false,
    "endpoint": "http://localhost:3000/ingest",
    "workspaceId": "tribunal",
    "emitOnPass": true,
    "emitOnFail": true
  }
}
```

`enabled: false` is the default. Users opt in by setting `enabled: true` and
providing their Onlooker endpoint. `emitOnPass` and `emitOnFail` allow selective
emission — e.g., only emit on failures to reduce noise.

### Grafana dashboard panels

The `tribunal_verdict` event type enables the following panels:

**Quality trend panels**
- Pass rate over time (7-day rolling average)
- Average score by rubric over time
- Iteration count distribution (how often does it take 1 vs 2 vs 3 iterations?)
- Score improvement from iteration 1 to final (Actor learning signal)

**Coverage panels (informed by Jung & Na, 2026 score–coverage dissociation)**
- Unique bias flag categories discovered per week (are new issues being found?)
- Bias flag frequency by judge persona (which persona flags most?)
- Rubric criterion failure heatmap (which criteria fail most often?)

**Adversarial pattern panels**
- Files or task types that consistently fail the security judge persona
- Tasks that pass the default judge but fail after Meta-Judge adjustment
  (indicates systematic Judge weakness in a category)
- Iteration 1 score vs. final score correlation (measures Actor self-challenge
  effectiveness once ADR-0007 is implemented)

**Cost and efficiency panels**
- Latency per pipeline run over time
- Gate cost estimate (tokens × model cost) per run
- Pass rate vs. panel size (validates the N=4 panel decision from ADR-0005)

### Onlooker-side requirements

Onlooker must register `tribunal_verdict` as a custom event type and provide:
- A PostgreSQL table or JSONB column for the extended schema
- A Grafana data source pointed at the Onlooker PostgreSQL instance
- Dashboard provisioning file (to be maintained in the Onlooker repo, not Tribunal)

Tribunal is not responsible for Onlooker's internal schema or dashboard
definitions. The contract between the two systems is the `tribunal_verdict`
event schema defined above. Schema changes follow semantic versioning: additive
changes (new fields) are backward-compatible; field removal or rename requires
a major version bump and migration guidance.

### Consequences

* Good: Tribunal remains fully functional without Onlooker — standalone value
  proposition is preserved.
* Good: When Onlooker is present, Tribunal verdict data becomes the richest
  signal in the observability stack — more semantically meaningful than generic
  agent traces.
* Good: The score–coverage dissociation panels (from Jung & Na, 2026) make the
  judge panel investment visible — operators can see whether the 4-judge panel
  is discovering new issue categories or has saturated.
* Good: The integration is opt-in and zero-friction — one config change to
  enable, no code changes to Tribunal's core pipeline.
* Good: `emitOnFail`-only mode allows high-signal low-noise operation for teams
  that only want to track regressions.
* Bad: The `tribunal_verdict` schema must be kept stable — any breaking change
  requires coordination with Onlooker consumers. This creates a lightweight
  contract maintenance burden.
* Bad: Onlooker must implement custom event handling for `tribunal_verdict` —
  this is work on the Onlooker side that Tribunal cannot control.
* Bad: Local-only Onlooker deployment means verdict telemetry is machine-scoped.
  Shared team observability requires deploying Onlooker to a shared server,
  which is an Onlooker deployment concern, not a Tribunal one.
* Neutral: Option B (local file logging) could be implemented alongside Option D
  as a zero-dependency fallback for users who want persistence without Onlooker.
  This is deferred but not excluded.

## Links

* Onlooker README — local-first agent observability tool (onlooker.dev)
* Jung, H. & Na, W. (2026). Logarithmic Scores, Power-Law Discoveries.
  arXiv:2604.00477 — informs score–coverage dissociation dashboard panels
* He, M. et al. (2026). YC-Bench: Benchmarking AI Agents for Long-Term
  Planning and Consistent Execution. arXiv:2604.01212 — scratchpad usage
  as strongest predictor of success motivates long-horizon verdict tracking
* Relates to: [0005 — Judge persona panel](0005-judge-persona-panel.md)
  (`judge_verdicts` array in event schema is designed for multi-persona output)
* Relates to: [0007 — Skeptical Actor](0007-skeptical-actor.md)
  (iteration 1 vs. final score delta panel measures Actor self-challenge ROI)
* Relates to: [0006 — Meta-Judge override thresholds](0006-meta-judge-override-thresholds.md)
  (Meta-Judge override events are separately trackable in the dashboard)