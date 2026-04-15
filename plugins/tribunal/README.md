# Tribunal

**A Claude Code plugin for multi-agent execution with LLM-as-a-Judge quality gates**

Version 0.1.0 · [github.com/onlooker-community/marketplace](https://github.com/onlooker-community/marketplace)

## Table of Contents

1. [Overview](#overview)
2. [Core Concepts](#core-concepts)
3. [Architecture](#architecture)
4. [Installation](#install-the-plugin)
5. [Directory Structure](#directory-structure)
6. [Configuration](#configuration)
7. [Usage](#usage)
8. [Agent Reference](#agent-reference)
9. [Hooks Reference](#hooks-reference)
10. [Research Foundation](#research-foundation)

## Overview

Tribunal is a Claude Code plugin that wraps your development workflow in a three-tier evaluation loop: an **Actor** agent does the work, a **Judge** agent evaluates the output, and a **Meta-Judge** agent reviews the evaluation itself before results are accepted.

It installs into your `.claude/` directory — either project-level or globally in `~/.claude/` — and integrates with Claude Code as a combination of subagents, hooks, and slash commands.

**What Tribunal gives you**:

- Fresh sub-agents spawned per task, eliminating context contamination between iterations
- Parallel actor execution for candidate generation
- Automated quality gates with structured pass/fail verdicts
- A meta-evaluation layer that prevents judgment saturation over iterations
- `/tribunal:run` slash command for manual override and configuration

Tribunal is grounded in two research frameworks: **LLM-as-a-Judge** (Zheng et al., NeurIPS 2023) and **LLM-as-a-Meta-Judge** (Wu et al., 2024). See [Research Foundation](#research-foundation).

## Core Concepts

### The Three Roles

**Actor** Executes the task. Actors are stateless sub-agents spawned fresh for each task or retry. A task can dispatch multiple Actors in parallel to generate candidate outputs.

**Judge** Evaluates Actor output against a rubric. Returns a structured verdict: a score, pass/fail signal, and specific actionable feedback. Multiple Judge agents can form a panel, with verdicts aggregated before the gate decision.

**Meta-Judge** Evaluates the Judge's verdict. Checks whether the evaluation is well-reasoned and free from known LLM judge biases (positional bias, verbosity bias, self-enhancement bias). The Meta-Judge can override or refine the Judge's feedback before it is returned to a new Actor iteration.

### Quality Gates

A quality gate sits between each Actor iteration and the next. The gate passes only when:

1. The aggregated Judge panel score meets the configured `passingScore` threshold, AND
2. The Meta-Judge approves the evaluation quality

If the gate fails, the Meta-Judge's refined feedback is passed to a new Actor agent. This continues up to `maxIterations`.

### Scope: Project vs Global

Like all Claude Code extensions, Tribunal can be installed at two scopes:

| Scope | Location | When to use |
| --- | --- | --- |
| Project | `.claude/tribunal/` | Per-project rubrics, task-specific panels |
| Global | `~/.claude/tribunal/` | Personal defaults across all projects |

Project-level config takes precedence over global config when both exist.

## Architecture

```txt
┌──────────────────────────────────────────────────────────┐
│                    Tribunal Plugin                       │
│                                                          │
│  .claude/tribunal/                                       │
│  ├── manifest.json          Plugin manifest              │
│  ├── agents/                                             │
│  │   ├── actor.md           Actor sub-agent              │
│  │   ├── judge.md           Judge sub-agent              │
│  │   └── meta-judge.md      Meta-Judge sub-agent         │
│  ├── commands/                                           │
│  │   └── tribunal.md        /tribunal slash command      │
│  ├── hooks/                                              │
│  │   └── hooks.json         PostToolUse auto-hook        │
│  └── config.json            Panel and gate defaults      │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### Execution Flow

```txt
Task Input
    │
    ▼
┌───────────────────────────┐
│   Actor(s)  [parallel]    │  ← Fresh sub-agent(s) per iteration
│   actor.md                │
└──────────────┬────────────┘
               │  candidate output(s)
               ▼
┌───────────────────────────┐
│   Judge Panel  [parallel] │  ← 1–N judge agents
│   judge.md × N            │
└──────────────┬────────────┘
               │  aggregated verdict
               ▼
┌───────────────────────────┐
│   Meta-Judge              │  ← Reviews the verdict itself
│   meta-judge.md           │
└──────────────┬────────────┘
               │
       ┌───────┴────────┐
       │                │
     PASS             FAIL
       │                │
       ▼                └──→ new Actor iteration (up to maxIterations)
   Final Output
```

## Installation

### Install the Plugin

**Project-level** (recommended for team projects):
`/plugin install tribunal`

**Global** (available across all your projects):

```text
/plugin install --global tribunal
```

### Verify Installation

After installing, confirm Tribunal's agents and commands are available:

```text
/tribunal:run status
```

You should see the Actor, Judge, and Meta-Judge agents listed as active, along with your current config.

## Directory Structure

After installation, your `.claude/tribunal/` directory looks like this:

```txt
.claude/
└── tribunal/
    ├── manifest.json          ← Plugin manifest (name, version, component paths)
    ├── config.json            ← Your panel and gate configuration
    ├── agents/
    │   ├── actor.md           ← Actor sub-agent definition
    │   ├── judge.md           ← Judge sub-agent definition
    │   └── meta-judge.md      ← Meta-Judge sub-agent definition
    ├── commands/
    │   └── tribunal.md        ← /tribunal slash command
    ├── hooks/
    │   └── hooks.json         ← Auto-hook configuration
    └── rubrics/               ← Optional: per-task rubric templates
        ├── code.md
        ├── writing.md
        └── sql.md
```

**Key files:**

`manifest.json` - Declares the plugin to Claude Code. Sets component paths and plugin metadata.

`config.json` - Your primary configuration file. Controls panel size, passing score, iteration limits, and aggregation strategy. See [Configuration](#configuration).

`agents/*.md` - Markdown files that define each sub-agent's role, system prompt, and behavior. You can edit these to customize how each tier evaluates tasks.

`rubrics/` - Optional folder for reusable rubric templates. Reference them in `config.json` by filename.

## Configuration

### `config.json`

The main configuration file. Create or edit `.claude/tribunal/config.json`:

```json
{
  "passingScore": 0.80,
  "maxIterations": 3,
  "actor": {
    "count": 1
  },
  "panel": {
    "size": 1,
    "aggregation": "mean"
  },
  "defaultRubric": "rubrics/code.md"
}
```

**Fields:**

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `passingScore` | number | `0.75` | Score threshold (0–1) required to pass the quality gate |
| `maxIterations` | number | `3` | Maximum Actor retry cycles before Tribunal returns the best result found |
| `actor.count` | number | `1` | Number of parallel Actor agents to spawn per iteration |
| `panel.size` | number | `1` | Number of parallel Judge agents per evaluation cycle |
| `panel.aggregation` | string | `'mean'` | How to combine panel scores: `'mean'`, `'majority'`, or `'weighted'` |
| `defaultRubric` | string | null | Path (relative to `tribunal/`) to the default rubric file |

### Rubric Files

Rubrics live in `.claude/tribunal/rubrics/` as Markdown files. They define the evaluation criteria passed to Judge agents.

Example -- `rubrics/code.md`:

_Evaluate the submitted code on the following criteria:_

1. **Correctness** - Does it handle all cases described in the task?
2. **Error handling** - Are errors caught and surfaced descriptively?
3. **Code quality** - Is it readable, typed, and free of unnecessary complexity?
4. **Edge cases** - Are empty inputs, boundary values, and failure modes handled?

Return a score from 0.0 to 1.0 and specific, actionable feedback the developer can act on immediately.

### Per-Task Rubric Override

You can override the default rubric for a specific invocation using the `/tribunal:run` command:

```text
/tribunal:run --rubric rubrics/sql.md Write a migration to add soft-delete to users
```

## Usage

### Auto-Hook Mode

By default, Tribunal hooks into Claude Code's `PostToolUse` event on `Write` and `Edit` tool calls. Every time Claude writes or edits a file, Tribunal's Judge and Meta-Judge automatically evaluate the output against your `defaultRubric`.

If the gate fails, Tribunal surfaces the Meta-Judge's refined feedback directly in your session and Claude will retry with a new Actor iteration.

To **disable auto-hook** for a session:

```text
/tribunal:run pause
```

To **re-enable**:

```text
/tribunal:run resume
```

### Slash Command Mode

Use `/tribunal:run` to manually dispatch a task through the full pipeline:

```text
/tribunal:run Write a Python function that validates email addresses
```

With options:

```text
/tribunal:run --rubric rubrics/writing.md --iterations 4 --score 0.9 Draft the onboarding email copy
```

**`/tribunal:run` subcommands:**

| Command | Description |
| --- | --- |
| `/tribunal:run [task]` | Dispatch a task through the full Actor → Judge → Meta-Judge pipeline |
| `/tribunal:run --rubric <path>` | Use a specific rubric file for this run |
| `/tribunal:run --iterations <n>` | Override `maxIterations` for this run |
| `/tribunal:run --score <n>` | Override `passingScore` for this run |
| `/tribunal:run status` | Show current config, active agents, and last verdict |
| `/tribunal:run pause` | Disable auto-hook for the current session |
| `/tribunal:run resume` | Re-enable auto-hook |
| `/tribunal:run verdict` | Show the full verdict from the most recent evaluation |
| `/tribunal:run config` | Open `config.json` for editing |

## Agent Reference

Each agent is defined as a Markdown file in `.claude/tribunal/agents/`. You can edit these files directly to customize behavior for your project.

### `agents/actor.md`

The Actor is the worker agent. It receives the task description and any context from previous failed iterations (the Meta-Judge's refined feedback).

#### Frontmatter defaults

```yaml
---
name: tribunal-actor
description: >
  Executes development tasks as part of the Tribunal quality pipeline.
  Invoked by Tribunal for each iteration of a task, incorporating feedback
  from previous failed quality gates.
model: sonnet
effort: high
maxTurns: 20
---
```

**What to customize:** The system prompt body. Add project conventions, coding standards, or domain context that every Actor should have.

### `agents/judge.md`

The Judge evaluates Actor output against the rubric. It returns a structured verdict.

#### Frontmatter defaults

```yaml
---
name: tribunal-judge
description: >
  Evaluates task output against a provided rubric as part of the Tribunal
  quality pipeline. Returns a structured verdict with score, pass/fail,
  and specific feedback.
model: sonnet
effort: medium
maxTurns: 5
---
```

#### Verdict schema (Judge agents must return this structure)

```json
{
  "score": 0.85,
  "pass": true,
  "feedback": "Specific, actionable feedback for the next iteration if needed",
  "strengths": ["What the output did well"],
  "weaknesses": ["What needs improvement"],
  "reasoning": "Full chain-of-thought for this evaluation"
}
```

**What to customize:** The system prompt body. Add domain expertise, bias reminders, or project-specific evaluation priorities.

### `agents/meta-judge.md`

The Meta-Judge reviews the Judge's verdict. It checks for evaluation quality and known LLM judge biases before the gate decision is made.

#### Frontmatter defaults

```yaml
name: tribunal-meta-judge
description: >
  Reviews Judge verdicts for quality and bias as part of the Tribunal
  quality pipeline. Can override scores and refine feedback before the
  gate decision is made.
model: sonnet
effort: medium
maxTurns: 5
---
```

#### Meta-verdict schema (Meta-Judge agents must return this structure)

```json
{
  "approved": true,
  "adjustedScore": 0.85,
  "biasFlags": [],
  "refinedFeedback": "Improved feedback to pass to the next Actor iteration",
  "metaReasoning": "Why the Judge verdict was accepted or overridden"
}
```

- **Bias flags** the Meta-Judge is prompted to detect:
  - `positional_bias` — Judge favored the first candidate in a multi-actor run
  - `verbosity_bias` — Judge scored longer outputs higher regardless of quality
  - `self_enhancement_bias` — Judge preferred outputs stylistically similar to its own tendencies

**What to customize:** The system prompt body. Add project-specific consistency requirements or additional bias checks.

## Hooks Reference

Tribunal registers hooks via `.claude/tribunal/hooks/hooks.json.` The default configuration hooks into `PostToolUse` on write operations:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "claude --agent tribunal-judge --agent tribunal-meta-judge $FILE_PATH"
          }
        ]
      }
    ]
  }
}
```

### Disabling Specific Hooks

To disable auto-evaluation on a specific file type, edit hooks.json to narrow the matcher. For example, to skip evaluation on Markdown files:

```json
"matcher": "Write(*.ts)|Write(*.py)|Edit(*.ts)|Edit(*.py)"
```

## Research Foundation

Tribunal’s evaluation layer is built on two peer-reviewed frameworks:

**LLM-as-a-Judge** — Zheng et al., NeurIPS 2023 [arxiv.org/abs/2306.05685](https://arxiv.org/abs/2306.05685)

Establishes that strong LLMs used as judges can approximate human preferences at scale, achieving over 80% agreement with human evaluators. Identifies key failure modes — positional bias, verbosity bias, and self-enhancement bias — that Tribunal’s Meta-Judge layer is designed to detect and correct at each gate.

**LLM-as-a-Meta-Judge** — Wu et al., 2024 [arxiv.org/abs/2407.19594](https://arxiv.org/abs/2407.19594)

Introduces Meta-Rewarding: a model that judges its own judgments to prevent evaluation saturation during iterative training. The Meta-Judge in Tribunal implements this pattern at inference time — improving evaluation quality across Actor iterations rather than allowing it to degrade as scores converge.
