/**
 * SurfaceClient — WebSocket client connecting to plasma-surface.
 *
 * Replaces Hera's NodeRegistry for standalone use.
 * Auto-reconnects with exponential backoff.
 */

import WebSocket from "ws";
import { randomUUID } from "node:crypto";
import type {
  Activity,
  DynamicUIActionMessage,
  CommandResultMessage,
} from "./types.js";

export class SurfaceClient {
  private ws: WebSocket | null = null;
  private url: string;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private reconnectDelay = 1000;
  private maxReconnectDelay = 30000;
  private pendingCommands = new Map<
    string,
    { resolve: (result: unknown) => void; reject: (err: Error) => void; timer: ReturnType<typeof setTimeout> }
  >();
  private actionHandler: ((action: DynamicUIActionMessage["action"]) => void) | null = null;
  private actionWaiters: Array<{
    resolve: (action: DynamicUIActionMessage["action"]) => void;
    reject: (err: Error) => void;
    timer: ReturnType<typeof setTimeout>;
  }> = [];
  private _connected = false;

  constructor(url?: string) {
    this.url = url || process.env.PLASMA_SURFACE_URL || "ws://localhost:9420";
  }

  /** Whether the client is currently connected to the surface. */
  isConnected(): boolean {
    return this._connected;
  }

  /** Connect to the plasma-surface WebSocket server. */
  async connect(): Promise<void> {
    if (this._connected) return;

    return new Promise<void>((resolve, reject) => {
      let resolved = false;

      const ws = new WebSocket(this.url);

      ws.on("open", () => {
        console.error("[SurfaceClient] Connected to", this.url);
        this._connected = true;
        this.ws = ws;
        this.reconnectDelay = 1000;
        if (!resolved) {
          resolved = true;
          resolve();
        }
      });

      ws.on("message", (data: WebSocket.Data) => {
        try {
          const msg = JSON.parse(data.toString());
          this.handleMessage(msg);
        } catch (err) {
          console.error("[SurfaceClient] Failed to parse message:", err);
        }
      });

      ws.on("close", () => {
        console.error("[SurfaceClient] Disconnected");
        this._connected = false;
        this.ws = null;
        this.scheduleReconnect();
        if (!resolved) {
          resolved = true;
          // Don't reject — just resolve and let tools fail individually
          resolve();
        }
      });

      ws.on("error", (err: Error) => {
        console.error("[SurfaceClient] Error:", err.message);
        if (!resolved) {
          resolved = true;
          resolve(); // Don't reject — surface may not be running yet
        }
      });
    });
  }

  /** Disconnect from the surface. */
  disconnect(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
    this._connected = false;
  }

  /** Render full HTML/CSS/JS on the surface. */
  async render(
    html: string,
    css: string,
    js: string,
    activities: Activity[],
  ): Promise<void> {
    this.send({
      type: "dynamic_ui",
      html,
      css,
      js,
      activities,
    });
  }

  /** Send incremental JS update (no reload). */
  async update(js: string): Promise<void> {
    this.send({
      type: "dynamic_ui_update",
      js,
    });
  }

  /** Clear the surface content. */
  async clear(): Promise<void> {
    this.send({
      type: "dynamic_ui_clear",
    });
  }

