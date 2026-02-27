/**
 * OrganismStorage — file I/O for PLASMA organisms.
 *
 * Extracted from Hera's plasma-client-tools.ts, standalone with no external deps.
 * Handles event-sourced organism lifecycle: create, mutate, load, list, delete.
 */

import { join } from "node:path";
import {
  existsSync,
  readdirSync,
  readFileSync,
  writeFileSync,
  mkdirSync,
  rmSync,
} from "node:fs";
import type { OrganismManifest, MainCode, MutationFile, Activity } from "./types.js";

const SNAPSHOT_INTERVAL = 20;

/**
 * Validate BASIC naming convention: a-zA-Z0-9_ only, max 4 words.
 */
export function validateOrganismName(name: string): void {
  if (!/^[a-zA-Z0-9_]+$/.test(name)) {
    throw new Error("Organism name must contain only a-zA-Z0-9_ characters (BASIC convention)");
  }
  const words = name.split("_");
  if (words.length > 4) {
    throw new Error("Organism name must be max 4 words separated by underscores");
  }
}

/**
 * Parse main.code YAML structure.
 */
export function parseMainCode(content: string): MainCode {
  const lines = content.split("\n");
  let currentSection: string | null = null;
  let sectionContent: string[] = [];
  const sections: Record<string, string> = {};

  for (const line of lines) {
    if (line.startsWith("---")) {
      if (currentSection) {
        sections[currentSection] = sectionContent.join("\n").trim();
      }
      currentSection = null;
      sectionContent = [];
    } else if (line.match(/^(html|css|js|activities):\s*\|?$/)) {
      if (currentSection) {
        sections[currentSection] = sectionContent.join("\n").trim();
      }
      currentSection = line.split(":")[0];
      sectionContent = [];
    } else if (currentSection) {
      sectionContent.push(line.replace(/^  /, ""));
    }
  }

  if (currentSection) {
    sections[currentSection] = sectionContent.join("\n").trim();
  }

  // Parse activities
  let activities: Activity[] = [];
  if (sections.activities) {
    try {
      const items = sections.activities.split(/^(?=- )/m).filter(Boolean);
      activities = items
        .map((item: string) => {
          const activity: Record<string, unknown> = {};
          const idMatch = item.match(/id:\s*(.+)/);
          const typeMatch = item.match(/type:\s*(.+)/);
          const contextMatch = item.match(/context:\s*(.+)/);
          const dataProviderMatch = item.match(/dataProvider:\s*(.+)/);
          if (idMatch) activity.id = idMatch[1].trim();
          if (typeMatch) activity.type = typeMatch[1].trim();
          if (contextMatch) {
            try {
              activity.context = JSON.parse(contextMatch[1].trim());
            } catch {
              /* skip */
            }
          }
          if (dataProviderMatch) activity.dataProvider = dataProviderMatch[1].trim();
          return activity;
        })
        .filter((a): a is Record<string, unknown> & { id: string; type: string } => !!(a.id && a.type)) as unknown as Activity[];
    } catch {
      try {
        activities = JSON.parse(sections.activities);
      } catch {
        activities = [];
      }
    }
  }

  return {
    html: sections.html || "",
    css: sections.css,
    js: sections.js,
    activities,
  };
}

/**
 * Serialize main.code to YAML format.
 */
export function serializeMainCode(code: MainCode): string {
  const activitiesYaml = code.activities
    .map((a) => {
      let yaml = `  - id: ${a.id}\n    type: ${a.type}`;
      if (a.context) {
        yaml += `\n    context: ${JSON.stringify(a.context)}`;
      }
      if (a.dataProvider) {
        yaml += `\n    dataProvider: ${a.dataProvider}`;
      }
      return yaml;
    })
    .join("\n");

  return `---
activities:
${activitiesYaml}
---
html: |
  ${code.html.split("\n").join("\n  ")}

${code.css ? `css: |\n  ${code.css.split("\n").join("\n  ")}\n` : ""}
${code.js ? `js: |\n  ${code.js.split("\n").join("\n  ")}` : ""}
`.trim();
}

/**
 * OrganismStorage manages the organisms directory on disk.
 */
export class OrganismStorage {
  private organismsDir: string;

  constructor(plasmaRoot: string) {
    this.organismsDir = join(plasmaRoot, "organisms");
    if (!existsSync(this.organismsDir)) {
      mkdirSync(this.organismsDir, { recursive: true });
    }
  }

  /** Get the path to an organism directory. */
  organismPath(name: string): string {
    return join(this.organismsDir, name);
  }

  /** Check if an organism exists. */
  exists(name: string): boolean {
    return existsSync(this.organismPath(name));
  }

