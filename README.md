# Onlooker Marketplace

## Installation

Add this marketplace to Claude Code:

```
# From GitHub
/plugin marketplace add onlooker-community/onlooker-marketplace

# From local checkout
/plugin marketplace add /path/to/onlooker-marketplace
```

## Available Plugins

### archivist

[archivist Plugin README](/plugins/archivist/README.md)

**Category:** Context Preservation

Extracts decisions, dead ends, and open questions before context is compacted. Reinjects the most important items when a new session starts.

### echo

[echo Plugin README](/plugins/echo/README.md)

**Category:** Regression Testing

Measurable before/after signals for every prompt change. Runs test cases through [Tribunal](/plugins/tribunal), compares scores against committed baselines, and reports improved, degraded, or neutral.

### onlooker

[onlooker Plugin README](/plugins/onlooker/README.md)

**Category:** Foundational

The observability spine for your agents. Hooks -> JSONL Telemetry -> Grafana dashboards. Local, observable agent telemetry on your machine.

### scribe

[scribe Plugin README](/plugins/scribe/README.md)

**Category:** Intent Capture

Captures _why_ changes were made, not what the code does. Two-phase architecture: lightweight capture during execution, then distill into readable docs when the session ends.

### sentinel

[sentinel Plugin README](/plugins/sentinel/README.md)

**Category:** Pre-Flight Gate

Pattern-matched risk evaluation before execution. Blocks dangerous commands, prompts for review on risky ones, and logs everything for audit. Zero latency on safe commands.

### tribunal

[tribunal Plugin README](/plugins/tribunal/README.md)

**Category:** LLM Judges

Orchestrate agents. Verify outputs with LLM judges. Automatic quality gates. All observable through Onlooker.

## Development

This is a monorepo containing multiple plugins. Each plugin is a separate directory in the `plugins/` directory.

### Quick Start

Clone this repository and run the following commands to get started:

```
# Install dependencies, run prepare scripts
bun install
```

## License

Copyright © 2026 [Onlooker Community](https://github.com/onlooker-community) under the [Blue Oak Model License 1.0.0](./LICENSE)
