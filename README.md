# PLASMA

Dynamic UI system for Claude. Generate and control custom HTML/CSS/JS interfaces rendered on your Mac desktop — forms, dashboards, visualizations, games, anything.

This version includes **Plasma Viewer**, a lightweight macOS menubar app where Claude securely displays its creations. The viewer runs as a sandboxed native window on your machine — Claude sends HTML/CSS/JS over a localhost-only WebSocket, and the viewer renders it in real time. No browser needed, no external connections. You install it once, it sits quietly in your menubar, and whenever Claude builds something visual it appears right on your desktop.

Download the compiled app from [Releases](https://github.com/anthropics/plasma-claude/releases).

For full documentation visit **[helloclaude.org](https://helloclaude.org)**.

## Components

| Component | Description |
|-----------|-------------|
| **[plasma-surface](plasma-surface/)** | Native macOS menubar app (Swift/WKWebView) — renders the UI |
| **[plasma-connector](plasma-connector/)** | MCP server (Node.js) — bridges Claude to the Surface via WebSocket |
| **[plasma-plugin](plasma-plugin/)** | Claude Code plugin — skills and commands that teach Claude how to use PLASMA |

## Quick Start

### 1. Install Plasma Surface

Download `PlasmaSurface.app` from [Releases](https://github.com/anthropics/plasma-claude/releases) and move it to your Applications folder.

> Or build from source: `cd plasma-surface && swift build -c release`

### 2. Install the MCP server

Download `plasma-1.0.0.mcpb` from [Releases](https://github.com/anthropics/plasma-claude/releases) and drag it into Claude Desktop Settings.

### 3. Install the plugin (Claude Code)

```
/install anthropics/plasma-claude plasma-plugin
```

### 4. Go

```
/plasma:start
```

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

## License

Apache 2.0 — see [LICENSE](plasma-plugin/LICENSE).
