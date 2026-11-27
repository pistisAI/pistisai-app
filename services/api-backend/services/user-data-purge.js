/**
 * User data purge for account hard delete.
 *
 * Several tables reference a user by a TEXT `user_id` (the auth subject or
 * the users.id as text) without a foreign key, so deleting the `users` row
 * does not cascade to them. This module removes, or pseudonymizes, every such
 * row inside the caller's transaction.
 *
 * Tables whose `user_id` is a UUID foreign key declared `ON DELETE CASCADE`
 * (api_keys, tunnels, email_*, proxy_*, user_auth_subjects, ...) are removed
 * by Postgres when the `users` row goes and are not listed here.
 *
 * Table names below are constants, never user input; every value is passed
 * as a query parameter.
 */

/**
 * Tables whose rows belonging to the user are deleted. `user_id` may be TEXT
 * or UUID depending on the schema, so it is compared as text.
 * `messages` is handled separately (it is keyed by conversation).
 */
export const USER_DATA_DELETE_TABLES = Object.freeze([
  'user_sessions',
  'subscriptions',
  'conversations',
  'tunnel_connections',
  'api_usage',
  'user_preferences',
  'user_activity_logs',
  'user_usage_metrics',
  'user_activity_summary',
]);

/**
 * Security audit tables kept for abuse investigation: the rows stay, but the
 * link to the person is removed (user id, IP address, user agent and the
 * free-form details, which can hold personal data, are cleared).
 */
export const USER_DATA_PSEUDONYMIZE_TABLES = Object.freeze([
  'audit_logs',
  'auth_audit_logs',
]);

async function tableExists(client, table) {
  const { rows } = await client.query(
    'SELECT to_regclass($1) IS NOT NULL AS exists',
    [table],
  );
  return Boolean(rows?.[0]?.exists);
}

/**
 * Collect every identifier this user can appear under in TEXT user_id
 * columns: users.id, users.jwt_id, users.supabase_id and any extra auth
 * subjects mapped in user_auth_subjects.
 */
export async function collectUserIdentifiers(client, userId) {
  const ids = new Set([String(userId)]);
  const { rows } = await client.query(
    `SELECT u.id::text AS id,
            to_jsonb(u)->>'jwt_id' AS jwt_id,
            to_jsonb(u)->>'supabase_id' AS supabase_id
       FROM users u
      WHERE u.id::text = $1`,
    [String(userId)],
  );
  for (const row of rows || []) {
    for (const value of [row.id, row.jwt_id, row.supabase_id]) {
      if (value) {
        ids.add(String(value));
      }
    }
  }
  if (await tableExists(client, 'user_auth_subjects')) {
    const subjects = await client.query(
      'SELECT subject FROM user_auth_subjects WHERE user_id::text = $1',
      [String(userId)],
    );
    for (const row of subjects.rows || []) {
      if (row.subject) {
        ids.add(String(row.subject));
      }
    }
  }
  return [...ids];
}

/**
 * Delete or pseudonymize the user's rows in every table that does not
 * cascade from `users`. Must run inside the caller's transaction, before the
 * `users` row is deleted.
 *
 * @returns {Promise<{identifiers: string[], deleted: Object<string, number>, pseudonymized: Object<string, number>, skipped: string[]}>}
 */
export async function purgeUserData(client, userId) {
  const identifiers = await collectUserIdentifiers(client, userId);
  const summary = { identifiers, deleted: {}, pseudonymized: {}, skipped: [] };

  // Messages first: they hang off conversations.
  if (
    (await tableExists(client, 'messages')) &&
    (await tableExists(client, 'conversations'))
  ) {
    const res = await client.query(
      `DELETE FROM messages
        WHERE conversation_id::text IN (
          SELECT id::text FROM conversations WHERE user_id::text = ANY($1::text[])
        )`,
      [identifiers],
    );
    summary.deleted.messages = res?.rowCount ?? 0;
  } else {
    summary.skipped.push('messages');
  }

  for (const table of USER_DATA_DELETE_TABLES) {
    if (!(await tableExists(client, table))) {
      summary.skipped.push(table);
      continue;
    }
    const res = await client.query(
      `DELETE FROM ${table} WHERE user_id::text = ANY($1::text[])`,
      [identifiers],
    );
    summary.deleted[table] = res?.rowCount ?? 0;
  }

  for (const table of USER_DATA_PSEUDONYMIZE_TABLES) {
    if (!(await tableExists(client, table))) {
      summary.skipped.push(table);
      continue;
    }
    const res = await client.query(
      `UPDATE ${table}
          SET user_id = NULL, ip_address = NULL, user_agent = NULL,
              details = '{}'::jsonb
        WHERE user_id::text = ANY($1::text[])`,
      [identifiers],
    );
    summary.pseudonymized[table] = res?.rowCount ?? 0;
  }

  // refunds.admin_user_id references users(id) without ON DELETE, which would
  // block deleting a user who once processed a refund. Keep the financial
  // record, drop the link.
  if (await tableExists(client, 'refunds')) {
    const res = await client.query(
      'UPDATE refunds SET admin_user_id = NULL WHERE admin_user_id::text = $1',
      [String(userId)],
    );
    summary.pseudonymized.refunds = res?.rowCount ?? 0;
  } else {
    summary.skipped.push('refunds');
  }

  return summary;
}
