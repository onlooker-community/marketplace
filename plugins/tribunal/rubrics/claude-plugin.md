# Claude Code Plugin Rubric

This rubric evaluates Claude Code plugin files for schema compliance, structural correctness, and adherence to plugin conventions. It covers `plugin.json`, `hooks.json`, agent `.md` files, and overall plugin structure.

**Canonical references:**

- Plugin manifest & components: https://code.claude.com/docs/en/plugins-reference
- Hooks system: https://code.claude.com/docs/en/hooks
- Subagents: https://code.claude.com/docs/en/sub-agents

## Criteria

**1. plugin.json Schema Compliance (25%)**

The manifest file lives at `.claude-plugin/plugin.json`. It is optional — if omitted, Claude Code auto-discovers components in default locations and derives the plugin name from the directory name. When present, validate:

### Required fields

If a manifest is present, `name` is the **only required field**.

| Field  | Type   | Rules | Example |
| :----- | :----- | :---- | :------ |
| `name` | string | Unique identifier. Must be kebab-case (lowercase, hyphen-separated, no spaces). Used for namespacing components (e.g., `plugin-name:agent-name`). | `"deployment-tools"` |

### Metadata fields (all optional)

| Field | Type | Description | Example |
| :---- | :--- | :---------- | :------ |
| `version` | string | Semantic version (`MAJOR.MINOR.PATCH`). If also set in marketplace entry, `plugin.json` takes priority. | `"2.1.0"` |
| `description` | string | Brief explanation of plugin purpose | `"Deployment automation tools"` |
| `author` | object | Author information (`name`, `email`, `url` fields) | `{"name": "Dev Team", "email": "dev@company.com"}` |
| `homepage` | string | Documentation URL | `"https://docs.example.com"` |
| `repository` | string | Source code URL | `"https://github.com/user/plugin"` |
| `license` | string | SPDX license identifier | `"MIT"`, `"Apache-2.0"` |
| `keywords` | array | Discovery tags | `["deployment", "ci-cd"]` |

### Component path fields

All paths **must be relative to the plugin root and start with `./`**. Custom paths for `commands`, `agents`, `skills`, and `outputStyles` replace the default directory — include the default in an array to keep it.

| Field | Type | Description | Example |
| :---- | :--- | :---------- | :------ |
| `commands` | string\|array | Command files/directories (replaces default `commands/`) | `"./custom/cmd.md"` or `["./cmd1.md"]` |
| `agents` | string\|array | Agent files/directories (replaces default `agents/`) | `"./custom/agents/reviewer.md"` |
| `skills` | string\|array | Skill directories (replaces default `skills/`) | `"./custom/skills/"` |
| `hooks` | string\|array\|object | Hook config paths or inline config | `"./hooks/hooks.json"` |
| `mcpServers` | string\|array\|object | MCP config paths or inline config | `"./mcp-config.json"` |
| `outputStyles` | string\|array | Output style files/directories (replaces default `output-styles/`) | `"./styles/"` |
| `lspServers` | string\|array\|object | LSP server configs for code intelligence | `"./.lsp.json"` |
| `userConfig` | object | User-configurable values prompted at enable time | See spec |
| `channels` | array | Channel declarations for message injection | See spec |

### userConfig

Declares values Claude Code prompts for when the plugin is enabled. Keys must be valid identifiers. Values available as `${user_config.KEY}` in configs and as `CLAUDE_PLUGIN_OPTION_<KEY>` env vars.

```json
{
  "userConfig": {
    "api_endpoint": {
      "description": "Your team's API endpoint",
      "sensitive": false
    },
    "api_token": {
      "description": "API authentication token",
      "sensitive": true
    }
  }
}
```

### Channels

Each channel binds to an MCP server. `server` is required and must match a key in the plugin's `mcpServers`.

```json
{
  "channels": [
    {
      "server": "telegram",
      "userConfig": {
        "bot_token": { "description": "Telegram bot token", "sensitive": true },
        "owner_id": { "description": "Your Telegram user ID", "sensitive": false }
      }
    }
  ]
}
```

---

**2. hooks.json Schema Compliance (25%)**

Hooks live at `hooks/hooks.json` (default) or are inlined in `plugin.json`. Validate configuration structure and values.

### Hook file structure

