---
name: brief
description: Generate or view a Counsel improvement brief — weekly synthesis of friction, regressions, and recommendations across all plugins
---

# /counsel:brief

Generate or view a Counsel improvement brief.

## Subcommands

### `generate`
Generate a new improvement brief by reading from all configured data sources over the configured lookback period (default: 7 days). The brief follows the layer-attributed format described below.

Steps:
1. Run the `counsel-gather` script to collect raw data from all sources
2. Spawn the `counsel-synthesizer` agent to analyze the gathered data and produce the brief
3. Write the brief to the configured `output_dir` as a timestamped markdown file
4. Update `last_run_file` with the current timestamp

If a brief was already generated within `min_days_between_runs`, warn the user and ask if they want to regenerate.

### `latest`
Display the most recent brief from the output directory. If no briefs exist, say so and suggest running `/counsel:brief generate`.

### `history`
List all generated briefs with their dates and one-line summaries. Show the 10 most recent.

### `sources`
Display the status of all configured data sources:
- Whether each source file/directory exists
- How many events/entries each contains within the lookback window
- Last modification time

This helps diagnose why a brief might be missing data from a particular plugin.

## Brief Format: Layer-Attributed

The brief MUST organize findings by plugin layer, not by metric type. This structure makes the marginal contribution of each component measurable.

```
## This Week's Friction by Layer

### Belief / Memory layer (Archivist)
- [findings about session memory quality, extraction failures, stale memories]
- Recommended action: [one concrete action]

### Planning layer (Oracle + Scribe)
- [findings about confidence calibration frequency, intent capture gaps]
- Recommended action: [one concrete action]

### Safety layer (Sentinel + Warden)
- [findings about blocked operations, injection detections, false positives]
- Recommended action: [one concrete action]

### Reflection layer (Tribunal + Echo)
- [findings about quality gate pass rates, regression trends, judge disagreement]
- Recommended action: [one concrete action]

### Observability layer (Onlooker)
- [findings about event volume, hook health, cost trends]
- Recommended action: [one concrete action]

## Top 3 Friction Points
1. [highest-frequency friction point with source attribution]
2. [second highest]
3. [third highest]

## Rubric Criteria Failing Most Often
- [from Tribunal verdicts: which rubric criteria fail most]

## Echo Regression Trends
- [from Echo runs: which prompts have degraded]

## Summary
[2-3 sentence overall assessment]
```

## Behavior

- The `generate` command is the only one that writes data. All others are read-only.
- Counsel never modifies the data sources it reads from.
- If a data source is missing or empty, the corresponding layer section should note "No data available" rather than omitting the section.
- The brief is a snapshot — it reflects the state of data sources at generation time.