  /** Create a new organism. */
  create(
    name: string,
    description: string,
    html: string,
    css?: string,
    js?: string,
    activities: Activity[] = [],
    tags?: string[],
  ): void {
    validateOrganismName(name);

    const orgPath = this.organismPath(name);
    if (existsSync(orgPath)) {
      throw new Error(`Organism '${name}' already exists. Use plasma_mutate to update it.`);
    }

    mkdirSync(orgPath, { recursive: true });

    // Create manifest
    const manifest: OrganismManifest = {
      name,
      description,
      created: new Date().toISOString(),
      updated: new Date().toISOString(),
      mutations: 0,
      tags: tags || [],
    };

    const manifestContent = `---
name: ${manifest.name}
description: ${manifest.description}
created: ${manifest.created}
updated: ${manifest.updated}
mutations: ${manifest.mutations}
${manifest.tags && manifest.tags.length > 0 ? `tags: [${manifest.tags.join(", ")}]` : ""}
---
`;
    writeFileSync(join(orgPath, "manifest.yaml"), manifestContent, "utf-8");

    // Create main.code
    const mainCode: MainCode = { html, css, js, activities };
    writeFileSync(join(orgPath, "main.code"), serializeMainCode(mainCode), "utf-8");
  }

  /** Apply a mutation to an organism. Returns the mutation number. */
  mutate(name: string, mutationName: string, js: string): number {
    const orgPath = this.organismPath(name);
    if (!existsSync(orgPath)) {
      throw new Error(`Organism '${name}' not found. Use plasma_list to see available organisms.`);
    }

    // Read manifest
    const manifestPath = join(orgPath, "manifest.yaml");
    const manifestContent = readFileSync(manifestPath, "utf-8");
    const manifestMatch = manifestContent.match(/mutations:\s*(\d+)/);
    const currentMutations = manifestMatch ? parseInt(manifestMatch[1], 10) : 0;

    const newMutationNum = currentMutations + 1;
    const mutationFileName = `${newMutationNum}_${mutationName}.code`;

    // Write mutation file
    writeFileSync(join(orgPath, mutationFileName), js, "utf-8");

    // Update manifest
    const updatedManifest = manifestContent
      .replace(/updated:.*/, `updated: ${new Date().toISOString()}`)
      .replace(/mutations:\s*\d+/, `mutations: ${newMutationNum}`);
    writeFileSync(manifestPath, updatedManifest, "utf-8");

    // Create snapshot if needed
    if (newMutationNum % SNAPSHOT_INTERVAL === 0) {
      this.createSnapshot(orgPath, newMutationNum);
    }

    return newMutationNum;
  }

  /** Load an organism, returning the base code and remaining mutations. */
  load(name: string): { code: MainCode; mutations: MutationFile[]; fromSnapshot: number } {
    const orgPath = this.organismPath(name);
    if (!existsSync(orgPath)) {
      throw new Error(`Organism '${name}' not found. Use plasma_list to see available organisms.`);
    }

    const mutations = this.getMutationFiles(orgPath);
    const snapshotPath = this.findBestSnapshot(orgPath, mutations);

    let baseCode: MainCode;
    let startMutation = 0;

    if (snapshotPath && existsSync(snapshotPath)) {
      const snapshotContent = readFileSync(snapshotPath, "utf-8");
      const snapshotMatch = snapshotPath.match(/snapshot_(\d+)\.code$/);
      startMutation = snapshotMatch ? parseInt(snapshotMatch[1], 10) : 0;

      const mainCodeMatch = snapshotContent.match(/=== main\.code ===\n([\s\S]+?)(?:\n\/\/ ===|$)/);
      if (mainCodeMatch) {
        baseCode = parseMainCode(mainCodeMatch[1]);
      } else {
        throw new Error("Failed to parse snapshot");
      }
    } else {
      const mainCodePath = join(orgPath, "main.code");
      const mainCodeContent = readFileSync(mainCodePath, "utf-8");
      baseCode = parseMainCode(mainCodeContent);
    }

    // Load state if exists
    const statePath = join(orgPath, "state.json");
    if (existsSync(statePath)) {
      const state = JSON.parse(readFileSync(statePath, "utf-8"));
      baseCode.js = `window.__initialState = ${JSON.stringify(state)};\n\n${baseCode.js || ""}`;
    }

    const remainingMutations = mutations.filter((m) => m.num > startMutation);

    return { code: baseCode, mutations: remainingMutations, fromSnapshot: startMutation };
  }

