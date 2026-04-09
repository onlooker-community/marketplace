# Oracle

Confidence calibration before action.

Oracle detects when the agent is about to proceed on uncertain ground and intervenes before costly misaligned work happens. It catches the failure mode that no other plugin addresses: the agent that proceeds confidently on a misunderstood task and does a lot of correct work toward the wrong goal.

## How it works

Oracle fires on two lifecycle events:

- **UserPromptSubmit** — When the user submits a prompt, Oracle assesses whether the request is clear enough for the agent to proceed correctly. Ambiguous prompts that could lead to divergent interpretations are flagged before work begins.

- **PreToolUse (Write, Bash)** — Before high-consequence tool calls, Oracle checks whether the agent has sufficient confidence that the action is aligned with the user's intent.

### Three confidence states

| State | Meaning | Action |
|-------|---------|--------|
| **confident** | Two independent interpretations would converge | Proceed silently |
| **uncertain_recoverable** | Some ambiguity, but interpretations are close | Flag assumption, proceed with caveat |
| **uncertain_high_stakes** | Ambiguous AND interpretations diverge significantly | Pause and ask the user |

### Convergence sampling

The key insight from calibration research: sampling multiple responses and measuring consistency is the most reliable black-box confidence signal. For ambiguous situations, Oracle's prompts instruct the evaluator to consider whether re-deriving the action from scratch would produce the same result — a lightweight convergence test.

## Relationship to Sentinel

Sentinel blocks **dangerous operations** (rm -rf, force push, DROP TABLE).
Oracle catches **misaligned operations** (correct code toward the wrong goal).

They are complementary. A file write can be perfectly safe (Sentinel won't fire) but completely wrong (Oracle will catch that the agent misunderstood the task).

## Configuration

See `config.json` for defaults:

- `confidence_threshold.proceed` (0.8) — Above this, always proceed
- `confidence_threshold.flag` (0.5) — Below this, escalate to high-stakes pause
- `skip_patterns` — Commands that bypass calibration (read-only, tests, linters)
- `convergence_sampling` — Enable/disable the convergence test heuristic

## Commands

- `/oracle:oracle show` — Display current configuration
- `/oracle:oracle audit` — View recent calibration decisions
- `/oracle:oracle stats` — Calibration statistics and health
- `/oracle:oracle threshold` — Adjust thresholds for this session
- `/oracle:oracle disable` / `enable` — Toggle for this session

## Install

```bash
/plugin install oracle@onlooker-marketplace
```
