# Counsel

Weekly synthesis and recommendations from your observability stack.

Counsel reads from every plugin in the Onlooker ecosystem — Tribunal verdicts, Echo regressions, Sentinel audit logs, Warden gate events, Oracle calibration decisions, Archivist session extracts — and produces a structured improvement brief. It turns your observability stack from a dashboard into a coach.

## How it works

Counsel is a synthesis agent that runs weekly. On Monday morning (or on demand), it:

1. **Gathers** recent events from all configured plugin data sources
2. **Analyzes** the data through a synthesizer agent that understands cross-plugin patterns
3. **Produces** a layer-attributed brief with specific findings and one concrete recommendation per layer

### Layer-attributed analysis

The brief organizes findings by plugin layer, not by metric type. This structure is derived from research showing that decomposition by layer makes the marginal contribution of each component measurable.

| Layer | Plugins | What it reveals |
|-------|---------|-----------------|
| **Belief / Memory** | Archivist | Session memory quality, extraction failures |
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

## Install

```bash
/plugin install counsel@onlooker-marketplace
```
