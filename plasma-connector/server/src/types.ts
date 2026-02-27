/**
 * PLASMA shared types for the connector.
 */

/** Activity definition for interactive elements in the UI. */
export interface Activity {
  id: string;
  type: "button" | "input" | "canvas" | "custom";
  context?: Record<string, unknown>;
  dataProvider?: string;
}

/** Organism manifest metadata. */
export interface OrganismManifest {
  name: string;
  description: string;
  created: string;
  updated: string;
  mutations: number;
  tags?: string[];
}

/** Parsed main.code structure. */
export interface MainCode {
  html: string;
  css?: string;
  js?: string;
  activities: Activity[];
}

/** Mutation file reference. */
export interface MutationFile {
  num: number;
  name: string;
  path: string;
}

// Wire protocol messages (Connector → Surface)

export interface DynamicUIMessage {
  type: "dynamic_ui";
  html: string;
  css: string;
  js: string;
  activities: Activity[];
}

export interface DynamicUIUpdateMessage {
  type: "dynamic_ui_update";
  js: string;
}

export interface DynamicUIClearMessage {
  type: "dynamic_ui_clear";
}

export interface CommandMessage {
  type: "command";
  id: string;
  command: string;
  params: Record<string, unknown>;
}

// Wire protocol messages (Surface → Connector)

export interface DynamicUIActionMessage {
  type: "dynamic_ui_action";
  action: {
    activityId: string;
    type: string;
    data?: Record<string, unknown>;
    context?: Record<string, unknown>;
  };
}

export interface CommandResultMessage {
  type: "command_result";
  id: string;
  ok: boolean;
  result?: unknown;
  error?: string;
}

export type OutgoingMessage =
  | DynamicUIMessage
  | DynamicUIUpdateMessage
  | DynamicUIClearMessage
  | CommandMessage;

export type IncomingMessage =
  | DynamicUIActionMessage
  | CommandResultMessage;
