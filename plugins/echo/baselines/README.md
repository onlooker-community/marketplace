# Echo Baselines

Baselines live in this directory as individual JSON files — one per test case.

## Baselines are committed to version control

This is intentional and important. Baselines are not generated artifacts to be gitignored. They are the source of truth for what "correct behavior" looks like for each agent file.

**Why commit baselines?**

1. **PR visibility.** When an engineer modifies `tribunal/agents/judge.md` and opens a PR, the diff will include changes to any baseline that was re-recorded against the new agent. Reviewers can see before/after scores directly in the PR. No tooling required.

2. **Auditability.** The git history of a baseline file answers: "When did this agent's performance change, and by how much?" This is more reliable than any database.

3. **Reproducibility.** Anyone who clones the repo has the baselines. They can run `echo run` immediately without connecting to external state.

4. **Regression prevention.** If a baseline is deleted or degraded in a PR, that change is visible and blockable in code review.

## What is NOT committed

Run logs (`~/.claude/echo/runs/`) are local only. They are the ephemeral execution history of your machine. Only the recorded baselines — the deliberate snapshots — belong in version control.

## Schema

```json
{
  "test_id": "judge-bias-detection-001",
  "recorded": "2026-04-02T14:32:15Z",
  "agent_file_hash": "sha256 of agents/judge.md at record time",
  "result": {
    "final_score": 0.87,
    "iterations": 1,
    "pass": true,
    "judge_scores": [0.87],
    "bias_flags": [],
    "meta_approved": true
  },
  "rubric_scores": {
    "correctness": 0.90,
    "completeness": 0.85,
    "code_quality": 0.88,
    "error_handling": 0.82,
    "adherence": 0.92
  }
}
```

### Field reference

| Field | Description |
|-------|-------------|
| `test_id` | Matches the `id` in the corresponding test case file. |
| `recorded` | ISO 8601 timestamp when this baseline was recorded. |
| `agent_file_hash` | SHA-256 of the agent file content at record time. Echo warns if this no longer matches the current file, indicating the baseline predates a prompt change. |
| `result.final_score` | The overall weighted score the Tribunal pipeline produced. |
| `result.iterations` | Number of Actor-Judge iterations required to reach this score. |
| `result.pass` | Whether the score met the test case's `passing_score`. |
| `result.judge_scores` | Array of scores from each Judge in the panel (if multiple). |
| `result.bias_flags` | Bias flags raised by the Judge at record time. |
| `result.meta_approved` | Whether the Meta-Judge approved the verdict. |
| `rubric_scores` | Per-criterion scores from the rubric. Used for targeted regression detection. |

## Recording a baseline

```bash
/echo:echo record --test <test-id>
```

To overwrite an existing baseline:

```bash
/echo:echo record --test <test-id> --force
```

## Hash drift detection

If the agent file changes after a baseline is recorded, Echo will warn:

```
Warning: Agent file hash mismatch for tribunal/agents/judge.md.
Baseline was recorded against a different version of the agent.
Consider re-recording: /echo:echo record --test judge-bias-detection-001 --force
```

This is a warning, not an error. Echo will still run the test and compare against the old baseline. Whether to re-record is a judgment call: if you intentionally changed the agent file to improve it, re-record after verifying the new scores. If the baseline is stale from an unrelated change, re-record to reset the reference point.

## Gitignore note

The Echo `.gitignore` (if present) must NOT exclude this directory. Run logs (`~/.claude/echo/runs/`) are local and do not need a gitignore entry because they live outside the repository.
