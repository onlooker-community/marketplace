# Onlooker Ecosystem Overview

The Onlooker Marketplace is a collection of Claude Code plugins that add observability, safety, memory, and quality-control layers to agentic workflows. Each plugin hooks into Claude Code's lifecycle events and operates independently — you can install one plugin or all of them, and they compose cleanly when used together.

## The core idea

Claude Code exposes a lifecycle of events: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`, `PreCompact`, `SessionEnd`, and others. Plugins attach shell scripts and agent prompts to these events. When an event fires, the hooks run.

This means every plugin in the ecosystem works the same way: it observes or modifies Claude's behavior at specific lifecycle moments without changing Claude itself.

## What the ecosystem covers

The 13 plugins fall into five functional layers:

### Observability

| Plugin | What it does |
|--------|-------------|
| [onlooker](../plugins/onlooker/) | Core telemetry. Emits JSONL events for every significant agent action. The data source most other plugins read from. |
| [ledger](../plugins/ledger/) | Tracks token consumption and cost per session. Blocks subagent spawning when budgets are exceeded. |

### Memory & Continuity

| Plugin | What it does |
|--------|-------------|
| [archivist](../plugins/archivist/) | Extracts decisions, dead ends, and open questions before context is compacted. Reinjects them on session start. |
| [relay](../plugins/relay/) | Captures task state at session end (what you were doing, what's next, what's blocking) and injects it when you reopen. |

### Safety & Security

| Plugin | What it does |
|--------|-------------|
| [sentinel](../plugins/sentinel/) | Pattern-matched pre-flight gate for destructive Bash operations. Blocks, reviews, or logs based on configurable risk levels. |
| [warden](../plugins/warden/) | Scans content from WebFetch and Read for prompt injection patterns. Closes a content gate that blocks Write, Edit, and Bash until you explicitly clear it. |
| [oracle](../plugins/oracle/) | Confidence calibration before action. Detects when the agent is about to proceed on uncertain ground and pauses before costly misaligned work happens. |

### Quality Gates

| Plugin | What it does |
|--------|-------------|
| [tribunal](../plugins/tribunal/) | Multi-agent execution framework. An Actor does the work, a Judge evaluates the output, a Meta-Judge reviews the evaluation. |
| [echo](../plugins/echo/) | Prompt regression testing. Runs representative test cases when agent prompts change and reports whether output quality improved, degraded, or held. |

### Documentation & Instruction Health

| Plugin | What it does |
|--------|-------------|
| [scribe](../plugins/scribe/) | Captures *why* changes were made during execution and distills them into documentation artifacts. |
| [cartographer](../plugins/cartographer/) | Audits `CLAUDE.md` and `.claude/rules/` for contradictions, stale references, orphaned plugin commands, and hierarchy conflicts. |

### Synthesis & Guidance

| Plugin | What it does |
|--------|-------------|
| [counsel](../plugins/counsel/) | Weekly synthesis agent. Reads from all other plugin data sources and produces a structured improvement brief with layer-attributed findings. |
| [cues](../plugins/cues/) | Injects contextual guidance based on trigger matching against prompts, commands, and file paths. |

## How the plugins relate

Most plugins are independent. A few have notable relationships:

- **onlooker** is the data source that **counsel** and **ledger** depend on for event data.
- **tribunal** is the evaluation pipeline that **echo** runs against for regression testing.
- **sentinel** and **warden** are both safety gates but operate at different layers: Sentinel catches dangerous operations *you initiate*; Warden catches malicious instructions *arriving through content*.
- **sentinel** and **oracle** are complementary: Sentinel blocks operations that are dangerous regardless of intent; Oracle catches operations that are safe but misaligned with what you actually asked for.
- **archivist** and **relay** both address session continuity but at different granularities: Relay preserves immediate task state (what you were doing right now); Archivist preserves structural knowledge (decisions, dead ends, open questions) across many sessions.
- **cartographer** pushes its findings into **lore** (the shared epistemic store used by several plugins), making instruction health part of the cross-plugin picture that **counsel** synthesizes.

## Plugin installation

Plugins are installed by copying them from this repository into either your user-level plugin directory (all projects) or your project-level directory (single project):

```bash
# User scope — available in all projects
cp -r plugins/<name> ~/.claude/plugins/<name>

# Project scope — available in this project only
cp -r plugins/<name> .claude/plugins/<name>
```

After copying, Claude Code will load the plugin's hooks and commands automatically on the next session start.

For step-by-step setup, see [DEVELOPMENT.md](./DEVELOPMENT.md).
For all available plugins, see [Plugins](./plugins/README.md).
