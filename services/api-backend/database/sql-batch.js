/**
 * Helpers for batched SQL writes (N+1 avoidance).
 */

/**
 * Build a multi-row VALUES clause and flattened parameter list.
 *
 * @param {Array<Array<*>>} rows - Each inner array is one row's column values
 * @param {number} [startParam=1] - First $N placeholder index
 * @returns {{ valuesSql: string, params: Array<*> }}
 */
export function buildMultiRowValues(rows, startParam = 1) {
  if (!Array.isArray(rows) || rows.length === 0) {
    return { valuesSql: '', params: [] };
  }

  const params = [];
  const valueGroups = [];
  let index = startParam;

  for (const row of rows) {
    const placeholders = [];
    for (const value of row) {
      placeholders.push(`$${index++}`);
      params.push(value);
    }
    valueGroups.push(`(${placeholders.join(', ')})`);
  }

  return {
    valuesSql: valueGroups.join(', '),
    params,
  };
}

/**
 * Insert conversation messages in a single multi-row INSERT.
 *
 * @param {{ query: Function }} client - DB client
 * @param {string} conversationId
 * @param {Array<Object>} messages
 * @param {string|null} [defaultModel]
 * @returns {Promise<void>}
 */
export async function insertMessagesBatched(
  client,
  conversationId,
  messages,
  defaultModel = null,
) {
  if (!Array.isArray(messages) || messages.length === 0) {
    return;
  }

  const params = [];
  const valueGroups = [];
  let index = 1;

  for (const msg of messages) {
    valueGroups.push(
      `($${index++}, $${index++}, $${index++}, $${index++}, $${index++}, $${index++}, $${index++}, $${index++}::jsonb)`,
    );
    params.push(
      conversationId,
      msg.role || 'user',
      msg.content || '',
      msg.model || defaultModel || null,
      msg.status || 'sent',
      msg.error || null,
      msg.timestamp ? new Date(msg.timestamp) : new Date(),
      msg.metadata
        ? typeof msg.metadata === 'string'
          ? msg.metadata
          : JSON.stringify(msg.metadata)
        : '{}',
    );
  }

  await client.query(
    `INSERT INTO messages(
  conversation_id, role, content, model, status, error, timestamp, metadata
) VALUES ${valueGroups.join(', ')}`,
    params,
  );
}
