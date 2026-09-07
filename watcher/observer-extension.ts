/**
 * Pi Watcher — Observer Extension
 *
 * An oh-my-pi extension that turns Pi into an always-on background watcher.
 * Registers health check tools, monitors tool calls, and sends alerts.
 *
 * Install:
 *   1. Copy to /dev/pistisai/watcher/observer-extension.ts
 *   2. Install: pi install ./watcher/observer-extension.ts
 *   3. Or reference directly in systemd ExecStart --extension flag
 */
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { heartbeat, recordSignal } from "./oversight-module.js";

export default function observerExtension(pi: ExtensionAPI) {
  const z = pi.zod;

  // ─── Health Check Tool ──────────────────────────────────────────
  pi.registerTool({
    name: "check_health",
    label: "Check Health",
    description: "Check health of all agent instances and services",
    parameters: z.object({
      scope: z.enum(["all", "agents", "services", "cron"]).default("all"),
    }),
    async execute(_id, { scope }) {
      const health = await performHealthCheck(scope);
      return {
        content: [
          { type: "text", text: JSON.stringify(health, null, 2) },
        ],
      };
    },
  });

  // ─── Notification Tool ──────────────────────────────────────────
  pi.registerTool({
    name: "notify_christopher",
    label: "Notify Christopher",
    description: "Send a notification to Christopher",
    parameters: z.object({
      message: z.string(),
      urgency: z.enum(["low", "medium", "high"]).default("medium"),
    }),
    async execute(_id, { message, urgency }) {
      await sendNotification(message, urgency);
      return {
        content: [{ type: "text", text: "Notification sent" }],
      };
    },
  });

  // ─── Systemd Status Tool ────────────────────────────────────────
  pi.registerTool({
    name: "systemd_status",
    label: "Systemd Status",
    description: "Check systemd service status",
    parameters: z.object({
      service: z.string().default("all"),
    }),
    async execute(_id, { service }) {
      const status = await checkSystemd(service);
      return {
        content: [{ type: "text", text: JSON.stringify(status, null, 2) }],
      };
    },
  });

  // ─── L1: Passive Monitoring ──────────────────────────────────────
  pi.on("tool_call", async (event) => {
    await pi.appendEntry({
      type: "tool_call_log",
      toolName: event.toolName,
      timestamp: Date.now(),
    });
    recordSignal({
      timestamp: Date.now(),
      type: "tool_call",
      detail: event.toolName,
      severity: "info",
    });
  });

  // ─── L2: Active Monitoring (every 5 min) ────────────────────────
  pi.setInterval(async () => {
    const health = await performHealthCheck("all");
    if (health.status !== "ok") {
      recordSignal({
        timestamp: Date.now(),
        type: "health_anomaly",
        detail: JSON.stringify(health.anomalies),
        severity: health.status === "critical" ? "critical" : "warning",
      });
    }
    // Run layered oversight heartbeat
    await heartbeat(pi);
  }, 300_000); // Every 5 minutes

  pi.sendMessage({
    role: "assistant",
    content: "🔍 Pi Watcher extension loaded. Monitoring active.",
    deliverAs: "steer",
  });
}

// ─── Health Check Implementation ────────────────────────────────────
async function performHealthCheck(scope: string): Promise<{
  status: "ok" | "warning" | "critical";
  anomalies: string[];
  timestamp: number;
}> {
  const anomalies: string[] = [];
  const services = ["llama-server", "pi-watcher"];

  if (scope === "all" || scope === "services") {
    for (const svc of services) {
      try {
        const result = await runCommand("systemctl", ["is-active", svc]);
        if (result.trim() !== "active") {
          anomalies.push(`Service ${svc}: ${result.trim()}`);
        }
      } catch (e) {
        anomalies.push(`Service ${svc}: check failed (${e})`);
      }
    }
  }

  const status = anomalies.length === 0
    ? "ok"
    : anomalies.length > 2 ? "critical" : "warning";

  return { status, anomalies, timestamp: Date.now() };
}

// ─── Notification Implementation ────────────────────────────────────
async function sendNotification(message: string, urgency: string): Promise<void> {
  // Write to a notification file that can be picked up by other services
  const fs = await import("fs/promises");
  const path = "/dev/pistisai/watcher/notifications.jsonl";
  const entry = JSON.stringify({
    timestamp: Date.now(),
    urgency,
    message,
  });
  await fs.appendFile(path, entry + "\n");
}

// ─── Systemd Status Implementation ──────────────────────────────────
async function checkSystemd(service: string): Promise<Record<string, string>> {
  if (service === "all") {
    const result = await runCommand("systemctl", ["list-units", "--type=service", "--state=running", "--no-pager", "--plain"]);
    const lines = result.split("\n").filter((l: string) => l.trim());
    const services: Record<string, string> = {};
    for (const line of lines.slice(1)) { // skip header
      const parts = line.split(/\s+/);
      if (parts.length >= 4) {
        services[parts[0]] = parts[3]; // name -> active state
      }
    }
    return services;
  }
  const result = await runCommand("systemctl", ["is-active", service]);
  return { [service]: result.trim() };
}

// ─── Utility ─────────────────────────────────────────────────────────
async function runCommand(cmd: string, args: string[]): Promise<string> {
  // Use Node.js child_process
  const { execFile } = await import("child_process");
  const { promisify } = await import("util");
  const execFileAsync = promisify(execFile);
  const { stdout } = await execFileAsync(cmd, args);
  return stdout;
}
