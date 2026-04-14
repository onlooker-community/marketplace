---
status: accepted
date: 2026-04-14
deciders: [onlooker-community]
---

# 2. Hook Scope: SubagentStart/Stop + Stop + SessionEnd

## Status

Accepted

## Context

Ledger needs to (a) accumulate cost data and (b) enforce budget constraints. Several Claude Code hooks are candidates. The design requirement from the brief is explicit: no PreToolUse — this is about agent spawning cost, not Bash operations.

The available hooks and what they provide:

| Hook | Fires when | Provides usage data | Can block |
|------|-----------|---------------------|-----------|
| PreToolUse | Before any tool call | No | Yes (exit 2) |
| PostToolUse | After any tool call | Partial | No |
| SubagentStart | Before an agent spawns | No | Yes (exit 2) |
| SubagentStop | After an agent finishes | Yes (agent usage) | No |
| Stop | Claude finishes a response | Yes (turn usage) | No |
| SessionEnd | Session closes | No | No |

## Decision

We will use exactly four hooks:

**SubagentStart** — The enforcement point. Reads the current session ledger and blocks if the budget is exceeded. Does not have usage data (the agent hasn't run yet), so it only reads; it increments `subagent_count` as a lightweight spawn record.

**SubagentStop** — Accumulates the completed subagent's token usage into the session ledger's `subagent_*` fields. Runs async since it doesn't block anything downstream and cost recording is best-effort.

**Stop** — The primary cost accumulation hook. Every Claude response generates a Stop event with full usage data. This is where the session running total is updated. Also emits budget warnings to stderr at the warning threshold.

**SessionEnd** — Finalizes the session file (adds `ended_at`, sets `finalized: true`) and appends a summary line to the all-sessions log for cross-session reporting. Runs async.

## Consequences

### Positive

- The four hooks cover the full lifecycle without overlapping responsibilities
- SubagentStart is the correct semantic point for enforcement — it fires once per spawn attempt, not once per tool call
- Stop is the only hook that reliably provides per-turn usage data; using it for accumulation is the natural fit
- Async on SubagentStop and SessionEnd means finalization never adds latency to Claude's response loop

### Negative

- SubagentStop may not fire if a subagent is killed mid-execution. The session ledger will undercount in that case, potentially allowing more spawns than intended. The reserve buffer mitigates this
- Stop fires per turn, not per session. A session with 50 turns generates 50 Stop events. The atomic write-via-rename pattern in `ledger_write_session` prevents corruption but adds per-turn file I/O

### Neutral

- PreToolUse is intentionally excluded. Ledger is not a Bash safety gate (that is Sentinel's domain). Using PreToolUse would conflate two distinct concerns and add overhead to every tool call

## Alternatives Considered

### Use PostToolUse to catch Agent tool completions

- Pros: Fires after every tool call, including Agent; could extract usage from agent responses
- Cons: Usage data in PostToolUse is for the tool invocation, not the agent's internal token consumption. SubagentStop is the correct hook for agent-level usage
- Why rejected: Wrong level of abstraction; SubagentStop is purpose-built for this

### Single hook: Stop only (no SubagentStart/Stop)

- Pros: Simpler — one hook, one responsibility
- Cons: Without SubagentStart, there is no enforcement point. Without SubagentStop, subagent cost is not separated from main session cost, making attribution impossible
- Why rejected: Enforcement requires SubagentStart; attribution requires SubagentStop