  /** List all organisms. */
  list(): Array<{ name: string; description: string; mutations: number; tags: string[] }> {
    if (!existsSync(this.organismsDir)) return [];

    const dirs = readdirSync(this.organismsDir, { withFileTypes: true })
      .filter((d) => d.isDirectory() && !d.name.startsWith("."))
      .map((d) => d.name);

    return dirs
      .map((name) => {
        try {
          const manifestPath = join(this.organismsDir, name, "manifest.yaml");
          if (!existsSync(manifestPath)) return null;

          const content = readFileSync(manifestPath, "utf-8");
          const descMatch = content.match(/description:\s*(.+)/);
          const mutationsMatch = content.match(/mutations:\s*(\d+)/);
          const tagsMatch = content.match(/tags:\s*\[(.+)\]/);

          return {
            name,
            description: descMatch ? descMatch[1].trim() : "No description",
            mutations: mutationsMatch ? parseInt(mutationsMatch[1], 10) : 0,
            tags: tagsMatch ? tagsMatch[1].split(",").map((t) => t.trim()) : [],
          };
        } catch {
          return null;
        }
      })
      .filter((o): o is NonNullable<typeof o> => o !== null);
  }

  /** Delete an organism. */
  delete(name: string): void {
    const orgPath = this.organismPath(name);
    if (!existsSync(orgPath)) {
      throw new Error(`Organism '${name}' not found`);
    }
    rmSync(orgPath, { recursive: true, force: true });
  }

  /** Read manifest for an organism. */
  readManifest(name: string): OrganismManifest | null {
    const manifestPath = join(this.organismPath(name), "manifest.yaml");
    if (!existsSync(manifestPath)) return null;

    const content = readFileSync(manifestPath, "utf-8");
    const nameMatch = content.match(/name:\s*(.+)/);
    const descMatch = content.match(/description:\s*(.+)/);
    const mutationsMatch = content.match(/mutations:\s*(\d+)/);
    const tagsMatch = content.match(/tags:\s*\[(.+)\]/);
    const createdMatch = content.match(/created:\s*(.+)/);
    const updatedMatch = content.match(/updated:\s*(.+)/);

    return {
      name: nameMatch ? nameMatch[1].trim() : name,
      description: descMatch ? descMatch[1].trim() : "",
      created: createdMatch ? createdMatch[1].trim() : "",
      updated: updatedMatch ? updatedMatch[1].trim() : "",
      mutations: mutationsMatch ? parseInt(mutationsMatch[1], 10) : 0,
      tags: tagsMatch ? tagsMatch[1].split(",").map((t) => t.trim()) : [],
    };
  }

  // Private helpers

  private getMutationFiles(orgPath: string): MutationFile[] {
    if (!existsSync(orgPath)) return [];
    const files = readdirSync(orgPath);
    const mutations: MutationFile[] = [];

    for (const file of files) {
      const match = file.match(/^(\d+)_(.+)\.code$/);
      if (match) {
        mutations.push({
          num: parseInt(match[1], 10),
          name: match[2],
          path: join(orgPath, file),
        });
      }
    }

    return mutations.sort((a, b) => a.num - b.num);
  }

  private findBestSnapshot(orgPath: string, mutations: MutationFile[]): string | null {
    if (!existsSync(orgPath)) return null;
    const files = readdirSync(orgPath);
    const snapshots: number[] = [];

    for (const file of files) {
      const match = file.match(/^snapshot_(\d+)\.code$/);
      if (match) {
        snapshots.push(parseInt(match[1], 10));
      }
    }

    if (snapshots.length === 0) return null;

    const maxMutation = mutations.length > 0 ? mutations[mutations.length - 1].num : 0;
    const validSnapshots = snapshots.filter((s) => s <= maxMutation);
    if (validSnapshots.length === 0) return null;

    const bestSnapshot = Math.max(...validSnapshots);
    return join(orgPath, `snapshot_${bestSnapshot}.code`);
  }

  private createSnapshot(orgPath: string, upToMutation: number): void {
    const mainCodePath = join(orgPath, "main.code");
    if (!existsSync(mainCodePath)) return;

    const mutations = this.getMutationFiles(orgPath).filter((m) => m.num <= upToMutation);

    let snapshotContent = `// Snapshot at mutation ${upToMutation}\n// Auto-generated: ${new Date().toISOString()}\n\n`;
    snapshotContent += `// === main.code ===\n${readFileSync(mainCodePath, "utf-8")}\n\n`;

    for (const mutation of mutations) {
      snapshotContent += `// === ${mutation.num}_${mutation.name}.code ===\n`;
      snapshotContent += readFileSync(mutation.path, "utf-8") + "\n\n";
    }

    writeFileSync(join(orgPath, `snapshot_${upToMutation}.code`), snapshotContent, "utf-8");
    console.error(`[OrganismStorage] Created snapshot at mutation ${upToMutation}`);
  }
}
