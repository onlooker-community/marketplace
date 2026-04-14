# Echo

Prompt regression testing for Claude Code agent files. Echo is the CI layer for the Onlooker plugin ecosystem.

## What it does

When an agent prompt changes — for example, `agents/judge.md` is modified in Tribunal — Echo automatically runs a suite of representative test cases through Tribunal's evaluation pipeline and reports whether the change improved, degraded, or had no measurable effect on output quality.

Without Echo, prompt engineering is pure intuition. With Echo, every change to an agent file has a measurable before/after signal.

## How it works

1. **Test cases** describe tasks to run and rubrics to evaluate against. They live in `test-cases/` as JSON files.
2. **Baselines** record the before-state: the scores a test case produced at a known-good point. They live in `baselines/` and are committed to version control.
3. **On every run**, Echo invokes the Tribunal pipeline (Actor + Judge), compares the new scores against the baseline, and classifies each test as `improved`, `degraded`, or `neutral`.
4. **Any degraded result** is a failure. Echo exits non-zero and the `echo-reporter` agent generates a report explaining what regressed.

## Relationship to Tribunal

Echo depends on Tribunal as its evaluation engine. Echo spawns Tribunal's subagents (`tribunal:tribunal-actor`, `tribunal:tribunal-judge`, `tribunal:tribunal-meta-judge`) to run evaluations. Echo is the test harness; Tribunal is the evaluator.

Echo installs without Tribunal present. Running tests without Tribunal installed produces:

```
Echo requires Tribunal. Install with: /plugin install tribunal
```

## Installation

### User scope (available in all projects)

```
/plugin install echo --scope user
```

### Project scope (available in this project only)

```
/plugin install echo --scope project
```

## Quick start

### 1. Write a test case

Create `test-cases/my-test.json`:

```json
{
  "id": "judge-handles-empty-output-001",
  "description": "Judge returns score 0.0 when Actor output is empty",
  "agent_file": "tribunal/agents/judge.md",
  "task": "Write a function that reverses a string in Python.",
  "rubric": "tribunal/rubrics/code.md",
  "passing_score": 0.80,
  "tags": ["tribunal-judge", "code"],
  "created": "2026-04-04"
}
```

### 2. Record a baseline

```
/echo:regression record --test judge-handles-empty-output-001
```

This runs the Tribunal pipeline and saves the result to `baselines/judge-handles-empty-output-001.json`. Commit the baseline file.

### 3. Make a prompt change

Edit `tribunal/agents/judge.md`. Save the file.

Echo automatically triggers on the ConfigChange event and runs any test cases tagged to that agent file.

### 4. Review the report

Echo prints a regression report:

```markdown
## Echo Regression Report

**1 degraded, 0 improved, 0 neutral**

### Degraded

- **judge-handles-empty-output-001** — Judge returns score 0.0 when Actor output is empty
  - Before: 0.87 | After: 0.71 | Delta: -0.16
  - Regressed criteria: error_handling, adherence

### Recommendation

Review degraded tests before merging
```

### 5. Run manually

```
/echo:regression run --agent tribunal/agents/judge.md
/echo:regression run --all
/echo:regression run --test judge-handles-empty-output-001
```

## Commands

| Command | Description |
|---------|-------------|
| `/echo:regression run` | Run the test suite |
| `/echo:regression record` | Record baselines |
| `/echo:regression status` | Show test case and baseline status |
| `/echo:regression add` | Scaffold a new test case |
| `/echo:regression list` | List test cases |
| `/echo:regression report` | Generate a report from a run log |
| `/echo:regression diff` | Show score diff for a test case |

See `/echo:regression --help` or `commands/regression.md` for full flag documentation.

## Configuration

Edit `config.json` to adjust thresholds:

```json
{
  "regression_threshold": 0.05,
  "improvement_threshold": 0.05,
  "per_criterion_regression_threshold": 0.10,
  "run_on_config_change": true
}
```

Set `run_on_config_change: false` to disable automatic hook-triggered runs.

## Onlooker integration

Echo optionally emits `echo_run` events to Onlooker for run history tracking and dashboards. Disabled by default. Enable in `config.json`:

```json
{
  "onlooker": {
    "enabled": true,
    "endpoint": "http://localhost:3000/ingest",
    "workspaceId": "echo"
  }
}
```

## Architecture

See `docs/adr/` for the key design decisions:

- [ADR 0001](docs/adr/0001-tribunal-as-evaluator.md) — Why Echo uses Tribunal subagents rather than its own evaluation
- [ADR 0002](docs/adr/0002-score-delta-not-string-compare.md) — Why score deltas are used instead of string comparison
- [ADR 0003](docs/adr/0003-baseline-as-committed-artifact.md) — Why baselines are committed to version control
