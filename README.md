# Onlooker Marketplace

## Installation

Add this marketplace to Claude Code:

```
# From GitHub
/plugin marketplace add onlooker-community/onlooker-marketplace

# From local checkout
/plugin marketplace add /path/to/onlooker-marketplace
```

## Available Plugins

### archivist

[Plugin README](plugins/archivist/README.md)

**Category:** Context Preservation

Structured session memory across context truncation. Extracts decisions, dead ends, and open questions before context is compacted, then reinjects the most important items when a new session starts.

**Contains:**

- **Agents:**
  - `archivist-extractor` - Reads a session transcript and extracts structured memory (decisions, dead ends, open questions, files) as JSON for persistence across context truncation.
  - `archivist-injector` - Loads the most recent session extract for the current working directory and returns a concise prose summary for injection into the new session context.
- **Commands:**
  - `/archivist:memory` - View, manage, and inspect Archivist session memory extracts.
- **Hooks:**
  - PreCompact hooks configured (Extract structured session memory from current session)
  - SessionEnd hooks configured (Finalize extraction)
  - SessionStart hooks configured (Load session context on startup)

**Installation:**

```bash
/plugin install archivist@onlooker-marketplace
```

### cues

[🧭 Plugin README](plugins/cues/README.md)

**Category:** Utility

Contextual guidance injected automatically based on triggers. Cues match prompts, commands, and file paths using regex, vocabulary, or semantic similarity.

**Contains:**

- **Commands:**
  - `/create-cue` - Create a new cue with triggers and guidance content
  - `/list-cues` - List all available cues with their triggers and activity
  - `/edit-cue` - Edit an existing cue's triggers or content
- **Hooks:**
  - SessionStart: Clears markers, injects cue context, escalates friction
  - UserPromptSubmit: Matches prompts to cues, classifies ideas
  - PreToolUse (Task): Stashes task context
  - PreToolUse (Bash): Matches commands to cues
  - PreToolUse (Write|Edit): Matches file paths to cues
  - PostToolUse: Tracks followups, detects failure patterns

**Installation:**

```bash
/plugin install cues@onlooker-marketplace
```


### echo

[Plugin README](plugins/echo/README.md)

**Category:** Regression Testing

Prompt regression testing — measurable before/after signals for agent file changes. Runs test cases through Tribunal, compares scores against committed baselines, and reports improved, degraded, or neutral.

**Contains:**

- **Agents:**
  - `echo-reporter` - Produces a human-readable regression report summarizing improved, degraded, and neutral outcomes with a before/after score breakdown and merge recommendation.
- **Commands:**
  - `/echo:echo` - Run test suites, record baselines, and detect regressions before merging prompt changes.
- **Hooks:**
  - ConfigChange hooks configured (Triggers regression test suite when agent files change)

**Installation:**

```bash
/plugin install echo@onlooker-marketplace
```

### onlooker

[Plugin README](plugins/onlooker/README.md)

**Category:** Foundational

Local observability for agentic workflows — telemetry, friction analysis, cost tracking, and weekly insights. The observability spine for your agents.

**Contains:**

- **Skills:**
  - `analyze-metrics` - Analyze Onlooker metrics to identify patterns, improvements, and anomalies in agent behavior (~47 lines)
  - `auto-observe` - Automatically configure Onlooker hooks for an agent (~32 lines)
  - `optimize-telemetry` - Optimize what metrics Onlooker tracks based on usage patterns (~35 lines)
  - `setup-hooks` - Help set up custom Onlooker hooks for specific use cases (~35 lines)
- **Agents:**
  - `metrics-analyzer` - Specialized agent for analyzing Onlooker metrics and identifying patterns
  - `hook-setup-agent` - Specialized agent for configuring Onlooker hooks
- **Commands:**
  - `/onlooker:observe` - Set up Onlooker observation for an agent.
  - `/onlooker:analyze` - Analyze your agent metrics.
- **Hooks:**
  - PostToolUse hooks configured (Track skill usage and file reads)
  - SessionStart hooks configured (Session start tracking)
  - Stop hooks configured (Cost tracking)

**Installation:**

```bash
/plugin install onlooker@onlooker-marketplace
```

### scribe

[Plugin README](plugins/scribe/README.md)

**Category:** Intent Capture

Intent documentation from agent activity — captures _why_ changes were made, not what the code does. Two-phase architecture: lightweight capture during execution, then distill into readable docs when the session ends.

**Contains:**

- **Agents:**
  - `scribe-capture` - Extracts intent from a single file operation while the agent still has context. Lightweight capture after every Write/Edit.
  - `scribe-distiller` - Synthesises a session's capture entries (plus optional Archivist context) into readable documentation artifacts.
- **Commands:**
  - `/scribe:scribe` - Manage Scribe intent documentation — view captures, distill sessions, browse artifacts.
- **Hooks:**
  - PostToolUse hooks configured (Capture intent on Write/Edit operations)
  - Stop hooks configured (Distill session on stop)
  - SessionEnd hooks configured (Distill session on end)

**Installation:**

```bash
/plugin install scribe@onlooker-marketplace
```

### oracle

[Plugin README](plugins/oracle/README.md)

**Category:** Confidence Calibration

