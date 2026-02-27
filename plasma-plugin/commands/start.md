---
description: Set up your PLASMA environment and check connection status
---

# PLASMA Start

> If you need to check which components are connected, see [CONNECTORS.md](../CONNECTORS.md).

You are helping a user get oriented with the PLASMA Dynamic UI plugin. Walk through the following steps in order.

## Step 1: Welcome

Display this welcome message:

    PLASMA Dynamic UI

    Build custom interactive interfaces rendered on your desktop.
    Forms, dashboards, visualizations, games — anything you can
    build with HTML/CSS/JS, controlled by Claude.

## Step 2: Check Connection Status

Test whether the Plasma Surface is reachable by trying to use a tool:

1. Call `plasma_list` to verify the MCP server (MCPB) is running.
2. If it fails, tell the user: "The PLASMA MCP server is not running. Make sure the `plasma-1.0.0.mcpb` is installed in Claude Desktop Settings."

3. Call `dynamic_ui_query` with `js: "document.title || 'connected'"` to verify the Surface app is reachable.
4. If it fails with "Not connected", tell the user: "Plasma Surface is not running. Launch it from your Applications or run: `open /path/to/PlasmaSurface.app`"

Report status:

    Status:
    - MCP Server (MCPB):  Connected / Not installed
    - Plasma Surface:     Connected / Not running

## Step 3: Show Available Tools

List the tools available:

| Tool | What It Does |
|------|-------------|
| `plasma_create` | Create a persistent UI app (organism) |
| `plasma_mutate` | Apply incremental changes to an existing app |
| `plasma_load` | Load a saved app and display it |
| `plasma_list` | List all saved apps |
| `plasma_delete` | Delete a saved app |
| `plasma_screenshot` | Take a screenshot of the current display |
| `dynamic_ui_render` | Render a quick one-off UI (not saved) |
| `dynamic_ui_update` | Update the current UI without reloading |
| `dynamic_ui_query` | Read values from the current UI |
| `wait_for_ui_event` | Wait for user interaction (click, input) |

## Step 4: Show Saved Organisms

Call `plasma_list` and show any existing organisms. If none exist, say:

    No saved apps yet. Ask me to create one!

## Step 5: Ask How to Help

Ask the user what they'd like to build. Suggest starting points:

1. **Interactive form** — "Create a form to collect customer data"
2. **Dashboard** — "Build a metrics dashboard with charts"
3. **Calculator or tool** — "Make a unit converter"
4. **Data visualization** — "Show a 3D rotating cube with Three.js"
5. **Load existing app** — "Open one of my saved apps"

Wait for the user's response and guide them accordingly.
