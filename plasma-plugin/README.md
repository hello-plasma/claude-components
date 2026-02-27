# PLASMA Plugin

Render custom HTML/CSS/JS interfaces on your desktop. Build interactive forms, dashboards, visualizations, and apps with event sourcing and live mutations. Use with [Claude Desktop](https://claude.ai/download) or install directly in Claude Code.

This plugin provides skills and commands for the PLASMA Dynamic UI system, which lets Claude generate and control fully custom web interfaces rendered in a native macOS window.

## Prerequisites

- **Plasma Surface** — Native macOS menubar app that renders the UI ([download](https://github.com/anthropics/plasma-claude/releases))
- **PLASMA MCPB** — MCP server bundle installed in Claude Desktop (`plasma-1.0.0.mcpb`)

## What's Included

### MCP Server (via MCPB)

> See [CONNECTORS.md](CONNECTORS.md) for details on how the plugin connects to the Plasma Surface.

| Component | What It Does | Category/Placeholder |
|-----------|-------------|---------------------|
| Plasma Surface | Native macOS menubar app rendering HTML/CSS/JS | `~~surface` |
| Plasma Connector | MCP server bridging Claude to the Surface via WebSocket | `~~connector` |

### Skill

#### PLASMA Dynamic UI
Complete guide for building interactive and display-only interfaces. Covers organism creation, event sourcing, activities, dataProviders, the `wait_for_ui_event` interaction loop, and design patterns.

### Commands

| Command | Description |
|---------|-------------|
| `/plasma:start` | Set up environment and check connection status |
| `/plasma:create <description>` | Create a new interactive UI app |
| `/plasma:load <name>` | Load a saved organism |
| `/plasma:list` | List all saved organisms |

## Getting Started

    # Install the plugin
    /install anthropics/plasma-claude plasma-plugin

    # Check your setup
    /plasma:start

    # Create your first app
    /plasma:create a customer entry form

## Common Workflows

**Interactive Form**
Create a form with input fields and a submit button. Claude waits for your input, processes the data, and updates the UI with results — all in a live feedback loop.

**Data Dashboard**
Build a dashboard with charts and metrics. Use external libraries (Chart.js, D3.js, Three.js) loaded from CDN.

**Multi-Record App**
Build an app where you accumulate records client-side (add customer, add item), then send them all to Claude at once for processing.

**Quick Visualization**
Render a one-off chart or 3D scene without persistence using `dynamic_ui_render`.

## Architecture

```
┌─────────────────────┐         ┌──────────────────────┐         ┌─────────────────────┐
│  Claude             │   MCP   │  plasma-connector    │   WS    │  plasma-surface     │
│  (Code/Desktop/     │◄───────►│  (MCPB, Node.js)     │◄───────►│  (Swift menubar)    │
│   Cowork)           │  stdio  │  Organism storage    │ :9420   │  Single WKWebView   │
└─────────────────────┘         └──────────────────────┘         └─────────────────────┘
                                         │
                                    ~/.plasma/organisms/
```

- **Plasma Surface** listens on `ws://localhost:9420` (localhost only)
- **Plasma Connector** (MCPB) connects as WS client when Claude starts it
- Protocol is Hera-compatible: `dynamic_ui`, `dynamic_ui_update`, `dynamic_ui_clear`, `command`/`command_result`
- Single window, no auth (localhost-only)

## Available Tools (via MCPB)

| Tool | Description |
|------|-------------|
| `plasma_create` | Create persistent organism with HTML/CSS/JS/activities |
| `plasma_mutate` | Apply incremental JS mutation to existing organism |
| `plasma_load` | Load saved organism and render on surface |
| `plasma_list` | List all saved organisms |
| `plasma_delete` | Delete an organism |
| `plasma_screenshot` | Capture PNG screenshot of the surface |
| `dynamic_ui_render` | Ad-hoc render (no persistence) |
| `dynamic_ui_update` | Incremental JS update without reload |
| `dynamic_ui_query` | Execute JS in surface, return result |
| `dynamic_ui_clear` | Clear the surface |
| `wait_for_ui_event` | Block until user interacts, return event data |

## License

Licensed under Apache 2.0. See [LICENSE](LICENSE).
