# Counsel

Weekly synthesis and recommendations from your observability stack.

Counsel reads from every plugin in the Onlooker ecosystem — Tribunal verdicts, Echo regressions, Sentinel audit logs, Warden gate events, Oracle calibration decisions, Archivist session extracts — plus **[Lore](../../tools/lore/README.md)**, the shared epistemic store (open questions with rising urgency, contradiction edges, stale hypotheses). It produces a structured improvement brief. It turns your observability stack from a dashboard into a coach.

## How it works

Counsel is a synthesis agent that runs weekly. On Monday morning (or on demand), it:

1. **Gathers** recent events from all configured plugin data sources. When Lore is enabled, `counsel-gather` also attaches `sources.lore`: a snapshot from `lore export-for-brief` for the **current working directory** (same cwd as when you run `/counsel:brief generate`), filtered by the same lookback window as other sources.
2. **Analyzes** the data through a synthesizer agent that understands cross-plugin patterns
3. **Produces** a layer-attributed brief with specific findings and one concrete recommendation per layer

### Layer-attributed analysis

The brief organizes findings by plugin layer, not by metric type. This structure is derived from research showing that decomposition by layer makes the marginal contribution of each component measurable.

| Layer | Plugins | What it reveals |
|-------|---------|-----------------|
| **Belief / Memory** | Archivist, Lore | Session memory quality, extraction failures; **Lore** adds ranked open questions, contradicted knowledge, and tentative hypotheses so the brief can separate settled patterns from contested or unresolved ones |
| **Planning** | Oracle, Scribe | Confidence calibration, intent capture gaps |
| **Safety** | Sentinel, Warden | Blocked operations, injection detections |
| **Reflection** | Tribunal, Echo | Quality gate performance, regressions |
| **Observability** | Onlooker | Event volume, hook health, cost trends |

## The gap it fills

Onlooker tells you what happened. Counsel tells you what to do about it.

Without Counsel, the weekly review is a manual process of reading dashboards and audit logs. With Counsel, it's a generated brief you react to — top 3 friction points, failing rubric criteria, degraded prompts, and one action per layer.

## Commands

- `/counsel:brief generate` — Generate a new improvement brief
- `/counsel:brief latest` — View the most recent brief
- `/counsel:brief history` — List all generated briefs
- `/counsel:brief sources` — Check data source availability and freshness

## Schedule

By default, Counsel checks on SessionStart whether a brief is due (>6 days since last run). It notifies you but does not auto-generate — you trigger generation with `/counsel:brief generate`.

Configure in `config.json`:
- `schedule.day` — preferred day for briefs (default: monday)
- `schedule.min_days_between_runs` — minimum days between briefs (default: 6)
- `schedule.auto_run_on_session_start` — whether to check on session start (default: true)

## Configuration

See `config.json` for all options:

- `sources` — paths to each plugin's data files
- `lookback_days` (7) — how far back to gather data
- `max_events_per_source` (500) — cap per source to keep analysis focused
- `brief_format` — "layer-attributed" (only supported format currently)
- `lore.enabled` (`true`) — when `true`, gather attaches `sources.lore` with a Lore snapshot for the project cwd. Set to `false` to omit Lore from gathered JSON

## Lore integration

[Lore](../../tools/lore/README.md) is not a Counsel plugin; it is a standalone CLI backed by `~/.claude/lore/lore.sqlite`. Archivist, Scribe, and Cartographer write into it; Counsel **reads** a ranked slice at brief time.

**Gathered shape.** Under `sources.lore` you will find:

- `count` — number of entries in `top_questions` from the snapshot (quick signal for “is Lore empty?”)
- `snapshot` — the full `lore export-for-brief` payload: `top_questions`, `top_contradictions`, `stale_hypotheses`, `since`, `cwd`, `generated_at`

The synthesizer is instructed to use `sources.lore.snapshot` when present so the brief can call out **unresolved ignorance** (urgent questions), **contested** instruction or memory (contradiction suppression), and **stale tentative** beliefs separately from flat Archivist text.

**CLI resolution.** Gathering uses the same resolver as other plugins: `LORE_CLI`, a `lore` binary on `PATH`, walking parents for `tools/lore/bin/cli.ts` in a monorepo checkout, or `bunx @onlooker-community/lore`. If none resolve, Lore data is omitted and the brief still generates.

**Cwd.** Lore export uses the directory from which gather runs (typically your project root when you invoke `/counsel:brief generate`). Run the command from the repo you care about so questions and decisions match that tree.

## Install

```bash
/plugin install counsel@onlooker-marketplace
```
