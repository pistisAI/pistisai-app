/** Types for sentry-scrub.js, imported by src/server.ts. */
export function isCredentialHeader(name: unknown): boolean;
export function isCredentialQueryParam(name: unknown): boolean;
export function stripQueryString<T>(query: T): T;
export function stripUrl<T>(url: T): T;
export function scrubSentryEvent<T>(event: T): T;
