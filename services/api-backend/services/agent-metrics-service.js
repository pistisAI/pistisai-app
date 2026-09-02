/**
 * Agent metrics service
 * Persists agent event metrics to PostgreSQL.
 */

import { getPool } from '../database/db-pool.js';
import logger from '../logger.js';

const METRIC_WINDOWS = {
  hourly: 'hourly',
  daily: 'daily',
};

/**
 * Update agent metrics based on an incoming agent event.
 *
 * @param {string} agentDbId - agents.id UUID
 * @param {string} eventType
 * @param {object} eventData
 */
export async function updateAgentMetrics(agentDbId, eventType, eventData = {}) {
  const pool = getPool();
  const metrics = deriveMetrics(eventType, eventData);

  for (const metric of metrics) {
    await pool.query(
      `INSERT INTO agent_metrics (agent_id, metric_name, metric_value, metric_window)
       VALUES ($1, $2, $3, $4)`,
      [agentDbId, metric.name, metric.value, metric.window],
    );
  }

  logger.debug('[AgentMetrics] Updated metrics', {
    agentDbId,
    eventType,
    metricCount: metrics.length,
  });
}

export function deriveMetrics(eventType, eventData) {
  const metrics = [];

  switch (eventType) {
    case 'message:received':
    case 'message:thinking':
      metrics.push({
        name: 'messages_per_hour',
        value: 1,
        window: METRIC_WINDOWS.hourly,
      });
      break;
    case 'tool:start':
      metrics.push({
        name: 'tool_invocations',
        value: 1,
        window: METRIC_WINDOWS.hourly,
      });
      break;
    case 'error':
      metrics.push({
        name: 'error_rate',
        value: 1,
        window: METRIC_WINDOWS.hourly,
      });
      break;
    case 'reply':
      if (typeof eventData.duration_ms === 'number') {
        metrics.push({
          name: 'avg_response_time',
          value: eventData.duration_ms,
          window: METRIC_WINDOWS.hourly,
        });
      }
      break;
    default:
      break;
  }

  return metrics;
}
