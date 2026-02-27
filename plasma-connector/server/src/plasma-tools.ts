/**
 * PLASMA organism tools — create, mutate, load, list, delete.
 *
 * Adapted from Hera's plasma-client-tools.ts.
 * Uses SurfaceClient instead of NodeRegistry.
 */

import { z } from "zod";
import { readFileSync } from "node:fs";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { SurfaceClient } from "./surface-client.js";
import type { OrganismStorage } from "./organism-storage.js";

/**
 * Safety net for LLM-generated tool calls: parse JSON strings back to arrays.
 */
function safeJsonArray<T extends z.ZodTypeAny>(schema: T) {
  return z.preprocess((val) => {
    if (typeof val === "string") {
      try {
        return JSON.parse(val);
      } catch {
        return val;
      }
    }
    return val;
  }, schema);
}

/**
 * Register all PLASMA organism tools on the MCP server.
 */
export function registerPlasmaTools(
  server: McpServer,
  storage: OrganismStorage,
  surface: SurfaceClient,
): void {
  // plasma_create
  server.tool(
    "plasma_create",
    `Create a new PLASMA organism (UI application).

An organism is a complete UI app with event sourcing:
- main.code: Initial version (HTML/CSS/JS/activities in YAML format)
- Mutations: Incremental updates (JavaScript only)
- Snapshots: Automatic every 20 mutations for fast loading

Naming convention: a-zA-Z0-9_ only, max 4 words, descriptive.
Examples: customer_form, sales_dashboard, task_manager

The organism is saved and immediately rendered on the Plasma Surface.`,
    {
      name: z.string().describe("Organism name (a-zA-Z0-9_ only, max 4 words, descriptive)"),
      description: z.string().describe("Description of what this organism does"),
      html: z.string().describe("HTML content"),
      css: z.string().optional().describe("CSS styles"),
      js: z.string().optional().describe("JavaScript code"),
      activities: safeJsonArray(
        z.array(
          z.object({
            id: z.string(),
            type: z.enum(["button", "input", "canvas", "custom"]),
            context: z.any().optional(),
            dataProvider: z
              .string()
              .optional()
              .describe("JS expression evaluated at event time. Result included as 'provided' in the action payload."),
          }),
        ),
      ).describe("Interactive elements"),
      tags: safeJsonArray(z.array(z.string())).optional().describe("Tags for categorization"),
    },
    async (args) => {
      try {
        storage.create(
          args.name,
          args.description,
          args.html,
          args.css,
          args.js,
          args.activities,
          args.tags,
        );

        // Render immediately on surface
        if (surface.isConnected()) {
          await surface.render(
            args.html,
            args.css || "",
            args.js || "",
            args.activities,
          );
        }

        return {
          content: [
            {
              type: "text" as const,
              text: `Organism '${args.name}' created successfully.

Saved to: ~/.plasma/organisms/${args.name}/
Activities: ${args.activities.length}
${args.activities.map((a: { id: string; type: string }) => `- #${a.id} (${a.type})`).join("\n")}
${surface.isConnected() ? "\nRendered on Plasma Surface." : "\nPlasma Surface not connected — organism saved but not rendered."}`,
            },
          ],
        };
      } catch (err) {
        return {
          content: [{ type: "text" as const, text: `Failed to create organism: ${err instanceof Error ? err.message : String(err)}` }],
          isError: true,
        };
      }
    },
  );

  // plasma_mutate
  server.tool(
    "plasma_mutate",
    `Apply an incremental mutation to an existing organism.

Mutations are JavaScript-only updates that modify the existing app.
Each mutation is saved as N_[descriptive_name].code.
The mutation is immediately applied to the active surface.`,
    {
      name: z.string().describe("Organism name"),
      mutation_name: z
        .string()
        .regex(/^[a-zA-Z0-9_]+$/)
        .describe("Descriptive name for this mutation (a-zA-Z0-9_ only)"),
      js: z.string().describe("JavaScript code for the mutation"),
    },
    async (args) => {
      try {
        const newNum = storage.mutate(args.name, args.mutation_name, args.js);

        // Apply immediately to surface
        if (surface.isConnected()) {
          await surface.update(args.js);
        }

        return {
          content: [
            {
              type: "text" as const,
              text: `Mutation applied to '${args.name}': ${newNum}_${args.mutation_name}.code
Total mutations: ${newNum}
${newNum % 20 === 0 ? `Snapshot created (snapshot_${newNum}.code)` : ""}
${surface.isConnected() ? "Applied to Plasma Surface." : "Saved but surface not connected."}`,
            },
          ],
        };
      } catch (err) {
        return {
          content: [{ type: "text" as const, text: `Failed to apply mutation: ${err instanceof Error ? err.message : String(err)}` }],
          isError: true,
        };
      }
    },
  );

  // plasma_load
  server.tool(
    "plasma_load",
    `Load a saved PLASMA organism and render it on the Plasma Surface.

Loads with smart snapshot support for fast loading, then applies remaining mutations.`,
    {
      name: z.string().describe("Organism name to load"),
    },
    async (args) => {
      try {
        if (!surface.isConnected()) {
          throw new Error("Plasma Surface not connected. Is plasma-surface running?");
        }

        const { code, mutations, fromSnapshot } = storage.load(args.name);
        const manifest = storage.readManifest(args.name);

        // Render base code
        await surface.render(code.html, code.css || "", code.js || "", code.activities);

        // Apply remaining mutations with a small delay
        if (mutations.length > 0) {
          await new Promise((resolve) => setTimeout(resolve, 100));
          for (const mutation of mutations) {
            const mutationJs = readFileSync(mutation.path, "utf-8");
            await surface.update(mutationJs);
          }
        }

        return {
          content: [
            {
              type: "text" as const,
              text: `Organism '${manifest?.name || args.name}' loaded and rendered.

${fromSnapshot > 0 ? `Loaded from: snapshot_${fromSnapshot}.code` : "Loaded from: main.code"}
${mutations.length > 0 ? `Applied ${mutations.length} additional mutations` : ""}
Activities: ${code.activities.length}`,
            },
          ],
        };
      } catch (err) {
        return {
          content: [{ type: "text" as const, text: `Failed to load organism: ${err instanceof Error ? err.message : String(err)}` }],
          isError: true,
        };
      }
    },
  );

  // plasma_list
  server.tool("plasma_list", "List all saved PLASMA organisms with their metadata.", {}, async () => {
    const organisms = storage.list();

    if (organisms.length === 0) {
      return {
        content: [{ type: "text" as const, text: "No organisms saved yet. Use plasma_create to create your first organism." }],
      };
    }

    const list = organisms
      .map((o) => {
        const tags = o.tags.length > 0 ? ` [${o.tags.join(", ")}]` : "";
        return `- ${o.name} — ${o.mutations} mutations${tags}\n  ${o.description}`;
      })
      .join("\n\n");

    return {
      content: [{ type: "text" as const, text: `${organisms.length} organism(s) available:\n\n${list}` }],
    };
  });

  // plasma_delete
  server.tool(
    "plasma_delete",
    "Delete a PLASMA organism permanently.",
    {
      name: z.string().describe("Organism name to delete"),
    },
    async (args) => {
      try {
        storage.delete(args.name);
        return {
          content: [{ type: "text" as const, text: `Organism '${args.name}' deleted permanently.` }],
        };
      } catch (err) {
        return {
          content: [{ type: "text" as const, text: `Failed to delete organism: ${err instanceof Error ? err.message : String(err)}` }],
          isError: true,
        };
      }
    },
  );

  // plasma_screenshot
  server.tool(
    "plasma_screenshot",
    `Capture a screenshot of the Plasma Surface.

Returns the screenshot as a PNG image that you can see directly.
Use this to verify visual rendering, debug layout issues, or confirm styling changes.`,
    {},
    async () => {
      try {
        if (!surface.isConnected()) {
          throw new Error("Plasma Surface not connected. Is plasma-surface running?");
        }

        const { image, mimeType } = await surface.screenshot();

        // Save to disk
        const { join } = await import("node:path");
        const { existsSync, mkdirSync, writeFileSync } = await import("node:fs");
        const screenshotsDir = join(
          process.env.PLASMA_ROOT || `${process.env.HOME}/.plasma`,
          "screenshots",
        );
        if (!existsSync(screenshotsDir)) mkdirSync(screenshotsDir, { recursive: true });
        const filename = `screenshot_${Date.now()}.png`;
        const filePath = join(screenshotsDir, filename);
        writeFileSync(filePath, Buffer.from(image, "base64"));

        return {
          content: [
            {
              type: "image" as const,
              data: image,
              mimeType,
            },
            {
              type: "text" as const,
              text: `Screenshot saved: ${filePath}`,
            },
          ],
        };
      } catch (err) {
        return {
          content: [{ type: "text" as const, text: `Screenshot failed: ${err instanceof Error ? err.message : String(err)}` }],
          isError: true,
        };
      }
    },
  );
}
