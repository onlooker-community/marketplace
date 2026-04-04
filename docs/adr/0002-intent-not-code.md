---
status: accepted
date: 2026-04-04
deciders: [onlooker-community]
---

# 2. Intent Not Code

## Status

Accepted

## Context

There are many tools that generate documentation from code — JSDoc, Sphinx, TypeDoc, and increasingly LLM-powered tools that read source files and produce API references. This is a solved problem.

The unsolved problem is documenting the reasoning behind technical decisions: why this approach was chosen over alternatives, what tradeoffs were accepted, what constraints shaped the design, and what approaches were tried and abandoned. This reasoning exists only in the developer's (or agent's) head during the moment of implementation. Once the session ends, it evaporates.

Git logs record what changed. Code comments (when they exist) describe what the code does. Neither captures why.

## Decision

Scribe captures intent — the reasoning behind changes — not descriptions of what code does.

The capture agent prompt explicitly constrains its output:
- `intent`: "What problem does this change solve?" (not "What does this code do?")
- `decision`: "What technical or design decision was made?" (not "What functions were added?")
- `tradeoffs`: "What was considered and rejected?" (not "What does the implementation look like?")
- `follow_up`: "What likely needs to change next?" (not "What are the function signatures?")

The distiller prompt reinforces this: "Write as if explaining to a thoughtful colleague who will read this once and needs to understand the reasoning, not the mechanics."

## Consequences

### Positive

- Scribe produces documentation that does not exist anywhere else — it fills the gap between code comments and git logs
- The output is useful even when the code changes, because the reasoning often outlasts the implementation
- By explicitly constraining against "what the code does," the prompts avoid the most common failure mode of AI-generated documentation

### Negative

- The capture agent may sometimes fail to extract meaningful intent from trivial or purely mechanical changes (mitigation: the `trivial` flag lets the agent skip these)
- Intent is the agent's stated reasoning, not ground truth — it reflects what the agent claimed to be doing, which may differ from what it actually did (mitigation: documented in README)

### Neutral

- Scribe's output complements rather than competes with API documentation tools. They can coexist.

## Alternatives Considered

### Generate API docs from code

- Pros: Well-understood problem, many existing tools, output is always accurate to the current code
- Cons: Already solved. Doesn't capture reasoning. Tells you what exists, not why it exists.
- Why rejected: Adding another API doc generator provides zero marginal value.

### Generate changelogs from git diffs

- Pros: Git is the source of truth for what changed, diffs are precise
- Cons: Git log already exists. LLM-generated changelogs from diffs are a slight improvement in readability but still describe what changed, not why.
- Why rejected: The "what" is already captured. The "why" is the gap.
