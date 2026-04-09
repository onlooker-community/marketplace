# Warden

Indirect prompt injection detection on content retrieved by your agent.

Warden monitors content flowing into your agent through WebFetch and Read operations, scanning for injection patterns before the agent processes it. When a threat is detected, Warden closes a content gate that blocks Write, Edit, and Bash operations until you explicitly clear it.

## How it works

Warden operates as a two-phase content gate:

1. **PostToolUse scan** — After WebFetch or Read returns content, Warden scans it against known injection patterns (instruction overrides, data exfiltration attempts, action hijacking). If patterns match, the gate closes.

2. **PreToolUse gate** — Before Write, Edit, or Bash operations execute, Warden checks the gate state. If the gate is closed (injection detected), the operation is blocked with an explanation.

### The Rule of Two

Warden is grounded in Meta's Agents Rule of Two: an agent should satisfy no more than two of three properties simultaneously — access to private data, ability to take external actions, and processing of untrusted content. When untrusted content contains injection patterns, Warden removes the "ability to take external actions" property until the user explicitly clears the gate.

## Gate states

| State | Meaning | Agent behavior |
|-------|---------|----------------|
| **Open** | No injection signals detected | All operations proceed normally |
| **Closed** | Injection pattern detected in retrieved content | Write, Edit, and Bash operations are blocked |

The gate requires **explicit user clearance** to re-open (`/warden:gate clear`). It does not auto-clear by default — this is a deliberate security decision to prevent the agent from being manipulated into clearing its own gate.

## Pattern categories

- **Instruction injection** — Attempts to override system prompts, change agent roles, or inject hidden directives
- **Data exfiltration** — Instructions to send data to external URLs, abuse tool calls for exfiltration, or encode/smuggle data
- **Action hijacking** — Instructions directing the agent's next actions, targeting sensitive files, or suppressing output

## Commands

- `/warden:gate status` — View current gate state and configuration
- `/warden:gate audit` — View recent scan and gate decisions
- `/warden:gate clear` — Re-open the gate after reviewing flagged content
- `/warden:gate block` — Manually close the gate
- `/warden:gate patterns` — List all loaded injection patterns

## Relationship to Sentinel

Sentinel blocks **dangerous operations you initiate** (rm -rf, force push, DROP TABLE).
Warden blocks **malicious instructions arriving through content** (prompt injection in fetched pages, repos, documents).

They operate at different layers and are complementary.

## Configuration

See `config.json` for defaults:

- `scan_tools` — Tools whose output is scanned (default: WebFetch, Read)
- `gate_tools` — Tools blocked when gate is closed (default: Write, Edit, Bash)
- `auto_clear` (false) — Whether the gate auto-clears (default: no, requires `/warden:gate clear`)
- `safe_paths` — Paths exempt from scanning (default: /tmp, ~/.claude/archivist, ~/.claude/logs)
- `max_content_scan_bytes` (102400) — Max bytes to scan per tool response

## Install

```bash
/plugin install warden@onlooker-marketplace
```
