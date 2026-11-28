/**
 * Removes credentials from a Sentry event before it is sent.
 *
 * Called from the Sentry `beforeSend` hook. The SDK's data collection
 * settings already mask many values; this is a second, explicit layer so
 * an error report never carries a request credential, whatever the SDK
 * defaults are in a given version.
 *
 * Removed from `event.request` and from breadcrumb `data`:
 * - the headers Authorization, Proxy-Authorization, Cookie, Set-Cookie,
 *   Cf-Access-Jwt-Assertion and X-Api-Key (any letter case);
 * - the `cookies` field;
 * - token-like query string parameters (token, access_token, api_key, ...)
 *   in `query_string` and in URLs.
 *
 * Everything else in the event is left as it is. The event is changed in
 * place and returned.
 */

const CREDENTIAL_HEADERS = new Set([
  'authorization',
  'proxy-authorization',
  'cookie',
  'set-cookie',
  'cf-access-jwt-assertion',
  'x-api-key',
]);

const CREDENTIAL_QUERY_PARAMS = new Set([
  'token',
  'access_token',
  'refresh_token',
  'id_token',
  'auth',
  'auth_token',
  'authorization',
  'api_key',
  'apikey',
  'api-key',
  'key',
  'secret',
  'client_secret',
  'password',
  'jwt',
  'code',
  'session',
  'session_id',
  'sessionid',
  'signature',
  'sig',
]);

export function isCredentialHeader(name) {
  return typeof name === 'string' && CREDENTIAL_HEADERS.has(name.toLowerCase());
}

export function isCredentialQueryParam(name) {
  if (typeof name !== 'string') {
    return false;
  }
  const lower = name.toLowerCase();
  return (
    CREDENTIAL_QUERY_PARAMS.has(lower) ||
    lower.endsWith('_token') ||
    lower.endsWith('-token') ||
    lower.endsWith('_secret')
  );
}

function stripHeaders(headers) {
  if (!headers || typeof headers !== 'object') {
    return;
  }
  for (const name of Object.keys(headers)) {
    if (isCredentialHeader(name)) {
      delete headers[name];
    }
  }
}

/** Removes credential parameters from a query string (leading `?` optional). */
export function stripQueryString(query) {
  if (typeof query !== 'string') {
    return query;
  }
  const hasMark = query.startsWith('?');
  const body = hasMark ? query.slice(1) : query;
  if (body === '') {
    return query;
  }
  const kept = body.split('&').filter((pair) => {
    const rawName = pair.split('=')[0];
    let name = rawName;
    try {
      name = decodeURIComponent(rawName.replace(/\+/g, ' '));
    } catch {
      // Keep the raw name when it is not valid percent-encoding.
    }
    return !isCredentialQueryParam(name);
  });
  return (hasMark && kept.length > 0 ? '?' : '') + kept.join('&');
}

function stripQueryStringField(value) {
  if (typeof value === 'string') {
    return stripQueryString(value);
  }
  if (Array.isArray(value)) {
    return value.filter(
      (entry) => !(Array.isArray(entry) && isCredentialQueryParam(entry[0])),
    );
  }
  if (value && typeof value === 'object') {
    for (const name of Object.keys(value)) {
      if (isCredentialQueryParam(name)) {
        delete value[name];
      }
    }
  }
  return value;
}

/** Removes credential query parameters from a URL; keeps the fragment. */
export function stripUrl(url) {
  if (typeof url !== 'string') {
    return url;
  }
  const queryStart = url.indexOf('?');
  if (queryStart === -1) {
    return url;
  }
  const hashStart = url.indexOf('#', queryStart);
  const base = url.slice(0, queryStart);
  const query =
    hashStart === -1 ? url.slice(queryStart) : url.slice(queryStart, hashStart);
  const hash = hashStart === -1 ? '' : url.slice(hashStart);
  return base + stripQueryString(query) + hash;
}

function scrubRequest(request) {
  if (!request || typeof request !== 'object') {
    return;
  }
  stripHeaders(request.headers);
  delete request.cookies;
  if ('query_string' in request) {
    request.query_string = stripQueryStringField(request.query_string);
  }
  if ('url' in request) {
    request.url = stripUrl(request.url);
  }
}

function scrubBreadcrumbData(data) {
  if (!data || typeof data !== 'object') {
    return;
  }
  for (const field of ['headers', 'request_headers', 'response_headers']) {
    stripHeaders(data[field]);
  }
  for (const field of ['url', 'http.url', 'to', 'from']) {
    if (typeof data[field] === 'string') {
      data[field] = stripUrl(data[field]);
    }
  }
  if ('http.query' in data) {
    data['http.query'] = stripQueryStringField(data['http.query']);
  }
}

export function scrubSentryEvent(event) {
  if (!event || typeof event !== 'object') {
    return event;
  }
  scrubRequest(event.request);
  let breadcrumbs = [];
  if (Array.isArray(event.breadcrumbs)) {
    breadcrumbs = event.breadcrumbs;
  } else if (event.breadcrumbs && Array.isArray(event.breadcrumbs.values)) {
    breadcrumbs = event.breadcrumbs.values;
  }
  for (const crumb of breadcrumbs) {
    if (crumb && typeof crumb === 'object') {
      scrubBreadcrumbData(crumb.data);
    }
  }
  return event;
}
