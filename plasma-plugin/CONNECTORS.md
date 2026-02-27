# Connectors

## How tool references work

Plugin files use `~~category` as a placeholder for whatever tool the user connects in that category. For example, `~~surface` refers to the Plasma Surface app running on the user's machine.

Plugins are **tool-agnostic** — they describe workflows in terms of categories rather than specific products. The MCPB pre-configures the Plasma Connector MCP server, but the Surface app must be running separately.

## Connectors for this plugin

| Category | Placeholder | Provided by | Required |
|----------|-------------|-------------|----------|
| Surface renderer | `~~surface` | Plasma Surface (macOS menubar app) | Yes |
| MCP server | `~~connector` | Plasma Connector (MCPB bundle) | Yes |
| Organism storage | `~~storage` | `~/.plasma/organisms/` (local filesystem) | Auto-created |

## Setup

1. **Install Plasma Surface** — Download and run the macOS menubar app. It listens on `ws://localhost:9420`.
2. **Install MCPB** — Drag `plasma-1.0.0.mcpb` into Claude Desktop Settings. This installs the MCP server that provides all PLASMA tools.
3. **Install this plugin** — Provides skills and commands that teach Claude how to use the tools effectively.

## How they connect

```
Claude Desktop
  └── MCPB (plasma-connector) ← MCP stdio transport
        └── WebSocket client → ws://localhost:9420
              └── Plasma Surface (macOS app) ← renders HTML/CSS/JS
```

The MCPB provides the tools. The plugin provides the intelligence. The Surface provides the rendering.
