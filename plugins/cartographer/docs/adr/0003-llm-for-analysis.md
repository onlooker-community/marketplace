---
status: accepted
date: 2026-04-14
deciders: [onlooker-community]
---

# 3. LLM Analysis vs Deterministic Parsing

## Status

Accepted

## Context

Cartographer needs to detect six issue categories in instruction files: contradictions, stale file references, orphaned plugin references, dead tool references, duplicates, and hierarchy conflicts.

Some of these can be detected deterministically:

- **Stale file references**: extract path-like strings, check existence with Glob
- **Orphaned plugin references**: extract `/plugin:command` patterns with regex, check if plugin directory exists

Others require judgment that a deterministic parser cannot provide:

- **Contradictions**: "always use tabs" + "use 2-space indentation" are contradictory. But "use tabs" + "use tabs in Python files only" are not. Determining whether two rules conflict requires understanding their scope, intent, and applicability
- **Duplicates**: "use TypeScript strict mode" and "enable strict: true in tsconfig.json" are the same rule. No regex matches these as duplicates — they share no common string
- **Dead tool references**: "run `npm test`" in a project with `bun.lockb` is a dead reference. Determining this requires understanding which lockfile corresponds to which package manager

## Decision

The Cartographer Auditor will be a `type: agent` using Haiku at medium effort. The agent performs all six checks — both the deterministic ones (using Glob/Read tools) and the judgment-based ones (using language understanding).

The mixed approach (agent for judgment, scripts for deterministic checks) was considered and rejected. The added complexity of maintaining two code paths (an agent prompt and shell scripts) is not justified when:

1. Haiku is fast enough for the deterministic checks (the overhead is minimal)
2. The agent must already read the instruction files for the judgment-based checks, so it can perform the deterministic checks in the same pass
3. A single pass through the files is more accurate than separate passes — the agent can cross-reference findings (a stale reference to a file + a rule about that file = one coherent issue, not two separate issues)

The agent is deliberately constrained:

- `model: haiku` — adequate for text analysis; avoids Sonnet/Opus cost
- `effort: medium` — enough for careful reading; not maximum which would be wasteful
- `maxTurns: 8` — sufficient for reading several files and writing output
- `disallowedTools: [Bash, Edit]` — read-only; cannot modify files or run commands

## Consequences

### Positive

- Contradiction and duplicate detection would be impossible with a deterministic script. The LLM approach unlocks the two most valuable check categories
- A single analysis pass produces coherent results — related issues are connected, not reported as unrelated findings
- The agent can apply judgment about severity: a stale reference in a comment is low severity; one in a prescriptive instruction is high
- New check categories can be added by extending the agent prompt, not by writing new code

### Negative

- LLM analysis introduces non-determinism: two runs on the same files might produce slightly different findings. Mitigated by the hash throttle (the same files are only analyzed once until they change) and the instruction to prefer false negatives over false positives
- Haiku at medium effort costs roughly $0.01–0.05 per audit. For a developer who changes instruction files daily, this is ~$0.01–0.05/day — negligible. For someone who changes them hourly, the throttle prevents runaway costs
- The agent cannot run shell commands to check tool availability (disallowedTools: Bash), so dead tool detection relies on lockfile presence rather than `which` checks

### Neutral

- The deterministic checks (stale files, orphaned plugins) could be faster as shell scripts, but the performance difference is imperceptible at the scale of instruction files (typically < 5 files, < 2000 words total)