  /** Execute JS in the surface and return the result. */
  async query(js: string, timeoutMs = 10000): Promise<unknown> {
    const id = randomUUID();

    return new Promise<unknown>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pendingCommands.delete(id);
        reject(new Error("Query timed out"));
      }, timeoutMs);

      this.pendingCommands.set(id, { resolve, reject, timer });

      this.send({
        type: "command",
        id,
        command: "dynamic_ui.query",
        params: { js },
      });
    });
  }

  /** Take a screenshot of the surface. */
  async screenshot(timeoutMs = 15000): Promise<{ image: string; mimeType: string }> {
    const id = randomUUID();

    return new Promise<{ image: string; mimeType: string }>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pendingCommands.delete(id);
        reject(new Error("Screenshot timed out"));
      }, timeoutMs);

      this.pendingCommands.set(id, {
        resolve: (result) => resolve(result as { image: string; mimeType: string }),
        reject,
        timer,
      });

      this.send({
        type: "command",
        id,
        command: "dynamic_ui.screenshot",
        params: {},
      });
    });
  }

  /**
   * Block until a UI action arrives from the surface, or timeout.
   * One-shot: resolves with the first action received.
   * If multiple waiters are queued, each action resolves the oldest waiter (FIFO).
   */
  async waitForAction(timeoutSeconds: number): Promise<DynamicUIActionMessage["action"]> {
    if (!this._connected) {
      throw new Error("Not connected to Plasma Surface. Is plasma-surface running?");
    }

    return new Promise<DynamicUIActionMessage["action"]>((resolve, reject) => {
      const timer = setTimeout(() => {
        // Remove this waiter from the queue
        const idx = this.actionWaiters.findIndex((w) => w.timer === timer);
        if (idx !== -1) this.actionWaiters.splice(idx, 1);
        reject(new Error("Timeout waiting for UI event"));
      }, timeoutSeconds * 1000);

      this.actionWaiters.push({ resolve, reject, timer });
    });
  }

  /** Register a handler for user actions from the surface. */
  onAction(handler: (action: DynamicUIActionMessage["action"]) => void): void {
    this.actionHandler = handler;
  }

  // MARK: - Private

  private send(msg: Record<string, unknown>): void {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error("Not connected to Plasma Surface. Is plasma-surface running?");
    }
    this.ws.send(JSON.stringify(msg));
  }

  private handleMessage(msg: Record<string, unknown>): void {
    switch (msg.type) {
      case "dynamic_ui_action": {
        const actionMsg = msg as unknown as DynamicUIActionMessage;
        // Priority: resolve pending waiters (FIFO) before generic handler
        if (this.actionWaiters.length > 0) {
          const waiter = this.actionWaiters.shift()!;
          clearTimeout(waiter.timer);
          waiter.resolve(actionMsg.action);
        } else if (this.actionHandler) {
          this.actionHandler(actionMsg.action);
        }
        break;
      }

      case "command_result": {
        const resultMsg = msg as unknown as CommandResultMessage;
        const pending = this.pendingCommands.get(resultMsg.id);
        if (pending) {
          clearTimeout(pending.timer);
          this.pendingCommands.delete(resultMsg.id);
          if (resultMsg.ok) {
            pending.resolve(resultMsg.result);
          } else {
            pending.reject(new Error(resultMsg.error || "Command failed"));
          }
        }
        break;
      }

      default:
        console.error("[SurfaceClient] Unknown message type:", msg.type);
    }
  }

  private scheduleReconnect(): void {
    if (this.reconnectTimer) return;

    this.reconnectTimer = setTimeout(async () => {
      this.reconnectTimer = null;
      console.error("[SurfaceClient] Attempting reconnect...");

      try {
        const ws = new WebSocket(this.url);

        ws.on("open", () => {
          console.error("[SurfaceClient] Reconnected");
          this._connected = true;
          this.ws = ws;
          this.reconnectDelay = 1000;

          ws.on("message", (data: WebSocket.Data) => {
            try {
              const msg = JSON.parse(data.toString());
              this.handleMessage(msg);
            } catch (err) {
              console.error("[SurfaceClient] Failed to parse message:", err);
            }
          });

          ws.on("close", () => {
            this._connected = false;
            this.ws = null;
            this.scheduleReconnect();
          });

          ws.on("error", (err: Error) => {
            console.error("[SurfaceClient] Error:", err.message);
          });
        });

        ws.on("error", () => {
          this.reconnectDelay = Math.min(this.reconnectDelay * 2, this.maxReconnectDelay);
          this.scheduleReconnect();
        });
      } catch {
        this.reconnectDelay = Math.min(this.reconnectDelay * 2, this.maxReconnectDelay);
        this.scheduleReconnect();
      }
    }, this.reconnectDelay);
  }
}
