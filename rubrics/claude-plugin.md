# Claude Code Plugin Rubric

This rubric evaluates Claude Code plugin files for schema compliance, structural correctness, and adherence to plugin conventions. It covers three file types: `plugin.json`, `hooks.json`, and agent `.md` files.

## Criteria

**1. plugin.json Schema Compliance (25%)**

Verify all required fields and formatting rules:
- `name` field is present and follows namespacing conventions (lowercase, hyphen-separated, e.g., `my-plugin` or `namespace-plugin`)
- `version` field is present and uses valid semver format (e.g., `1.0.0`, `0.1.2`)
- `description` field is present and non-empty
- All paths reference files that should exist in the plugin directory structure
- Other metadata fields are as follows:

| Field |	Type |	Description |	Example |
| --- | --- | --- | --- |
| version |	string |	Semantic version. If also set in the marketplace entry, plugin.json takes priority. You only need to set it in one place. |	"2.1.0" |
| description |	string |	Brief explanation of plugin purpose |	"Deployment automation tools" |
| author	| object	| Author information	| `{"name": "Dev Team", "email": "dev@company.com"}` |
| homepage	| string	 | Documentation URL	| "https://docs.example.com" |
| repository |	string	| Source code URL |	"https://github.com/user/plugin" |
| license	| string	| License identifier |	"MIT", "Apache-2.0" |
| keywords	| array |	Discovery tags	| ["deployment", "ci-cd"] |

- Component fields are as follows:


| Field          | Type                  | Description                                                                                                                                               | Example                                |
| :------------- | :-------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------- |
| `commands`     | string\|array         | Custom command files/directories (replaces default `commands/`)                                                                                           | `"./custom/cmd.md"` or `["./cmd1.md"]` |
| `agents`       | string\|array         | Custom agent files (replaces default `agents/`)                                                                                                           | `"./custom/agents/reviewer.md"`        |
| `skills`       | string\|array         | Custom skill directories (replaces default `skills/`)                                                                                                     | `"./custom/skills/"`                   |
| `hooks`        | string\|array\|object | Hook config paths or inline config                                                                                                                        | `"./my-extra-hooks.json"`              |
| `mcpServers`   | string\|array\|object | MCP config paths or inline config                                                                                                                         | `"./my-extra-mcp-config.json"`         |
| `outputStyles` | string\|array         | Custom output style files/directories (replaces default `output-styles/`)                                                                                 | `"./styles/"`                          |
| `lspServers`   | string\|array\|object | [Language Server Protocol](https://microsoft.github.io/language-server-protocol/) configs for code intelligence (go to definition, find references, etc.) | `"./.lsp.json"`                        |
| `userConfig`   | object                | User-configurable values prompted at enable time.                                                           | See below                              |
| `channels`     | array                 | Channel declarations for message injection (Telegram, Slack, Discord style).                                                  | See below                              |

- User configuration
    - The `userConfig` field declares values that Claude Code prompts the user for when the plugin is enabled. Use this instead of requiring users to hand-edit `settings.json`:
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
- Channels
    - The `channels` field lets a plugin declare one or more message channels that inject content into the conversation. Each channel binds to an MCP server that the plugin provides.

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

   - The `server` field is required and must match a key in the plugin’s `mcpServers`. The optional per-channel `userConfig` uses the same schema as the top-level field, letting the plugin prompt for bot tokens or owner IDs when the plugin is enabled.



**2. hooks.json Schema Compliance (25%)**

Validate hook configuration structure and values:
- Each hook config contains required fields: `type` and `timeout`
- `type` field uses only valid values: `command`, `agent`, or `prompt`
- `type: "command"` requires `command` field (path to executable)
- `type: "agent"` requires `prompt` field (not an `agent` field)
- `type: "prompt"` requires `prompt` field
- Keys like `agent`, `background`, `url` are type-specific optional fields, not universally valid
- `matcher` field (if present) contains valid regex pattern syntax
- `timeout` field is a positive number
- `command` paths use `./` prefix for relative paths
- Valid hook event types are top-level keys under `hooks`: `PreToolUse`, `PostToolUse`, `SubagentStop`, `Notification`, `SessionStart`, `SessionStop`, `UserPromptSubmit`

**3. Agent File Schema Compliance (20%)**

Check agent markdown file frontmatter and structure:
- Frontmatter is present and valid YAML format
- Required fields `name` and `description` are present and non-empty
- `name` should be a valid identifier (lowercase, hyphen-separated allowed, no spaces or special characters)
- `model` field (if present) uses valid values: `sonnet`, `opus`, or `haiku`
- `effort` field (if present) uses valid values: `low`, `medium`, or `high`
- `maxTurns` field (if present) is a positive integer
- Frontmatter delimiter (`---`) is properly formatted
- Agent content follows frontmatter (not just empty file)

**4. Path and Reference Integrity (15%)**

Ensure all cross-references are valid:
- Agents listed in `plugin.json` match actual agent file names
- Commands listed in `plugin.json` match actual command file names
- Hooks referencing agents or commands use correct paths
- All relative paths consistently use `./` prefix convention
- No broken references or missing files
- Path separators are appropriate for the file system

**5. Structural Clarity and Best Practices (15%)**

Evaluate overall plugin structure quality:
- JSON files are properly formatted with consistent indentation
- Field ordering follows logical conventions (name, version, description at top)
- Agent descriptions are clear and actionable
- Hook event types match their intended use case (e.g., `PreToolUse` for tool interception)
- No duplicate agent names or command names within the plugin
- Timeout values are reasonable for the hook's purpose
- Agent effort levels match the complexity described in their content

## Scoring

Use this scale for overall assessment:

- **0.90-1.00 (Excellent)**: All schema requirements met, no validation errors, follows all conventions, paths are correct, best practices applied
- **0.75-0.89 (Good)**: Minor issues such as suboptimal naming or missing optional fields, but all required fields present and valid
- **0.60-0.74 (Acceptable)**: Some schema violations or missing required fields in one file type, but plugin is mostly functional
- **0.40-0.59 (Needs Work)**: Multiple schema violations across file types, incorrect types or missing critical fields
- **0.00-0.39 (Unacceptable)**: Major schema violations, missing required files, invalid JSON/YAML, or broken references that prevent plugin from loading

## Feedback Guidance

When providing feedback, be specific and actionable:

- **For missing fields**: State which file and which required field is missing (e.g., "`plugin.json` missing required `version` field")
- **For invalid values**: Specify the field, current value, and list of valid options (e.g., "`hooks.json` line 12: `type` is 'script' but must be one of: command, agent, prompt")
- **For path issues**: Identify the incorrect path and provide the corrected version (e.g., "agents array uses `agents/my-agent.md` but should be `./agents/my-agent.md`")
- **For regex errors**: Quote the invalid pattern and describe the syntax error
- **For naming conventions**: Show the current name and suggest a corrected version following conventions
- **For semver issues**: Explain what makes the version invalid (e.g., "version '1.0' missing patch number, should be '1.0.0'")

Prioritize issues by severity:
1. Critical: Missing required fields, invalid JSON/YAML syntax, broken references
2. High: Invalid enum values, incorrect path conventions, malformed regex
3. Medium: Naming convention violations, missing optional but recommended fields
4. Low: Formatting inconsistencies, suboptimal but valid configurations
