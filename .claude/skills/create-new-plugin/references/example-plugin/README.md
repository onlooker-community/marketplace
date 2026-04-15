# Example Plugin

Example demonstrating all plugin features.

## Features

### Skills

- **example-skill**: Demonstrates skill structure with progressive disclosure

### Commands

- `/example-plugin:hello`: Simple greeting command with arguments
- `/example-plugin:analyze`: Example analysis command

### Agents

- **example-agent**: Custom subagent demonstrating specialized capabilities

### Hooks

- **SessionStart**: Logs session initialization
- **PostToolUse**: Example post-tool processing

### MCP Server

- **example-mcp**: TypeScript-based MCP server with example tools

## Installation

From marketplace:

```txt
/plugin install example-plugin@onlooker-marketplace
```

## Usage

### Using the Skill

The skill is automatically invoked when relevant. Try asking about example patterns.

### Using Commands

```txt
/example-plugin:hello World
/example-plugin:analyze path/to/your/file
```

### Using the Agent

The agent can be invoked via the Task tool when appropriate, or manually:

```txt
/agent example-agent
```

### Using the MCP Server

The MCP server provides additional tools that appear prefixed with `mcp__example-mcp__*`.

## Development

### Setup

```bash
cd plugins/example-plugin
bun install
bun run build
```

### Testing

```bash
bun test
```