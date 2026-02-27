/**
 * Dynamic UI tools — ad-hoc render/update/query/clear (no organism persistence).
 *
 * Adapted from Hera's dynamic-ui-tools.ts.
 * Uses SurfaceClient instead of NodeRegistry.
 */

import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { SurfaceClient } from "./surface-client.js";

/**
 * Register Dynamic UI tools on the MCP server.
 */
export function registerDynamicUITools(
  server: McpServer,
  surface: SurfaceClient,
): void {
  // dynamic_ui_render
  server.tool(
    "dynamic_ui_render",
    `Render custom HTML/CSS/JS interface on the Plasma Surface (ad-hoc, no organism persistence).

Activities: JSON array describing interactive elements in your HTML.
- Each activity has: id (element ID), type (button/input/canvas/custom), context (optional), dataProvider (optional JS expr)
- Activities auto-wire: clicks/changes send actions back to you
- dataProvider: JS expression evaluated at event time, result included as 'provided' in the action payload

Use cases: interactive forms, data visualizations (Three.js, D3, Chart.js), games, control panels.

IMPORTANT: Expose global state via window.app = {...} for incremental updates.`,
    {
      html: z.string().describe("HTML content"),
      css: z.string().optional().describe("CSS styles"),
      js: z.string().optional().describe("JavaScript code"),
      activities: z
        .array(
          z.object({
            id: z.string().describe("Element ID in HTML"),
            type: z.enum(["button", "input", "canvas", "custom"]).describe("Activity type"),
            context: z.any().optional().describe("Optional context metadata"),
            dataProvider: z.string().optional().describe("JS expression evaluated at event time"),
          }),
        )
        .describe("Interactive elements to wire up"),
    },
    async (args) => {
      try {
        if (!surface.isConnected()) {
          throw new Error("Plasma Surface not connected. Is plasma-surface running?");
        }

        await surface.render(args.html, args.css || "", args.js || "", args.activities);

        return {
          content: [
            {
              type: "text" as const,
              text: `Dynamic UI rendered on Plasma Surface.

Activities: ${args.activities.length}
${args.activities.map((a) => `- #${a.id} (${a.type})`).join("\n")}

User interactions will be sent back as actions.`,
            },
          ],
        };
      } catch (err) {
        return {
          content: [{ type: "text" as const, text: `Failed to render: ${err instanceof Error ? err.message : String(err)}` }],
          isError: true,
        };
      }
    },
  );

  // dynamic_ui_update
  server.tool(
    "dynamic_ui_update",
    `Send incremental JavaScript update to the Plasma Surface without reloading.

Maintains ALL existing state (Three.js scenes, timers, variables, canvas, etc.).
Use for small changes: color, position, add/remove element, update text.
Access state via window.app (or whatever was exposed in initial render).`,
    {
      js: z.string().describe("JavaScript code to execute (modifies existing state)"),
    },
    async (args) => {
      try {
        if (!surface.isConnected()) {
          throw new Error("Plasma Surface not connected. Is plasma-surface running?");
        }

        await surface.update(args.js);

        return {
          content: [{ type: "text" as const, text: "Dynamic UI updated (state preserved)." }],
        };
      } catch (err) {
        return {
          content: [{ type: "text" as const, text: `Failed to update: ${err instanceof Error ? err.message : String(err)}` }],
          isError: true,
        };
      }
    },
  );

  // dynamic_ui_query
  server.tool(
    "dynamic_ui_query",
    `Execute JavaScript in the Plasma Surface and return the result.

Use to read runtime state: form values, computed data, DOM state, etc.
The JS runs in the same context as the rendered content.

Examples:
- "document.getElementById('name').value"
- "({name: document.getElementById('name').value, email: document.getElementById('email').value})"
- "JSON.stringify(window.app.records)"`,
    {
      js: z.string().describe("JavaScript expression to evaluate. The result is returned."),
    },
    async (args) => {
      try {
        if (!surface.isConnected()) {
          throw new Error("Plasma Surface not connected. Is plasma-surface running?");
        }

        const result = await surface.query(args.js);
        const resultStr = typeof result === "string" ? result : JSON.stringify(result);

        return {
          content: [{ type: "text" as const, text: `Result: ${resultStr}` }],
        };
      } catch (err) {
        return {
          content: [{ type: "text" as const, text: `Query failed: ${err instanceof Error ? err.message : String(err)}` }],
          isError: true,
        };
      }
    },
  );

  // dynamic_ui_clear
  server.tool(
    "dynamic_ui_clear",
    "Clear the Plasma Surface content.",
    {},
    async () => {
      try {
        if (!surface.isConnected()) {
          throw new Error("Plasma Surface not connected. Is plasma-surface running?");
        }

        await surface.clear();

        return {
          content: [{ type: "text" as const, text: "Plasma Surface cleared." }],
        };
      } catch (err) {
        return {
          content: [{ type: "text" as const, text: `Failed to clear: ${err instanceof Error ? err.message : String(err)}` }],
          isError: true,
        };
      }
    },
  );

  // wait_for_ui_event
  server.tool(
    "wait_for_ui_event",
    `Block until a user interaction occurs on the Plasma Surface, then return the event data.

This tool suspends execution and waits for the user to interact with the rendered UI
(click a button, submit a form, change an input, etc.). When an action arrives, it
returns the full event payload including the element ID, event type, and any data
from the activity's dataProvider.

Use this to build reactive flows:
1. Render a UI with plasma_create or dynamic_ui_render
2. Call wait_for_ui_event to block until the user interacts
3. Process the returned data (validate, compute, call APIs)
4. Update the UI with dynamic_ui_update or plasma_mutate
5. Repeat from step 2 for continuous interaction loops

The tool times out after the specified number of seconds and returns an error.
Default timeout is 120 seconds.

Example flow:
  render form → wait_for_ui_event(120) → user clicks Submit →
  returns {activityId: "btn-submit", type: "click", provided: {name: "Lorenzo", email: "..."}} →
  you process the data → dynamic_ui_update to show result`,
    {
      timeout_seconds: z
        .number()
        .int()
        .min(1)
        .max(600)
        .default(120)
        .describe("Max seconds to wait for an event (1-600, default 120)"),
    },
    async (args) => {
      try {
        if (!surface.isConnected()) {
          throw new Error("Plasma Surface not connected. Is plasma-surface running?");
        }

        const action = await surface.waitForAction(args.timeout_seconds);

        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify(
                {
                  activityId: action.activityId,
                  type: action.type,
                  data: action.data || null,
                  context: action.context || null,
                },
                null,
                2,
              ),
            },
          ],
        };
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        if (msg.includes("Timeout")) {
          return {
            content: [{ type: "text" as const, text: "No UI event received within the timeout period." }],
          };
        }
        return {
          content: [{ type: "text" as const, text: `Failed to wait for event: ${msg}` }],
          isError: true,
        };
      }
    },
  );
}
