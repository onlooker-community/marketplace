# Archivist

Structured session memory across context truncation for Claude Code.

Archivist extracts decisions, dead ends, and open questions before context is compacted, then reinjects the most important items when a new session starts in the same project. Based on the YC-Bench finding (arXiv:2604.01212) that structured, reusable rules are the strongest predictor of long-horizon agent success.

## How it works

1. **PreCompact** — Before context is truncated, an extractor agent reads the session transcript and produces a structured extract with four categories: decisions (reusable rules), files (paths + rationale), dead_ends (failed approaches), and open_questions (unresolved items).

2. **SessionEnd** — The session extract is finalized with a completion timestamp.

3. **SessionStart** — The most recent extract for the current working directory is loaded and a concise summary (max 400 words) is injected into context. Prioritizes open questions, then decisions, then dead ends.

## Install

### User scope (all projects)

```bash
# clone this repository
cp -r archivist ~/.claude/plugins/archivist
```

### Project scope (single project)

```bash
# clone this repository
cp -r archivist .claude/plugins/archivist
```

## Usage

Session memory is automatic once installed. Use the slash command to inspect or manage it:

```
/archivist:memory show              # Most recent session extract
/archivist:memory show --all        # All sessions for current cwd
/archivist:memory show --session <id>  # Specific session
/archivist:memory forget --session <id>  # Delete a session
/archivist:memory forget --cwd      # Delete all sessions for current cwd
/archivist:memory status            # Config and connection status
```

## Configuration

Edit `config.json` in the plugin directory:

| Key | Default | Description |
|-----|---------|-------------|
| `storage_path` | `~/.claude/archivist/sessions` | Where session extracts are stored |
| `max_injection_words` | `400` | Maximum words in the SessionStart injection |
| `inject_on_start` | `true` | Whether to inject context on session start |
| `extract_on_compact` | `true` | Whether to extract on PreCompact |
| `extract_on_end` | `true` | Whether to finalize on SessionEnd |
| `min_confidence_to_inject` | `"medium"` | Minimum confidence level for injecting decisions |

## Example session extract

```json
{
  "session_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "cwd": "/Users/dev/myproject",
  "timestamp": "2026-04-03T14:30:00Z",
  "decisions": [
    {
      "rule": "Use absolute imports throughout the project — relative imports cause circular dependency issues in the plugin system",
      "rationale": "Discovered when adding the hook loader; relative imports between scripts/ and agents/ created import cycles",
      "confidence": "high"
    }
  ],
  "files": [
    {
      "path": "/Users/dev/myproject/src/loader.py",
      "change": "Added plugin discovery with glob pattern matching",
      "reason": "Needed to support both user-scope and project-scope plugin directories"
    }
  ],
  "dead_ends": [
    {
      "approach": "Tried using importlib.metadata to discover plugins",
      "why_failed": "Requires packages to be installed with entry_points, which doesn't work for file-based plugins that aren't pip-installed"
    }
  ],
  "open_questions": [
    {
      "question": "Should plugin configs be merged or overridden when both user and project scope exist?",
      "context": "Currently project scope wins entirely, but users may want to set defaults at user scope",
      "priority": "high"
    }
  ],
  "complete": true,
  "completed_at": "2026-04-03T15:45:00Z"
}
```

## Onlooker integration

Archivist works standalone, or out-of-the-box with Onlooker. No configuration needed — if Onlooker is installed, it automatically picks up Archivist's session events.

Archivist emits `archivist_session` events on SessionEnd containing session metadata and counts. The full session extract is not sent — only aggregate stats and high-priority question text.

### Event schema

```json
{
  "type": "archivist_session",
  "workspaceId": "archivist",
  "session_id": "a1b2c3d4-...",
  "cwd": "/Users/dev/myproject",
  "timestamp": "2026-04-03T15:45:00Z",
  "decision_count": 2,
  "file_count": 3,
  "dead_end_count": 1,
  "open_question_count": 1,
  "high_priority_questions": ["Should plugin configs be merged or overridden?"]
}
```

## Architecture

See [docs/adr/](docs/adr/) for architecture decision records.
