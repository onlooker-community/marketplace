# ADR 0001: Use Tribunal Subagents as the Evaluation Engine

Date: 2026-04-04
Status: Accepted

## Context

Echo needs to evaluate agent output quality as part of its regression testing pipeline. This requires an evaluation engine capable of scoring LLM outputs against rubric criteria and detecting bias.

The evaluation must be consistent with the production quality gates that Tribunal already provides. Using a different evaluation approach would mean Echo's regression signals don't reflect the same quality bar as the system it is meant to protect.

Tribunal provides three subagents — `tribunal:tribunal-actor`, `tribunal:tribunal-judge`, and `tribunal:tribunal-meta-judge` — that form a complete evaluation pipeline: Actor executes the task, Judge scores the output against the rubric, Meta-Judge reviews the verdict for bias and consistency.

## Decision

Echo spawns Tribunal's subagents directly via the Claude Code Task tool to run evaluations. The agent names used in `config.json` must match the installed Tribunal plugin's actual namespaced agent names.

## Options considered

### Option A: Echo implements its own evaluation logic

Echo contains its own rubric scoring and bias detection code.

Rejected. This creates a second evaluation standard that will inevitably diverge from Tribunal's production quality gates. Any improvements to Tribunal's Judge would need to be ported to Echo separately. The surface area for drift is large.

### Option B: Echo calls /tribunal:run via slash command

Echo invokes the Tribunal slash command programmatically.

Rejected. Slash commands are designed for interactive use in a Claude Code session. They are not a stable programmatic API. Invoking them from a hook or script is fragile and unsupported. Slash command interfaces can change without notice.

### Option C: Echo spawns Tribunal's subagents directly via Task tool (chosen)

Echo uses the Task tool to spawn `tribunal:tribunal-actor` and `tribunal:tribunal-judge` as subagents in a controlled pipeline.

Accepted. This is the intended mechanism for inter-plugin composition in Claude Code. Subagent invocation is a first-class API. Echo gets the same evaluation quality as Tribunal's production pipeline with no duplication.

## Consequences

- Echo has a hard runtime dependency on Tribunal. Without Tribunal installed, `echo run` and `echo record` exit with a clear error.
- The agent names in Echo's `config.json` (`tribunal_actor`, `tribunal_judge`, `tribunal_meta_judge`) must match the names Tribunal registers. If Tribunal renames its agents, Echo's config must be updated.
- Echo's install is soft-dependency: it installs without Tribunal present. The dependency is only enforced at run time.
- Tribunal version changes that affect scoring behavior will be reflected in Echo's regression results automatically — which is the desired behavior.