The top-level structure uses **event names as keys**, each mapping to an array of matcher groups. Each matcher group contains a `hooks` array of individual hook definitions:

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "optional-regex-pattern",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/example.sh"
          }
        ]
      }
    ]
  }
}
```

### Valid hook event types (26 total)

| Event | When it fires |
| :---- | :------------ |
| `SessionStart` | Session begins or resumes |
| `SessionEnd` | Session terminates |
| `UserPromptSubmit` | User submits a prompt, before Claude processes it |
| `InstructionsLoaded` | CLAUDE.md or `.claude/rules/*.md` files load |
| `ConfigChange` | Configuration file changes during a session |
| `PreToolUse` | Before a tool call executes (can block it) |
| `PostToolUse` | After a tool call succeeds |
| `PostToolUseFailure` | After a tool call fails |
| `PermissionRequest` | Permission dialog appears |
| `PermissionDenied` | Tool call denied by auto mode classifier |
| `PreCompact` | Before context compaction |
| `PostCompact` | After context compaction completes |
| `Notification` | Claude Code sends a notification |
| `SubagentStart` | Subagent is spawned |
| `SubagentStop` | Subagent finishes |
| `Stop` | Claude finishes responding |
| `StopFailure` | Turn ends due to API error |
| `TeammateIdle` | Agent team teammate goes idle |
| `TaskCreated` | Task created via TaskCreate |
| `TaskCompleted` | Task marked completed |
| `CwdChanged` | Working directory changes |
| `FileChanged` | Watched file changes on disk (`matcher` specifies filenames) |
| `WorktreeCreate` | Worktree created via `--worktree` or `isolation: "worktree"` |
| `WorktreeRemove` | Worktree removed |
| `Elicitation` | MCP server requests user input |
| `ElicitationResult` | User responds to MCP elicitation |

### Hook types and required fields

There are **4 valid hook types**: `command`, `http`, `prompt`, `agent`.

| Type | Required field | Optional fields |
| :--- | :------------- | :-------------- |
| `command` | `command` (path to executable) | `async` (boolean), `shell` (`"bash"` or `"powershell"`) |
| `http` | `url` (endpoint) | `headers` (object), `allowedEnvVars` (array) |
| `prompt` | `prompt` (LLM evaluation prompt; can use `$ARGUMENTS`) | `model` |
| `agent` | `prompt` (instructions for the subagent) | `model` |

**Common optional fields (all types):**

- `timeout` — optional, with defaults: 600s (command), 30s (prompt), 60s (agent)
- `statusMessage` — custom spinner message
- `if` — permission rule syntax filter (tool events only)
- `once` — run only once per session (skills only)

### Key validation rules

- Event names are **case-sensitive** (e.g., `PostToolUse`, not `postToolUse`)
- `type: "agent"` does **not** have an `agent` field — the subagent is defined by its `prompt` (and optional `model`)
- `type: "http"` does **not** have a `command` field — it uses `url`
- `matcher` field (if present) must contain valid regex syntax
- Plugin hook commands should reference scripts via `${CLAUDE_PLUGIN_ROOT}` for portability
- `timeout` is **not required** — sensible defaults are provided by the runtime

### Environment variables in hooks

Two substitution variables are available in hook commands, MCP/LSP configs, and content:

| Variable | Purpose |
| :------- | :------ |
| `${CLAUDE_PLUGIN_ROOT}` | Absolute path to plugin installation directory. Use for bundled scripts and configs. |
| `${CLAUDE_PLUGIN_DATA}` | Persistent directory for plugin state that survives updates. Use for caches, dependencies. |

---

**3. Agent File Schema Compliance (20%)**

Agent files live in the `agents/` directory as Markdown files with YAML frontmatter.

### Frontmatter fields

| Field | Required | Type | Rules |
| :---- | :------- | :--- | :---- |
| `name` | Yes | string | Valid identifier (lowercase, hyphens allowed, no spaces or special characters) |
| `description` | Yes | string | Non-empty. Describes what the agent specializes in and when Claude should invoke it |
| `model` | No | string | Valid values: `sonnet`, `opus`, `haiku` |
| `effort` | No | string | Valid values: `low`, `medium`, `high` |
| `maxTurns` | No | integer | Positive integer |
| `tools` | No | string\|array | Tools the agent can use |
| `disallowedTools` | No | string\|array | Tools the agent cannot use |
| `skills` | No | string\|array | Skills available to the agent |
| `memory` | No | boolean | Whether agent has memory |
| `background` | No | boolean | Whether agent runs in background |
| `isolation` | No | string | Only valid value: `"worktree"` |

**Not supported for plugin agents** (security restriction): `hooks`, `mcpServers`, `permissionMode`.

### Structure requirements

- Frontmatter is valid YAML between `---` delimiters
- Agent body content follows frontmatter (not just empty file)
- Body should contain a detailed system prompt describing role, expertise, and behavior

---

**4. Path and Reference Integrity (15%)**

Ensure all cross-references are valid:

- Agents listed/referenced in `plugin.json` match actual agent file names in the agents directory
- Commands listed/referenced in `plugin.json` match actual command files in the commands directory
- Hooks referencing scripts use `${CLAUDE_PLUGIN_ROOT}` for portability
- All relative paths in `plugin.json` start with `./`
- No broken references or missing files
- Components are at the **plugin root**, not inside `.claude-plugin/` (only `plugin.json` belongs there)
- No path traversal outside the plugin root (`../` references won't work after installation due to plugin caching)

---

**5. Structural Clarity and Best Practices (15%)**

Evaluate overall plugin structure quality:

- JSON files are properly formatted with consistent indentation
- Field ordering follows logical conventions (`name`, `version`, `description` at top of manifest)
- Agent descriptions are clear and actionable — they should convey when Claude should invoke the agent
- Hook event types match their intended use case (e.g., `PreToolUse` for intercepting tool calls, `PreCompact` for pre-compaction work, `SessionEnd` for cleanup)
- No duplicate agent names or command names within the plugin
- If timeouts are specified, values are reasonable for the hook's purpose
- Agent effort levels match the complexity described in their content
- Plugin uses `${CLAUDE_PLUGIN_ROOT}` (not `$PLUGIN_DIR` or hardcoded paths) for referencing bundled files
- Hook file structure uses the nested format (event names as keys with matcher groups)

## Scoring

Use this scale for overall assessment:

- **0.90-1.00 (Excellent)**: All schema requirements met, no validation errors, follows all conventions, paths correct, best practices applied
- **0.75-0.89 (Good)**: Minor issues such as suboptimal naming, missing optional metadata, or minor structural deviations, but all required fields present and valid
- **0.60-0.74 (Acceptable)**: Some schema violations or missing required fields in one file type, but plugin is mostly functional
- **0.40-0.59 (Needs Work)**: Multiple schema violations across file types, incorrect types or missing critical fields
- **0.00-0.39 (Unacceptable)**: Major schema violations, missing required files, invalid JSON/YAML, or broken references that prevent plugin from loading

## Feedback Guidance

When providing feedback, be specific and actionable:

- **For missing fields**: State which file and which required field is missing (e.g., "`agents/my-agent.md` frontmatter missing required `description` field")
- **For invalid values**: Specify the field, current value, and list of valid options (e.g., "`hooks.json`: `type` is `'script'` but must be one of: `command`, `http`, `prompt`, `agent`")
- **For path issues**: Identify the incorrect path and provide the corrected version (e.g., "`plugin.json` uses `agents/` but should be `./agents/`")
- **For hook structure**: Show the expected nested format if using a flat array
- **For regex errors**: Quote the invalid pattern and describe the syntax error
- **For naming conventions**: Show the current name and suggest a corrected version
- **For semver issues**: Explain what makes the version invalid (e.g., "version `'1.0'` missing patch number, should be `'1.0.0'`")
- **For environment variables**: Flag use of non-standard variables (e.g., `$PLUGIN_DIR` should be `${CLAUDE_PLUGIN_ROOT}`)

Prioritize issues by severity:

1. **Critical**: Missing required fields (`name` in manifest, `name`/`description` in agents), invalid JSON/YAML syntax, broken references, wrong hook structure format
2. **High**: Invalid enum values, incorrect path conventions (missing `./` prefix), wrong hook type fields (e.g., `agent` field on type `"agent"`), unsupported agent frontmatter fields (`hooks`, `mcpServers`, `permissionMode`)
3. **Medium**: Naming convention violations, missing recommended metadata (`version`, `description`), non-standard environment variables in hooks
4. **Low**: Formatting inconsistencies, suboptimal but valid configurations, missing optional metadata (`author`, `license`, `keywords`)