Confidence calibration before action — catches misaligned work before it becomes expensive to reverse. Detects when the agent is about to proceed on uncertain ground and intervenes before costly work toward the wrong goal.

**Contains:**

- **Commands:**
  - `/oracle:calibrate` - Manage Oracle confidence calibration — view config, audit log, and calibration state.
- **Hooks:**
  - UserPromptSubmit hooks configured (Assess task clarity and interpretation divergence)
  - PreToolUse hooks configured (Calibrate confidence on Write and Bash operations)

**Installation:**

```bash
/plugin install oracle@onlooker-marketplace
```

### sentinel

[Plugin README](plugins/sentinel/README.md)

**Category:** Pre-Flight Gate

Pre-flight safety gate for destructive Bash operations. Pattern-matched risk evaluation before execution — blocks dangerous commands, prompts for review on risky ones, and logs everything for audit. Zero latency on safe commands.

**Contains:**

- **Commands:**
  - `/sentinel:sentinel` - Manage Sentinel pre-flight safety gate — view config, audit log, and pattern overrides.
- **Hooks:**
  - PreToolUse hooks configured (Evaluate destructive Bash operations with pattern matching)

**Installation:**

```bash
/plugin install sentinel@onlooker-marketplace
```

### tribunal

[Plugin README](plugins/tribunal/README.md)

**Category:** LLM Judges

Post-run evaluation and quality scoring for LLM outputs. Orchestrate agents, verify outputs with LLM judges, and enforce automatic quality gates.

**Contains:**

- **Agents:**
  - `tribunal-actor` - Executes a development task with structured self-challenge (skepticism phase) before submission.
  - `tribunal-judge` - Evaluates Actor output against a provided rubric. Returns structured JSON verdict with score, pass/fail, and feedback.
  - `tribunal-meta-judge` - Reviews a Judge verdict for evaluation quality and bias before the quality gate decision is finalized.
  - `tribunal-judge-security` - Evaluates output through a security lens, hunting for vulnerabilities and defensive gaps.
  - `tribunal-judge-maintainability` - Evaluates output for long-term code health, readability, and changeability.
  - `tribunal-judge-adversarial` - Plays devil's advocate, stress-testing assumptions and exploring edge cases.
  - `tribunal-judge-domain` - Evaluates output for domain correctness, business logic accuracy, and semantic alignment.
- **Commands:**
  - `/tribunal:run` - Tribunal quality pipeline. Dispatches a task through Actor → Judge Panel → Meta-Judge with configurable quality gates.
- **Hooks:**
  - PostToolUse hooks configured (Evaluate file quality on Write/Edit operations)
  - SubagentStop hooks configured (Review judge verdicts on actor completion)

**Installation:**

```bash
/plugin install tribunal@onlooker-marketplace
```

### warden

[Plugin README](plugins/warden/README.md)

**Category:** Security

Indirect prompt injection detection — scans content retrieved by WebFetch and Read for injection patterns and gates agent actions (Write, Edit, Bash) when threats are detected. Grounded in Meta's Agents Rule of Two.

**Contains:**

- **Commands:**
  - `/warden:gate` - Manage Warden content gate — view status, audit log, injection patterns, and clear blocked state.
- **Hooks:**
  - PostToolUse hooks configured (Scan WebFetch and Read content for injection patterns)
  - PreToolUse hooks configured (Gate Write, Edit, and Bash operations when injection detected)

**Installation:**

```bash
/plugin install warden@onlooker-marketplace
```

### counsel

[Plugin README](plugins/counsel/README.md)

**Category:** Synthesis

Weekly synthesis and recommendations — reads from Onlooker events, Tribunal verdicts, Echo regressions, Sentinel/Warden audit logs, and Oracle calibration to produce layer-attributed improvement briefs with concrete actions.

**Contains:**

- **Agents:**
  - `counsel-synthesizer` - Analyzes gathered plugin data and produces a layer-attributed improvement brief.
- **Commands:**
  - `/counsel:brief` - Generate or view a Counsel improvement brief — weekly synthesis of friction, regressions, and recommendations.
- **Hooks:**
  - SessionStart hooks configured (Check if a weekly brief is due)

**Installation:**

```bash
/plugin install counsel@onlooker-marketplace
```

## Tools

### @onlooker-community/dashboard

[Tool README](tools/dashboard/README.md)

CLI tool to spin up a pre-configured Grafana dashboard for Onlooker telemetry data. Starts a Bun API server and a Grafana container with pre-provisioned dashboards for cost tracking, session activity, hook health, and tool usage.

```bash
bunx @onlooker-community/dashboard up
```

## Development

This is a monorepo containing multiple plugins and tools. Plugins are in `plugins/`, standalone tools are in `tools/`.

Contributor-focused documentation (repository layout, workflows, plugin index) lives in the [`docs/`](./docs/) directory as a [MkDocs](https://www.mkdocs.org/) project. See [`docs/README.md`](./docs/README.md) for how to build and serve it locally.

### Quick Start

Clone this repository and run the following commands to get started:

```
# Install dependencies, run prepare scripts
bun install
```

## License

Copyright © 2026 [Onlooker Community](https://github.com/onlooker-community) under the [Blue Oak Model License 1.0.0](./LICENSE)
