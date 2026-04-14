# /echo:regression

Prompt regression testing for Claude Code agent files. Run test suites, record baselines, and detect regressions before merging prompt changes.

## Usage

```
/echo:regression <subcommand> [flags]
```

## Subcommands

### run

Run the test suite for one or more test cases.

```
/echo:regression run [--agent <agent-file>] [--tag <tag>] [--test <test-id>] [--all]
```

Flags:
- `--agent <path>` — Run only test cases tagged to this agent file (e.g., `tribunal/agents/judge.md`)
- `--tag <tag>` — Run only test cases with this tag (e.g., `bias-detection`)
- `--test <id>` — Run a single test case by ID
- `--all` — Run all test cases in `test-cases/`

Behavior:
- Test cases without a recorded baseline are skipped with a warning: "No baseline for <id> — run `echo:regression record --test <id>` first"
- Each result is classified as `improved`, `degraded`, or `neutral`
- Any `degraded` result causes the suite to exit with a non-zero status code
- Generates a report via the `echo-reporter` agent on completion

### record

Record a baseline for one or more test cases.

```
/echo:regression record [--test <test-id>] [--agent <agent-file>] [--all] [--force]
```

Flags:
- `--test <id>` — Record baseline for a single test case
- `--agent <path>` — Record baselines for all test cases tagged to this agent file
- `--all` — Record baselines for all test cases
- `--force` — Overwrite existing baselines (required if baseline already exists)

Behavior:
- Runs the Tribunal pipeline for the test case and records the result as the new baseline
- Hashes the current agent file and stores it in the baseline for drift detection
- Writes baseline JSON to `baselines/<test-id>.json`
- Without `--force`, exits with an error if a baseline already exists: "Baseline already exists for <id>. Use --force to overwrite."

### status

Show the current status of all test cases and their baselines.

```
/echo:regression status [--agent <agent-file>]
```

Flags:
- `--agent <path>` — Filter to test cases for a specific agent file

Output columns:
- Test ID
- Description
- Agent file
- Baseline recorded (yes/no)
- Baseline date
- Agent file hash match (yes/no/missing)
- Last run outcome (improved/degraded/neutral/never run)

### add

Scaffold a new test case file.

```
/echo:regression add --id <test-id> --agent <agent-file> --rubric <rubric-path> [--description <text>] [--tag <tag>...]
```

Flags:
- `--id <id>` — Test case ID (required, must be unique, use kebab-case)
- `--agent <path>` — Agent file this test case targets (required)
- `--rubric <path>` — Rubric file to evaluate against (required)
- `--description <text>` — Human-readable description of what this test verifies
- `--tag <tag>` — Tag(s) for filtering (repeatable)

Creates `test-cases/<test-id>.json` with a template populated from the flags. The `task` field is left as a placeholder to be filled in manually.

### list

List all test cases, optionally filtered.

```
/echo:regression list [--agent <agent-file>] [--tag <tag>] [--no-baseline]
```

Flags:
- `--agent <path>` — Filter by agent file
- `--tag <tag>` — Filter by tag
- `--no-baseline` — Show only test cases without a recorded baseline

Output: table of test case IDs, descriptions, agent files, and tags.

### report

Generate a regression report from the most recent run log, or a specific run.

```
/echo:regression report [--run <timestamp>] [--format markdown|json]
```

Flags:
- `--run <timestamp>` — Report on a specific run log from `~/.claude/echo/runs/` (defaults to most recent)
- `--format <format>` — Output format: `markdown` (default) or `json`

Invokes the `echo-reporter` agent to produce the report.

### diff

Show a diff of rubric scores between two baselines, or between a baseline and the last run result.

```
/echo:regression diff --test <test-id> [--run <timestamp>]
```

Flags:
- `--test <id>` — Test case to diff (required)
- `--run <timestamp>` — Compare baseline against a specific run (defaults to most recent run for this test)

Output: per-criterion score table with before/after columns and delta.

## Requirements

Echo requires Tribunal to run evaluations. If Tribunal is not installed, all run and record commands exit with:

```
Echo requires Tribunal. Install with: /plugin install tribunal
```

## Configuration

Edit `config.json` in the Echo plugin root to adjust:
- `regression_threshold` — minimum score drop to classify as degraded (default: 0.05)
- `improvement_threshold` — minimum score gain to classify as improved (default: 0.05)
- `per_criterion_regression_threshold` — per-rubric-criterion regression threshold (default: 0.10)
- `run_on_config_change` — enable/disable automatic runs on agent file changes (default: true)

## Baselines in version control

Baselines in `baselines/` are committed to the repository. When reviewing a PR that modifies an agent file, the diff will show before/after baseline scores. This makes prompt regressions visible in code review without running the test suite.
