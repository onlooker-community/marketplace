# @onlooker-community/dashboard

CLI tool to spin up a pre-configured Grafana dashboard for Onlooker telemetry data.

## Quick Start

```bash
bunx @onlooker-community/dashboard up
```

This starts a Bun API server and a Grafana container with pre-provisioned dashboards. Open `http://localhost:3456` to view your dashboards.

## Commands

| Command | Description |
|---------|-------------|
| `up` | Start the API server and Grafana container |
| `down` | Stop and remove both processes |
| `status` | Show running state, ports, and data file sizes |
| `logs` | Tail Grafana container logs (`--follow` for live) |
| `open` | Open the Grafana dashboard in your browser |

## Architecture

```text
JSONL files (host)          Bun API server (host:3457)      Grafana (container:3456)
~/.claude/logs/*.jsonl  -->  Bun.serve() routes        <--  JSON API datasource plugin
~/.claude/onlooker/*         /query, /metrics                Pre-provisioned dashboards
```

The API server reads Onlooker's JSONL event files and serves them as JSON to Grafana via the `marcusolsson-json-datasource` plugin. Grafana runs in a Docker container with anonymous admin access (local use only).

## Dashboards

- **Cost Overview** — total spend, cost by model, token usage breakdown
- **Session Activity** — session count, event type distribution
- **Hook Health** — hook success/failure rates, execution durations
- **Tool Usage** — file reads by type, skill invocations

## Requirements

- [Bun](https://bun.sh) (for the API server and CLI)
- A container runtime: [Docker](https://docker.com), [Podman](https://podman.io), or [nerdctl](https://github.com/containerd/nerdctl)

## Configuration

Override ports via environment variables:

```bash
ONLOOKER_GRAFANA_PORT=4000 ONLOOKER_API_PORT=4001 onlooker-dashboard up
```

## Data Sources

The API server reads from:

- `~/.claude/logs/onlooker-events.jsonl` — all Onlooker telemetry events
- `~/.claude/onlooker/metrics/costs.jsonl` — cost tracking per session

These files are created by the [Onlooker plugin](../../plugins/onlooker) hooks.

## Global Install

```bash
bun install -g @onlooker-community/dashboard
onlooker-dashboard up
```
