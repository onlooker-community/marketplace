# 0003 — Tribunal cannot validate its own initial scaffold

Date: 2026-04-02
Status: Accepted

## Context and Problem Statement

Tribunal is a quality pipeline that evaluates artifacts through an Actor → Judge → Meta-Judge loop. A natural goal is to use Tribunal to improve Tribunal — running plugin files through the loop to catch schema errors, improve agent prompts, and refine rubrics.

However, the initial scaffold must be manually bootstrapped to a valid, installable state before the loop can run. If `hooks.json` has an invalid schema, or `plugin.json` references a missing file, the plugin will not load and `/tribunal:run` cannot be invoked.

This was encountered directly: the first scaffold had an invalid `hooks.json` (using non-existent `agent` and `background` keys). The error could not be caught by running Tribunal because Tribunal was not yet runnable.

## Decision Drivers

- Claude Code will not install a plugin with an invalid manifest or hooks schema.
- A broken plugin cannot invoke its own commands or agents.
- This is not a fixable limitation — it is a structural property of any self-hosting system. The Go compiler was written in C first. The first version of Tribunal must be written without Tribunal.
- The bootstrap phase is always manual. All subsequent changes can go through the loop.

## Considered Options

- **Option A: Manual bootstrap then self-hosted iteration**
  - Write and validate the initial scaffold by hand against Claude Code plugin docs.
  - Once installed and runnable, use Tribunal for all subsequent changes.
  - Accept that bootstrap is always manual; iteration is always Tribunal-hosted.

- **Option B: External schema validation tool**
  - Use a separate JSON Schema validator or linter to validate `plugin.json` and `hooks.json`.
  - Run external tool before installation, bypassing the need for a runnable Tribunal.
  - **Rejected:** Still requires something outside Tribunal. Adds tooling dependency without eliminating the fundamental constraint. The external tool itself would need validation.

- **Option C: Accept perpetual external validation**
  - Never attempt to self-host. Always validate Tribunal with external tools or manual review.
  - **Rejected:** Defeats the core value proposition of Tribunal. If we don't trust the loop to improve itself, why trust it to improve anything else? Self-hosting is a forcing function for quality.

- **Option D: Incremental bootstrap with minimal seed**
  - Start with the smallest possible valid plugin (one agent, no hooks, minimal config).
  - Add features incrementally, validating each addition with the running (partial) Tribunal.
  - **Rejected:** Still requires a manual first step — just a smaller one. Doesn't eliminate the bootstrap constraint, only shrinks the manual surface. Adds complexity to the development workflow for marginal benefit.

## Decision Outcome

Chosen: **Option A** — Manual bootstrap then self-hosted iteration.

Tribunal adopts a two-phase development model:

**Phase 1 — Manual bootstrap:** The initial scaffold is written and validated by hand. This includes verifying `plugin.json`, `hooks.json`, and agent frontmatter against the Claude Code plugin schema before attempting installation. The Claude Code plugin docs are the ground truth during this phase.

**Phase 2 — Self-hosted iteration:** Once the plugin is installed and `/tribunal:run` is callable, all subsequent changes — new rubrics, agent prompt improvements, config changes, new hook patterns — are dispatched through the Tribunal loop. The working scaffold is the baseline; the loop maintains and improves it from there.

### Consequences

- Good: Clear boundary between bootstrap (manual) and iteration (Tribunal-hosted).
- Good: The loop can be trusted once it's running — it has already survived the bootstrap gate.
- Bad: Schema errors introduced in the bootstrap phase cannot be caught automatically. The first version of any Tribunal deployment has a manual quality gap.
- Neutral: This is a known limitation of all self-hosting systems, not a design flaw specific to Tribunal.
- Future: A `SessionStart` hook that validates `plugin.json` and `hooks.json` against their schemas on startup would surface errors immediately, even if the plugin itself cannot run. This is deferred but noted.

## Links

- Relates to: [0001 — Hook type selection](0001-hook-type-selection.md) (the schema error that motivated this ADR)
- Relates to: [0004 — Domain-specific rubrics](0004-rubric-per-domain.md) (rubrics also cannot catch schema errors they don't encode)
