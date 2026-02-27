<p align="center">
  <img src="imgs/plasma-icon.png" width="200" alt="PLASMA">
</p>

# PLASMA

Dynamic UI system for Claude. Generate and control custom HTML/CSS/JS interfaces rendered on your Mac desktop — forms, dashboards, visualizations, games, anything.

This version includes **Plasma Viewer**, a lightweight macOS menubar app where Claude securely displays its creations. The viewer runs as a sandboxed native window on your machine — Claude sends HTML/CSS/JS over a localhost-only WebSocket, and the viewer renders it in real time. No browser needed, no external connections. You install it once, it sits quietly in your menubar, and whenever Claude builds something visual it appears right on your desktop.

Download the compiled app from [Releases](https://github.com/hello-plasma/claude-components/releases).

For full documentation visit **[helloclaude.org](https://helloclaude.org)**.

## Components

| Component | Description |
|-----------|-------------|
| **[plasma-surface](plasma-surface/)** | Native macOS menubar app (Swift/WKWebView) — renders the UI |
| **[plasma-connector](plasma-connector/)** | MCP server (Node.js) — bridges Claude to the Surface via WebSocket |
| **[plasma-plugin](plasma-plugin/)** | Claude Code plugin — skills and commands that teach Claude how to use PLASMA |

## Installation

### Step 1 — Install the Plasma Surface (macOS App)

The Surface is a lightweight menubar application for macOS.

1. Download the latest release from the [Plasma Surface releases page](https://github.com/hello-plasma/claude-components/releases).
2. Move the app to your Applications folder.
3. Launch it. You'll see a small icon appear in your macOS menu bar.

That's it — the Surface is now listening on `ws://localhost:9420` and waiting for content.

> **Note:** The Surface only accepts connections from localhost, so no network exposure is involved.
>
> Or build from source: `cd plasma-surface && swift build -c release`

### Step 2 — Install the MCPB Extension

The MCPB (MCP Bundle) is what gives Claude the actual tools to communicate with the Surface. Think of it as a bridge that Claude can talk through.

1. Locate the `plasma-1.0.0.mcpb` file (it comes with the [Plasma distribution](https://github.com/hello-plasma/claude-components/releases)).
2. Open **Claude Desktop**.
3. Go to **Settings**.
4. Look for the **MCP / Extensions** section.
5. Drag and drop the `.mcpb` file into the settings window — or use the "Add" button to browse and select it.

Claude Desktop will register the extension and make its tools available.

Once installed, Claude gains access to tools like `dynamic_ui_render`, `plasma_create`, `wait_for_ui_event`, and others — but it won't know the best way to use them yet. That's what the Plugin is for.

### Step 3 — Install the Plasma Plugin

The Plugin is a zip file that contains skills, commands, and best practices. It teaches Claude the optimal patterns for building interactive UIs with Plasma.

1. Download `plasma-plugin.zip` from the [releases page](https://github.com/hello-plasma/claude-components/releases).
2. Open **Claude Desktop**.
3. Go to **Settings**.
4. Look for the **Capabilities** section.
5. Click on **Skills** / go to **Customize**.
6. Click the **+** icon, then select **Upload Skill**.
7. Drag and drop the `.zip` file into the upload window.

Claude will add the plugin and its skills will be available immediately.

Once installed, you'll have access to these slash commands:

| Command | What it does |
|---------|-------------|
| `/plasma:start` | Check that everything is connected and ready |
| `/plasma:create` | Create a new interactive app |
| `/plasma:load` | Load a previously saved app |
| `/plasma:list` | See all your saved apps |

### Step 4 — Go

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
