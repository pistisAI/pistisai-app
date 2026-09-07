/**
 * Pi Watcher — Layered Oversight Module
 *
 * Implements the three-tier oversight model:
 *   L1 (Passive):  Log all tool calls, self-correct via extension
 *   L2 (Active):   Cron heartbeat → A2A peer check-in for second opinion
 *   L3 (Intervention): Anomaly + peer confirms → surface to Christopher
 *
 * This module is imported by observer-extension.ts.
 */
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

export type OversightLevel = "L1" | "L2" | "L3";

export interface DriftSignal {
  timestamp: number;
  type: string;
  detail: string;
  severity: "info" | "warning" | "critical";
}

export interface OversightState {
  signals: DriftSignal[];
  lastPeerCheck: number | null;
  lastIntervention: number | null;
}

const state: OversightState = {
  signals: [],
  lastPeerCheck: null,
  lastIntervention: null,
};

// ─── L1: Passive Monitoring ──────────────────────────────────────────

export function recordSignal(signal: DriftSignal): void {
  state.signals.push(signal);
  // Keep only last 100 signals to avoid unbounded growth
  if (state.signals.length > 100) {
    state.signals = state.signals.slice(-100);
  }
}

export function getRecentSignals(sinceMs: number = 3600_000): DriftSignal[] {
  const cutoff = Date.now() - sinceMs;
  return state.signals.filter((s) => s.timestamp >= cutoff);
}

// ─── L2: Active Accountability ───────────────────────────────────────

export async function performPeerCheck(pi: ExtensionAPI): Promise<{
  ok: boolean;
  detail: string;
}> {
  state.lastPeerCheck = Date.now();

  // Build a drift summary from recent signals
  const recent = getRecentSignals(1800_000); // Last 30 min
  const warnings = recent.filter((s) => s.severity === "warning");
  const criticals = recent.filter((s) => s.severity === "critical");

  if (criticals.length > 0) {
    // Escalate to L3
    return {
      ok: false,
      detail: `Critical signals detected: ${criticals.length}. Escalating to L3.`,
    };
  }

  if (warnings.length > 2) {
    return {
      ok: false,
      detail: `Multiple warnings (${warnings.length}). Peer review recommended.`,
    };
  }

  return {
    ok: true,
    detail: `L1 nominal. ${recent.length} signals in last 30min, no escalation needed.`,
  };
}

// ─── L3: Intervention ────────────────────────────────────────────────

export async function triggerIntervention(
  pi: ExtensionAPI,
  reason: string,
): Promise<void> {
  state.lastIntervention = Date.now();

  // Format as a single pointed question (from accountability-cron pattern)
  const question = formatInterventionQuestion(reason);

  pi.sendMessage({
    role: "assistant",
    content: question,
    deliverAs: "steer",
  });

  // Also log the intervention
  recordSignal({
    timestamp: Date.now(),
    type: "intervention",
    detail: reason,
    severity: "critical",
  });
}

function formatInterventionQuestion(reason: string): string {
  // Not a report. A question. Forces engagement without noise.
  return `🪞 ${reason}\n\n— Pi Watcher (L3 intervention)`;
}

// ─── Heartbeat (called by setInterval) ──────────────────────────────

export async function heartbeat(pi: ExtensionAPI): Promise<void> {
  const check = await performPeerCheck(pi);

  if (!check.ok) {
    // L2 escalation: ask the peer for a second opinion
    await triggerIntervention(pi, check.detail);
  } else {
    // L1: passive log
    recordSignal({
      timestamp: Date.now(),
      type: "heartbeat",
      detail: check.detail,
      severity: "info",
    });
  }
}

// ─── State Access ────────────────────────────────────────────────────

export function getState(): Readonly<OversightState> {
  return state;
}
