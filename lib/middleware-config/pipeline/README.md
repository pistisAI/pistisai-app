/**
 * Middleware Pipeline Module
 *
 * Main orchestration for setting up the complete middleware stack
 * Order is critical for security and performance
 */

export { setupMiddlewarePipeline } from './index.js';

/**
 * Main setup function
 *
 * Usage in an Express app:
 * ```javascript
 * import { setupMiddlewarePipeline } from '@pistisai/middleware-config/pipeline';
 *
 * const app = express();
 * setupMiddlewarePipeline(app, {
 *   corsOptions: { ... },
 *   rateLimitOptions: { ... },
 *   timeoutMs: 30000,
 * });
 * ```
 */
