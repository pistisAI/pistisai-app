/**
 * Auth0 token refresh helper for streaming-proxy.
 */

export class TokenRefreshError extends Error {
  constructor(message: string, code = 'TOKEN_REFRESH_FAILED') {
    super(message);
    this.name = 'TokenRefreshError';
    this.code = code;
  }
}

interface RefreshTokenResponse {
  access_token: string;
  refresh_token?: string;
  expires_in?: number;
  token_type?: string;
}

/**
 * Exchange a refresh token for a new access token via Auth0.
 */
export async function refreshAuth0AccessToken(
  refreshToken: string,
): Promise<RefreshTokenResponse> {
  const domain = process.env.AUTH0_DOMAIN;
  const clientId = process.env.AUTH0_CLIENT_ID;
  const clientSecret = process.env.AUTH0_CLIENT_SECRET;
  const audience = process.env.AUTH0_AUDIENCE;

  if (!domain || !clientId) {
    throw new TokenRefreshError(
      'Auth0 refresh is not configured (AUTH0_DOMAIN, AUTH0_CLIENT_ID required)',
      'AUTH0_REFRESH_NOT_CONFIGURED',
    );
  }

  if (!refreshToken) {
    throw new TokenRefreshError(
      'Refresh token is required for token refresh',
      'REFRESH_TOKEN_REQUIRED',
    );
  }

  const body = new URLSearchParams({
    grant_type: 'refresh_token',
    client_id: clientId,
    refresh_token: refreshToken,
  });

  if (clientSecret) {
    body.set('client_secret', clientSecret);
  }
  if (audience) {
    body.set('audience', audience);
  }

  const response = await fetch(`https://${domain}/oauth/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });

  const payload = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new TokenRefreshError(
      payload.error_description ||
        payload.error ||
        `Auth0 token refresh failed with status ${response.status}`,
      'AUTH0_REFRESH_REJECTED',
    );
  }

  if (!payload.access_token) {
    throw new TokenRefreshError(
      'Auth0 refresh response did not include access_token',
      'AUTH0_REFRESH_INVALID_RESPONSE',
    );
  }

  return payload;
}
