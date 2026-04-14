---
status: accepted
date: 2026-04-14
deciders: [onlooker-community]
---

# 1. Conservation Law Budget Model

## Status

Accepted

## Context

The Agent Contracts paper (arXiv) demonstrates a conservation law for token budgets in multi-agent systems: when an orchestrator delegates work to subagents, the sum of all delegated budgets must not exceed the parent's own budget minus a coordination reserve (10–15%). This prevents unbounded resource consumption through recursive spawning.

Without a circuit breaker, a runaway Tribunal loop, an Echo suite expanding beyond its test-case set, or an Archivist distillation on a long session can accumulate significant API cost with no stopping condition. Onlooker records what happened; nothing prevents it.

The key constraint is that cost tracking in Claude Code hooks is **additive across turns**. The `Stop` event fires once per Claude response, not once per session. A single session with many back-and-forth turns generates many Stop events, each carrying only that turn's token usage. The ledger must accumulate these across events into a single session total.

## Decision

We will implement a session-scoped ledger that:

1. **Accumulates cost from every Stop event** into a per-session JSON file at `~/.claude/ledger/sessions/<session_id>.json`. Each Stop event adds its delta; the file holds the running total.

2. **Applies a conservation-law check at SubagentStart** — before a subagent is allowed to spawn, the hook reads the current session total and compares it to the configured budget. If the effective limit (budget × (1 − reserve_buffer_pct / 100)) is reached, the hook exits with code 2 to block the spawn.

3. **Tracks subagent cost separately** from the main session cost in the ledger (fields `subagent_cost_usd`, `subagent_input_tokens`, `subagent_output_tokens`). The budget check uses the combined total. This mirrors the Agent Contracts model: parent cost + delegated cost must not exceed the parent budget.

4. **Uses a 12% reserve buffer by default** (configurable via `reserve_buffer_pct`). This buffer accommodates coordination overhead — the final response that surfaces the budget warning consumes tokens that are not tracked until after the check. The buffer prevents the budget from being exceeded by the response that reports it is exceeded.

5. **Emits a warning at a configurable threshold** (default: 80% of budget) without blocking, so users can finish a thought before hitting the circuit breaker.

## Consequences

### Positive

- Matches the Agent Contracts conservation law without requiring formal contract machinery — the plugin-level hook is sufficient
- The circuit breaker is at SubagentStart, the cheapest point to enforce the constraint (before the subagent's context is loaded)
- Per-session JSON files allow inspection and manual reset (`/ledger:ledger reset`) without affecting other sessions
- The reserve buffer means the budget warning can itself be delivered without triggering the constraint

### Negative

- Token counts from the Stop event are estimates — they reflect what was billed for that turn, but the session total may differ slightly from the Anthropic invoice due to caching behavior and batching
- The circuit breaker only fires at SubagentStart, not mid-subagent. A subagent that is already running when the budget is exceeded will complete; only the next spawn is blocked
- Cost accumulation depends on Stop firing reliably. If Claude Code crashes mid-session, the final turn's cost is not recorded

### Neutral

- The `block_on_budget_exceeded` config key allows the circuit breaker to be disabled (warning-only mode) for users who want visibility without enforcement

## Alternatives Considered

### Track cost only at SessionEnd

- Pros: Simpler — one write per session, no accumulation needed
- Cons: SessionEnd fires after the session is over. There is no opportunity to block anything. We want guidance.
- Why rejected: Doesn't address the circuit breaker requirement. Onlooker already provides post-hoc observability

### Use PreToolUse to intercept Agent tool calls

- Pros: Fires before every agent spawn regardless of how it's invoked
- Cons: The Agent tool is one of many tools Claude can call; PreToolUse fires on all tool calls, requiring pattern matching to isolate Agent invocations. SubagentStart is semantically precise — it fires exactly when an agent is about to be spawned, with no filtering required
- Why rejected: SubagentStart is the correct hook for this. The hook system provides the right level of abstraction

### Enforce budget via config (max_turns, etc.)

- Pros: No token counting needed
- Cons: Turn count is a poor proxy for cost. A single Tribunal judge panel with 5 models is far more expensive than 50 cheap tool calls
- Why rejected: Cost-based budgets require cost tracking; turn limits don't address the problem
