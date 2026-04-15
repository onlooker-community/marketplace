---
status: accepted
date: 2026-04-14
deciders: [onlooker-community]
---

# 2. Agent Hook at SessionEnd for Capture

## Status

Accepted

## Context

The capture step needs to answer: "What was the developer doing, and what should they do next?" This requires reading the conversation and reasoning about task state. A command script cannot do this — it can read files and JSON, but it cannot interpret "what was being worked on."

Two hook types can do reasoning: `type: prompt` (single-turn, no tools) and `type: agent` (multi-turn, has tools including Write).

The capture agent needs to write a file (the handoff JSON), so `type: prompt` is insufficient — prompt hooks cannot take actions. `type: agent` is required.

The question is: which hook event?

**PreCompact** (Archivist's choice): fires when context is about to be truncated, while the session is still active. The transcript is explicitly available via hook input. Fires multiple times per session.

**SessionEnd**: fires when the session closes. The agent has memory of the full session. Fires once per session — exactly what Relay needs (one handoff per session close).

**Stop**: fires after each Claude response. Would fire too frequently for a handoff — a handoff should represent "I'm done for now," not "I finished one response."

## Decision

We will use `type: agent` at `SessionEnd`.

The agent is the right capture mechanism because:

1. It can reason about "what was being done" rather than just extracting structured fields
2. It can use the Write tool to persist the handoff JSON
3. It fires exactly once at session close — the moment the handoff is needed

The agent runs with `model: haiku` and `effort: low` to minimize session-close latency. The handoff is a structured JSON write — it does not require deep reasoning, just task state assessment and accurate field population. Haiku at low effort is sufficient and keeps the capture under 10 seconds in typical cases.

The agent prompt explicitly forbids Bash to prevent it from running arbitrary commands during session cleanup. It also forbids Edit (Write-only — the handoff file doesn't exist yet, so there's nothing to edit).

## Consequences

### Positive

- The agent can interpret the conversation and make judgment calls about task state (partial vs. nearly_complete, what constitutes a blocking question vs. a resolved one)
- SessionEnd fires exactly once, producing one handoff per session — the right cardinality
- The agent writes its own file via Write tool — no shell plumbing needed for the output path
- `model: haiku` at `effort: low` keeps capture fast and cheap (typically < $0.01 per session)

### Negative

- Agent hooks at SessionEnd add latency to session close. The user has already closed Claude Code, so this latency is invisible — but the handoff file is not immediately available. It will exist within ~10 seconds of session close
- If Claude Code crashes rather than closing cleanly, SessionEnd may not fire and the handoff will not be generated. The previous session's handoff remains injected until a new one is written
- Agent hooks can fail silently if the model is unavailable or rate-limited. The inject script handles a missing handoff gracefully (no injection, no error)

### Neutral

- The agent uses `maxTurns: 3` — read hook input, reason about session state, write the file. Three turns is sufficient; more would be wasteful
- The `prompt` field in hooks.json provides the agent's task framing, while `agentPath` points to the full agent definition in `agents/relay-capture.md`

## Alternatives Considered

### `type: prompt` at SessionEnd

- Pros: Faster than agent; simpler
- Cons: Prompt hooks cannot write files. The handoff must be written somewhere — either the prompt outputs it to stdout (which Claude Code may not capture as a file) or we need a separate write step. The agent approach is cleaner
- Why rejected: Cannot persist the handoff without Write tool access

### Command script with jq extraction

- Pros: No LLM cost; deterministic; fast
- Cons: Cannot interpret "what was the developer working on" from a session. A command script can read structured data; it cannot understand conversation content. Relay's value is in capturing task state that requires interpretation, not just field extraction
- Why rejected: The problem requires reading comprehension, not data extraction. A command script is the right tool for injection (relay-inject.sh) where the input is already structured JSON. It is the wrong tool for capture where the input is an open-ended conversation

### `type: agent` at PreCompact (same as Archivist)

- Pros: Transcript is explicitly available; fires while session is still active
- Cons: PreCompact fires on context truncation, not on session close. A developer who closes Claude Code mid-session without triggering a compact will get no handoff. Also, PreCompact can fire multiple times; we want exactly one handoff per session close
- Why rejected: Wrong trigger. Relay's semantic is "I'm done for now" — that's SessionEnd, not PreCompact
