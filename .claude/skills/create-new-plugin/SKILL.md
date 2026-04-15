---
name: create-new-plugin
description: Create a new plugin for Onlooker with specified name and description. Use when user asks to "create a new plugin" "create plugin".
---

# Create New Plugin

## Instructions

Follow these steps to create a new plugin:

### 1. Validate Plugin Name

- Ensure the name is in kebab-case format (e.g., `my-plugin`)
- Check that `plugins/<plugin-name>` doesn't already exist
- Verify the name isn't already registered in `.claude-plugin/marketplace.json`

### 2. Create Directory Structure

Create the follow directory structure:

```txt
plugins/<plugin-name>/
├── .claude-plugin/
│   └── plugin.json
├── commands/           # Optional: slash commands
├── agents/             # Optional: custom agents
├── skills/             # Optional: agent skills
├── hooks/              # Optional: event hooks
├── src/                # Optional: MCP server source
├── .mcp.json           # Optional: MCP configuration
├── package.json        # Optional: if MCP server needed
├── tsconfig.json       # Optional: if MCP server needed
└── README.md
```

### Create plugin.json

Create `.claude-plugin/plugin.json` with:

```json
{
    "author": {
        "name": "onlooker-community"
    },
    "description": "<description>",
    "keywords": [],
    "license": "BlueOak-1.0.0",
    "name": "<plugin-name>",
    "version": "0.1.0"
}
```

### 4. Create README.md

Generate a README.md with:

```markdown
# <Plugin Name>

<description>

## Installation

\`\`\`bash
/plugin install <plugin-name>@onlooker-marketplace
\`\`\`

## Components

### Commands

(None yet)

### Skills

(None yet)

### Agents

(None yet)

### Hooks

(None yet)

### MCP Servers

(None yet)

## Usage

(Add usage examples here)

## Development

See [DEVELOPMENT.md](../../docs/DEVELOPMENT.md) for development guidelines.

## License

[Blue Oak Model License 1.0.0](../../LICENSE)
```

### 5. Register in Marketplace

Add an entry to `.claude-plugin/marketplace.json`:

```json
{
    "author": {
        "name": "onlooker-community"
    },
    "category": "<category>",
    "description": "<description>",
    "name": "<plugin-name>",
    "source": "./plugins/<plugin-name>",
    "strict": true,
    "tags": [],
    "version": "0.1.0"
}
```

**Important:**

- Add the entry alphabetically by name
- Choose appropriate category
- Add relevant tags based on functionality

### 6. Register in Release Pipeline

Add an entry to `.release-please-manifest.json`:

```json
{
    # ...
    "plugins/name": "0.1.0"
}
```

Add an entry to `release-plugin-config.json`, nested in `packages`

```json
{
    "packages":  {
        "plugins/<plugin-name>": {
            "component": "<plugin-name>",
            "extra-files": [
                {
                    "jsonpath": "$.version",
                    "path": ".claude-plugin/plugin.json",
                    "type": "json"
                }
            ],
            "initial-version": "0.1.0",
            "release-type": "simple"
        }
    }
}

```

### 7. Format Files

Run Biome to format all created files:

```bash
bun run check
```

### 8. Provide Next Steps

After creation, inform the user:

1. **Plugin created successfully at:** `plugins/<plugin-name>/`
2. **Next steps:**
   - Add components as needed (commands, skills, agents, hooks, or MCP server)
   - Update keywords in `plugin.json` and tags in `marketplace.json`
   - Choose appropriate category in `marketplace.json`
   - Fill in README.md with usage examples
   - Test locally: `/plugin marketplace add /path/to/claude-plugins`
   - Install and test: `/plugin install <plugin-name>@onlooker-marketplace`

## Best Practices

1. **Keep it simple** - Start with minimal functionality
2. **Document thoroughly** - Clear README with examples
3. **Test locally first** - Install from local marketplace before publishing
4. **Follow conventions** - Use kebab-case for all naming
5. **Format consistently** - Run `bun run format` before committing
6. **Version semantically** - Follow semver (1.0.0, 1.1.0, 2.0.0, etc.)

## Resources

- [Example Plugin](./references/example-plugin/README.md)
- [Claude Code Plugin Documentation](https://code.claude.com/docs/en/plugins)

## Troubleshooting

**Issue:** Plugin name validation fails

- **Solution:** Ensure name is kebab-case with only lowercase letters, numbers, and hyphens

**Issue:** Plugin already exists

- **Solution:** Choose a different name or remove existing plugin first

**Issue:** Marketplace registration fails

- **Solution:** Check JSON syntax in marketplace.json and ensure proper formatting