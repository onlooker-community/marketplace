---
status: accepted
date: 2026-04-03
deciders: [onlooker-community]
---

# 1. Pattern Matching Architecture

## Status

Accepted

## Context

Sentinel fires on every Bash call via `PreToolUse`. Latency is the primary constraint — adding evaluation overhead to every `ls`, `git status`, or `echo` would make the plugin unusable. We need a mechanism that lets the vast majority of Bash calls pass through with zero added latency while still catching destructive operations.

The Claude Code hook system provides an `if` field that pre-filters before the hook body executes. Only commands matching the `if` field pattern trigger the hook at all.

## Decision

We will use a two-layer architecture:

1. **Layer 1: `if` field pre-filter** — The hook's `if` field contains a glob-style pattern matching known-dangerous command prefixes (`rm *`, `git push*--force*`, `DROP *`, etc.). Commands not matching any pattern pass through instantly with zero latency. This filtering happens in the hook system itself before Sentinel code runs.

2. **Layer 2: Prompt-based evaluation** — For commands that match the `if` field, a `type: prompt` hook (single-turn, no tool access) evaluates the command in context. The prompt classifies risk level (critical/high/medium/low), looks up the configured behavior (block/review/log), and returns the appropriate hook output.

A deterministic fallback (`scripts/evaluate.sh`) provides the same pattern matching and classification without LLM evaluation, for CI/CD contexts or when faster-than-prompt evaluation is needed.

## Consequences

### Positive

- Zero latency for non-matching Bash calls — the hook system handles filtering before Sentinel code runs
- LLM evaluation adds contextual judgment that pure regex cannot (e.g., understanding branch names, path safety)
- The deterministic fallback ensures Sentinel works in headless/offline contexts
- Pattern coverage is explicitly defined and auditable via `patterns/*.json`

### Negative

- The `if` field is the most important maintenance surface in the plugin — gaps in the `if` field are gaps in safety coverage. A destructive command not listed in the `if` pattern will never be evaluated
- The `if` field pattern and the `patterns/*.json` regexes are two separate representations of "what's dangerous" that must be kept in sync. Drift between them means the `if` field might trigger on a command that no pattern matches (wasted evaluation) or a pattern might exist for a command the `if` field doesn't catch (dead pattern)
- Prompt-based evaluation adds 2-15 seconds of latency for matching commands. This is acceptable for destructive operations (where a pause is appropriate) but would be unacceptable for routine commands

### Neutral

- The `type: prompt` hook is single-turn with no tool access, which is faster than `type: agent` but cannot do complex reasoning like reading files or checking git state directly

## Alternatives Considered

### Evaluate every Bash call with LLM

- Pros: Complete coverage, no pattern gaps
- Cons: 2-15 seconds added to every Bash call including `ls`, `cd`, `git status`. Completely unusable
- Why rejected: Latency makes the plugin un-installable. Users would disable it immediately

### Pure regex matching with no LLM

- Pros: Fastest possible evaluation, deterministic, no API costs
- Cons: No contextual judgment — cannot understand "this is a feature branch" vs "this is main", cannot assess whether a path is safe in context, cannot provide nuanced safer alternatives
- Why rejected: Regex alone produces too many false positives (blocking safe operations) and false negatives (missing dangerous operations that don't match exact patterns). The LLM layer adds judgment that justifies the latency for matching commands

### `type: agent` hook with tool access

- Pros: Could read git state, check branch names, read file contents before deciding
- Cons: Agent hooks are significantly slower (30-120 seconds), spawn a full agent context, and the timeout for safety evaluation should be tight (15 seconds)
- Why rejected: Speed is non-negotiable for a pre-flight gate. The prompt approach gives good-enough judgment within the latency budget
