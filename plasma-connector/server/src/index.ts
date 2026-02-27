#!/usr/bin/env node

/**
 * PLASMA Connector — MCP Server for Claude Code/Desktop/Cowork.
 *
 * Connects to plasma-surface via WebSocket and exposes PLASMA tools
 * through the standard MCP protocol (stdio transport).
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { SurfaceClient } from "./surface-client.js";
import { OrganismStorage } from "./organism-storage.js";
import { registerPlasmaTools } from "./plasma-tools.js";
import { registerDynamicUITools } from "./dynamic-ui-tools.js";

const PLASMA_ROOT = process.env.PLASMA_ROOT || `${process.env.HOME}/.plasma`;
const SURFACE_URL = process.env.PLASMA_SURFACE_URL || "ws://localhost:9420";

async function main() {
  console.error("[PlasmaConnector] Starting...");
  console.error(`[PlasmaConnector] Plasma root: ${PLASMA_ROOT}`);
  console.error(`[PlasmaConnector] Surface URL: ${SURFACE_URL}`);

  // Initialize storage
  const storage = new OrganismStorage(PLASMA_ROOT);

  // Initialize surface client
  const surface = new SurfaceClient(SURFACE_URL);

  // Connect to surface (non-blocking — will auto-reconnect)
  await surface.connect();

  // Handle actions from the surface
  surface.onAction((action) => {
    // Log actions for now — in a full implementation these would be
    // forwarded as notifications or resource updates
    console.error(
      `[PlasmaConnector] Action received: ${action.type} on #${action.activityId}`,
      action.data ? JSON.stringify(action.data) : "",
    );
  });

  // Create MCP server
  const server = new McpServer({
    name: "plasma",
    version: "1.0.0",
  });

  // Register all tools
  registerPlasmaTools(server, storage, surface);
  registerDynamicUITools(server, surface);

  // Start stdio transport
  const transport = new StdioServerTransport();
  await server.connect(transport);

  console.error("[PlasmaConnector] MCP server running on stdio");

  // Handle shutdown
  process.on("SIGINT", () => {
    console.error("[PlasmaConnector] Shutting down...");
    surface.disconnect();
    process.exit(0);
  });

  process.on("SIGTERM", () => {
    console.error("[PlasmaConnector] Shutting down...");
    surface.disconnect();
    process.exit(0);
  });
}

main().catch((err) => {
  console.error("[PlasmaConnector] Fatal error:", err);
  process.exit(1);
});
