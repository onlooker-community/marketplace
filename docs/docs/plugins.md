# Plugin catalog

Each row is a **workspace package** under `plugins/<name>/`. Authoritative install instructions for end users stay in the root `README.md` and in each plugin’s own `README.md`; this table orients **contributors** who are browsing the tree.

| Directory | Focus |
| --------- | ----- |
| `plugins/archivist` | Structured session memory across context truncation |
| `plugins/cues` | Contextual guidance from triggers (prompts, commands, paths) |
| `plugins/counsel` | Weekly synthesis and improvement recommendations |
| `plugins/echo` | Prompt regression testing for agent files |
| `plugins/onlooker` | Observability spine for agents |
| `plugins/oracle` | Confidence calibration before action |
| `plugins/scribe` | Intent documentation for agent activity |
| `plugins/sentinel` | Pre-flight safety gate for destructive operations |
| `plugins/tribunal` | Multi-agent orchestration with quality gates |
| `plugins/warden` | Indirect prompt-injection detection on retrieved content |

## Where to read more

In a checkout, open `plugins/<name>/README.md` for narrative documentation and `plugins/<name>/.claude-plugin/plugin.json` for marketplace metadata (identifier, version, hooks registration, and so on).
