import { TokenValidationResult } from '../interfaces/auth-middleware';
import { JWTValidator } from './jwt-validator.interface';
import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';

interface JWTPayload {
  sub: string;
  iss: string;
  aud: string | string[];
  exp: number;
  iat: number;
  email?: string;
  [key: string]: unknown;
}

function audienceMatches(actual: string | string[], expected: string): boolean {
  if (Array.isArray(actual)) {
    return actual.includes(expected);
  }
  return actual === expected;
}

/**
 * Validates Cloudflare Access JWTs using the team JWKS
 * (`https://<team>/cdn-cgi/access/certs`) and the application AUD.
 */
export class CloudflareAccessJWTValidator implements JWTValidator {
  private readonly client: jwksClient.JwksClient;
  private readonly audience: string;
  private readonly issuer: string;

  constructor(jwksUri: string, audience: string, issuer: string) {
    this.audience = audience;
    this.issuer = issuer;
    this.client = jwksClient({
      jwksUri,
      cache: true,
      rateLimit: true,
      jwksRequestsPerMinute: 5,
    });
  }

  private getKey(header: jwt.JwtHeader, callback: jwt.SigningKeyCallback) {
    this.client.getSigningKey(header.kid, (err: Error | null, key?: jwksClient.SigningKey) => {
      if (err) {
        callback(err);
        return;
      }
      callback(null, key?.getPublicKey());
    });
  }

  async validateToken(token: string): Promise<TokenValidationResult> {
    return new Promise((resolve) => {
      jwt.verify(
        token,
        this.getKey.bind(this),
        { algorithms: ['RS256'], issuer: this.issuer, audience: this.audience },
        (err: jwt.VerifyErrors | null, decoded: string | jwt.JwtPayload | undefined) => {
          if (err) {
            if (err instanceof jwt.TokenExpiredError) {
              const decodedToken = jwt.decode(token) as JWTPayload | null;
              resolve({
                valid: false,
                error: 'Token expired',
                userId: decodedToken?.sub,
                expiresAt: decodedToken?.exp
                  ? new Date(decodedToken.exp * 1000)
                  : undefined,
              });
            } else {
              resolve({
                valid: false,
                error: err.message,
              });
            }
            return;
          }

          const payload = decoded as JWTPayload;
          if (!audienceMatches(payload.aud, this.audience)) {
            resolve({
              valid: false,
              error: `Invalid audience: expected ${this.audience}, got ${String(payload.aud)}`,
            });
            return;
          }

          resolve({
            valid: true,
            userId: payload.sub,
            expiresAt: new Date(payload.exp * 1000),
          });
        }
      );
    });
  }
}
