# Echo Test Cases

Test cases live in this directory as individual JSON files. Each file defines one regression test for a specific agent file in the Tribunal (or other) plugin ecosystem.

## File naming

Use the test case `id` as the filename: `<id>.json`.

Example: `judge-bias-detection-001.json`

## Schema

```json
{
  "id": "judge-bias-detection-001",
  "description": "Judge correctly identifies verbosity bias in a passing verdict",
  "agent_file": "tribunal/agents/judge.md",
  "task": "The full task prompt to send to the Actor",
  "rubric": "tribunal/rubrics/code.md",
  "passing_score": 0.80,
  "expected_characteristics": {
    "min_score": 0.75,
    "max_score": 0.95,
    "required_bias_flags": [],
    "forbidden_bias_flags": ["verbosity_bias"],
    "max_iterations": 2
  },
  "tags": ["tribunal-judge", "bias-detection", "code"],
  "created": "2026-04-02",
  "baseline_file": "baselines/judge-bias-detection-001.json"
}
```

### Field reference

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique identifier. Use kebab-case. Becomes the baseline filename. |
| `description` | Yes | One sentence describing what this test verifies. Be specific. |
| `agent_file` | Yes | Relative path to the agent file being tested (e.g., `tribunal/agents/judge.md`). Echo uses this to filter tests on ConfigChange and to detect hash drift. |
| `task` | Yes | The full task prompt that will be sent to the Tribunal Actor. This is what gets evaluated. Write it as you would write a real task for that agent. |
| `rubric` | Yes | Relative path to the rubric file used for evaluation. |
| `passing_score` | Yes | Minimum score for the Tribunal pipeline to consider this a passing run. |
| `expected_characteristics` | No | Optional constraints used to detect regressions beyond overall score. |
| `expected_characteristics.min_score` | No | If current score drops below this, always flag as degraded regardless of thresholds. |
| `expected_characteristics.max_score` | No | Upper bound; scores above this may indicate overfitting. |
| `expected_characteristics.required_bias_flags` | No | Bias flags that MUST appear in the verdict. Missing flags = degraded. |
| `expected_characteristics.forbidden_bias_flags` | No | Bias flags that must NOT appear. A new forbidden flag = degraded. |
| `expected_characteristics.max_iterations` | No | If the pipeline uses more iterations than this, flag (non-failing). |
| `tags` | No | Array of strings for filtering. Use agent names, domain names, or test categories. |
| `created` | No | ISO date when this test case was written. |
| `baseline_file` | No | Conventional path to the baseline. Echo computes this automatically from the `id`. |

## Writing good test cases

### Be specific about what you are testing

A test case named `judge-001` tells you nothing. A test case named `judge-verbosity-bias-short-solution` tells you exactly what regression it guards against.

Write the `description` field to complete the sentence: "This test verifies that..."

### Write realistic tasks

The `task` field is sent verbatim to the Tribunal Actor. Write tasks that represent real usage:

- Too vague: `"Write some code"`
- Good: `"Implement a Ruby method that validates email addresses using a regex, with unit tests covering valid addresses, invalid addresses, and edge cases (empty string, nil)."`

### Choose the right rubric

Match the rubric to the task domain. Using `tribunal/rubrics/code.md` for a documentation task will produce misleading scores.

### Use `expected_characteristics` for targeted regression guards

If you specifically want to ensure that the Judge never flags verbosity bias on a concise correct solution, add `"forbidden_bias_flags": ["verbosity_bias"]` to `expected_characteristics`. This creates a targeted guard that fires even if the overall score stays flat.

### Tag thoughtfully

Tags drive filtering. Common conventions:
- `tribunal-actor`, `tribunal-judge`, `tribunal-meta-judge` — which agent is being tested
- `bias-detection` — tests for specific bias types
- `code`, `adr`, `docs` — task domain
- `fast` — tests expected to complete in one Tribunal iteration (useful for CI speed filtering)

### One concern per test case

Resist the urge to test everything in one case. If a test fails, you want to know exactly which capability regressed. Narrow test cases produce more actionable signal.

## Running test cases

```bash
# Run all tests
/echo:echo run --all

# Run tests for a specific agent
/echo:echo run --agent tribunal/agents/judge.md

# Run a single test
/echo:echo run --test judge-bias-detection-001
```

## Recording baselines

Before a test case can be used in a regression run, you must record its baseline:

```bash
/echo:echo record --test judge-bias-detection-001
```

Baselines are committed to version control. See `baselines/README.md`.
