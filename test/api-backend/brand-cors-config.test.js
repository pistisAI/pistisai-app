/**
 * Brand-Aware CORS Configuration Tests
 *
 * Tests for:
 * - Brand extraction from various request sources
 * - CORS policy application per brand
 * - Origin validation and enforcement
 * - Preflight request handling
 * - Policy fallback to defaults
 *
 * Issue #385: CORS policy enforcement for whitelabel builds
 */

import request from 'supertest';
import express from 'express';
import {
  initializeBrandCORSPolicies,
  registerBrandCORSPolicy,
  getBrandCORSPolicy,
  extractBrandFromRequest,
  dynamicBrandCorsMiddleware,
  logBrandCorsDecisions,
  getAllBrandPolicies,
  isOriginAllowedForBrand,
  DEFAULT_BRAND_CORS_POLICY,
} from '../middleware/brand-cors-config.js';

describe('Brand-Aware CORS Configuration', () => {
  let app;

  beforeEach(() => {
    // Reset to initial state
    initializeBrandCORSPolicies();

    // Create test app
    app = express();
    app.use(logBrandCorsDecisions);
    app.use(dynamicBrandCorsMiddleware);

    app.get('/test', (req, res) => {
      res.json({
        brandId: req.brandId,
        message: 'OK',
      });
    });

    app.post('/test', (req, res) => {
      res.json({
        brandId: req.brandId,
        method: 'POST',
      });
    });
  });

  describe('Brand Extraction', () => {
    it('should extract brand from X-Brand-ID header', () => {
      const req = {
        headers: {
          'x-brand-id': 'acme',
        },
        hostname: 'api.pistisai.app',
        query: {},
      };

      const brandId = extractBrandFromRequest(req);
      expect(brandId).toBe('acme');
    });

    it('should extract brand from subdomain', () => {
      const req = {
        headers: {
          host: 'acme.pistisai.app',
        },
        hostname: 'acme.pistisai.app',
        query: {},
      };

      const brandId = extractBrandFromRequest(req);
      expect(brandId).toBe('acme');
    });

    it('should not extract reserved subdomains as brand', () => {
      const reservedSubdomains = ['www', 'api', 'admin', 'app', 'localhost'];

      reservedSubdomains.forEach((subdomain) => {
        const req = {
          headers: {
            host: `${subdomain}.pistisai.app`,
          },
          hostname: `${subdomain}.pistisai.app`,
          query: {},
        };

        const brandId = extractBrandFromRequest(req);
        expect(brandId).not.toBe(subdomain);
      });
    });

    it('should extract brand from origin header', () => {
      const req = {
        headers: {
          origin: 'https://acme.pistisai.app',
        },
        hostname: 'api.pistisai.app',
        query: {},
      };

      const brandId = extractBrandFromRequest(req);
      expect(brandId).toBe('acme');
    });

    it('should extract brand from query parameter', () => {
      const req = {
        headers: {},
        hostname: 'api.pistisai.app',
        query: { brandId: 'acme' },
      };

      const brandId = extractBrandFromRequest(req);
      expect(brandId).toBe('acme');
    });

    it('should default to "default" brand when no identifier found', () => {
      const req = {
        headers: {},
        hostname: 'api.pistisai.app',
        query: {},
      };

      const brandId = extractBrandFromRequest(req);
      expect(brandId).toBe('default');
    });

    it('should prioritize X-Brand-ID over other sources', () => {
      const req = {
        headers: {
          'x-brand-id': 'brand-header',
          host: 'brand-subdomain.pistisai.app',
          origin: 'https://brand-origin.pistisai.app',
        },
        hostname: 'brand-subdomain.pistisai.app',
        query: { brandId: 'brand-query' },
      };

      const brandId = extractBrandFromRequest(req);
      expect(brandId).toBe('brand-header');
    });
  });

  describe('CORS Policy Management', () => {
    it('should register a new brand CORS policy', () => {
      const policy = {
        origins: ['https://app.acme.com', 'https://api.acme.com'],
        credentials: true,
        methods: ['GET', 'POST'],
      };

      registerBrandCORSPolicy('acme', policy);

      const retrieved = getBrandCORSPolicy('acme');
      expect(retrieved.origins).toEqual(policy.origins);
      expect(retrieved.credentials).toBe(policy.credentials);
      expect(retrieved.methods).toEqual(policy.methods);
    });

    it('should merge new policy with defaults', () => {
      const partialPolicy = {
        origins: ['https://app.acme.com'],
      };

      registerBrandCORSPolicy('acme', partialPolicy);

      const retrieved = getBrandCORSPolicy('acme');
      expect(retrieved.origins).toEqual(partialPolicy.origins);
      expect(retrieved.methods).toEqual(DEFAULT_BRAND_CORS_POLICY.methods);
      expect(retrieved.credentials).toBe(DEFAULT_BRAND_CORS_POLICY.credentials);
    });

    it('should return default policy when brand not registered', () => {
      const policy = getBrandCORSPolicy('unknown-brand');

      expect(policy).toBeDefined();
      expect(policy.methods).toBeDefined();
      expect(policy.credentials).toBeDefined();
    });

    it('should get all registered brand policies', () => {
      registerBrandCORSPolicy('acme', {
        origins: ['https://app.acme.com'],
      });
      registerBrandCORSPolicy('widgets', {
        origins: ['https://app.widgets.com'],
      });

      const allPolicies = getAllBrandPolicies();

      expect(allPolicies.acme).toBeDefined();
      expect(allPolicies.widgets).toBeDefined();
      expect(allPolicies.default).toBeDefined();
    });
  });

  describe('Origin Validation', () => {
    beforeEach(() => {
      registerBrandCORSPolicy('acme', {
        origins: ['https://app.acme.com', 'https://api.acme.com'],
      });
    });

    it('should allow registered origins', () => {
      const isAllowed = isOriginAllowedForBrand('acme', 'https://app.acme.com');
      expect(isAllowed).toBe(true);
    });

    it('should reject unregistered origins', () => {
      const isAllowed = isOriginAllowedForBrand('acme', 'https://evil.com');
      expect(isAllowed).toBe(false);
    });

    it('should allow requests without origin', () => {
      const isAllowed = isOriginAllowedForBrand('acme', null);
      expect(isAllowed).toBe(true);
    });

    it('should reject empty origin string for brand with strict policy', () => {
      const isAllowed = isOriginAllowedForBrand('acme', '');
      // Empty string should not be in the origins array
      expect(isAllowed).toBe(false);
    });
  });

  describe('HTTP Middleware Integration', () => {
    it('should allow GET request from authorized origin', async () => {
      registerBrandCORSPolicy('acme', {
        origins: ['http://localhost:3000'],
      });

      const response = await request(app)
        .get('/test')
        .set('Origin', 'http://localhost:3000')
        .set('X-Brand-ID', 'acme');

      expect(response.status).toBe(200);
      expect(response.body.brandId).toBe('acme');
      expect(response.headers['access-control-allow-origin']).toBe('http://localhost:3000');
    });

    it('should block GET request from unauthorized origin with OPTIONS preflight rejected', async () => {
      registerBrandCORSPolicy('acme', {
        origins: ['https://app.acme.com'],
      });

      const response = await request(app)
        .options('/test')
        .set('Origin', 'https://evil.com')
        .set('X-Brand-ID', 'acme');

      expect(response.status).toBe(403);
      expect(response.body.error).toBe('CORS policy violation');
    });

    it('should handle OPTIONS preflight request', async () => {
      registerBrandCORSPolicy('acme', {
        origins: ['http://localhost:3000'],
        methods: ['GET', 'POST', 'PUT'],
      });

      const response = await request(app)
        .options('/test')
        .set('Origin', 'http://localhost:3000')
        .set('X-Brand-ID', 'acme')
        .set('Access-Control-Request-Method', 'POST');

      expect(response.status).toBe(200);
      expect(response.headers['access-control-allow-methods']).toContain('POST');
      expect(response.headers['access-control-allow-origin']).toBe('http://localhost:3000');
    });

    it('should include credentials header when policy allows', async () => {
      registerBrandCORSPolicy('acme', {
        origins: ['http://localhost:3000'],
        credentials: true,
      });

      const response = await request(app)
        .get('/test')
        .set('Origin', 'http://localhost:3000')
        .set('X-Brand-ID', 'acme');

      expect(response.headers['access-control-allow-credentials']).toBe('true');
    });

    it('should allow requests without origin header', async () => {
      const response = await request(app)
        .get('/test')
        .set('X-Brand-ID', 'acme');

      expect(response.status).toBe(200);
      expect(response.body.brandId).toBe('acme');
    });

    it('should extract brand from subdomain and enforce policy', async () => {
      registerBrandCORSPolicy('acme', {
        origins: ['http://localhost:3000'],
      });

      const response = await request(app)
        .get('/test')
        .set('Origin', 'http://localhost:3000')
        .set('Host', 'acme.pistisai.app');

      expect(response.status).toBe(200);
      expect(response.body.brandId).toBe('acme');
      expect(response.headers['access-control-allow-origin']).toBe('http://localhost:3000');
    });

    it('should handle multiple origins per brand', async () => {
      const origins = [
        'https://app.acme.com',
        'https://api.acme.com',
        'https://admin.acme.com',
      ];

      registerBrandCORSPolicy('acme', { origins });

      for (const origin of origins) {
        const response = await request(app)
          .get('/test')
          .set('Origin', origin)
          .set('X-Brand-ID', 'acme');

        expect(response.status).toBe(200);
        expect(response.headers['access-control-allow-origin']).toBe(origin);
      }
    });
  });

  describe('Policy Isolation Between Brands', () => {
    it('should enforce separate policies for different brands', async () => {
      registerBrandCORSPolicy('acme', {
        origins: ['https://app.acme.com'],
      });

      registerBrandCORSPolicy('widgets', {
        origins: ['https://app.widgets.com'],
      });

      // ACME brand should reject widgets origin
      const response1 = await request(app)
        .options('/test')
        .set('Origin', 'https://app.widgets.com')
        .set('X-Brand-ID', 'acme');

      expect(response1.status).toBe(403);

      // Widgets brand should reject acme origin
      const response2 = await request(app)
        .options('/test')
        .set('Origin', 'https://app.acme.com')
        .set('X-Brand-ID', 'widgets');

      expect(response2.status).toBe(403);
    });

    it('should not leak CORS headers between brands', async () => {
      registerBrandCORSPolicy('acme', {
        origins: ['https://app.acme.com'],
      });

      registerBrandCORSPolicy('widgets', {
        origins: ['https://app.widgets.com'],
      });

      const acmeResponse = await request(app)
        .get('/test')
        .set('Origin', 'https://app.acme.com')
        .set('X-Brand-ID', 'acme');

      expect(acmeResponse.headers['access-control-allow-origin']).toBe('https://app.acme.com');

      const widgetsResponse = await request(app)
        .get('/test')
        .set('Origin', 'https://app.widgets.com')
        .set('X-Brand-ID', 'widgets');

      expect(widgetsResponse.headers['access-control-allow-origin']).toBe(
        'https://app.widgets.com',
      );
    });
  });

  describe('Development Mode Flexibility', () => {
    it('should include localhost origins when NODE_ENV is development', () => {
      const originalEnv = process.env.NODE_ENV;
      try {
        process.env.NODE_ENV = 'development';

        // Manually register with development origins
        registerBrandCORSPolicy('dev-test', {
          origins: [
            'http://localhost:3000',
            'http://localhost:8080',
            'http://127.0.0.1:3000',
          ],
        });

        const policy = getBrandCORSPolicy('dev-test');
        expect(policy.origins).toContain('http://localhost:3000');
        expect(policy.origins).toContain('http://127.0.0.1:3000');
      } finally {
        process.env.NODE_ENV = originalEnv;
      }
    });

    it('should initialize default policy with production origins when NODE_ENV is production', () => {
      const defaultPolicy = getBrandCORSPolicy('default');

      // Default policy should have product origins
      expect(defaultPolicy.origins).toContain('https://app.pistisai.app');
      expect(defaultPolicy.origins).toContain('https://pistisai.app');
    });
  });

  describe('Environment Configuration', () => {
    it('should load CORS policies from BRAND_CORS_POLICIES_JSON env var', () => {
      const policies = {
        'brand-a': {
          origins: ['https://app-a.com'],
        },
        'brand-b': {
          origins: ['https://app-b.com'],
        },
      };

      process.env.BRAND_CORS_POLICIES_JSON = JSON.stringify(policies);

      initializeBrandCORSPolicies();

      expect(getBrandCORSPolicy('brand-a').origins).toEqual(['https://app-a.com']);
      expect(getBrandCORSPolicy('brand-b').origins).toEqual(['https://app-b.com']);

      delete process.env.BRAND_CORS_POLICIES_JSON;
    });

    it('should handle invalid BRAND_CORS_POLICIES_JSON gracefully', () => {
      process.env.BRAND_CORS_POLICIES_JSON = 'invalid json {]';

      expect(() => {
        initializeBrandCORSPolicies();
      }).not.toThrow();

      delete process.env.BRAND_CORS_POLICIES_JSON;
    });
  });

  describe('Exposed Headers', () => {
    it('should include rate limiting headers in exposed headers', async () => {
      registerBrandCORSPolicy('acme', {
        origins: ['http://localhost:3000'],
      });

      const response = await request(app)
        .get('/test')
        .set('Origin', 'http://localhost:3000')
        .set('X-Brand-ID', 'acme');

      const exposedHeaders = response.headers['access-control-expose-headers'];
      expect(exposedHeaders).toContain('X-RateLimit-Limit');
      expect(exposedHeaders).toContain('X-RateLimit-Remaining');
      expect(exposedHeaders).toContain('X-RateLimit-Reset');
    });
  });

  describe('Backward Compatibility', () => {
    it('should provide default brand for existing deployments', () => {
      const defaultPolicy = getBrandCORSPolicy('default');

      expect(defaultPolicy).toBeDefined();
      expect(defaultPolicy.origins).toContain('https://app.pistisai.app');
      expect(defaultPolicy.origins).toContain('https://pistisai.app');
    });

    it('should work with requests that do not specify a brand', async () => {
      const response = await request(app)
        .get('/test')
        // No X-Brand-ID header
        .set('Origin', 'https://app.pistisai.app');

      expect(response.status).toBe(200);
      expect(response.body.brandId).toBe('default');
    });
  });
});
