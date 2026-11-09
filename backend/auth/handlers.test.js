const request = require('supertest');

const DEV_TOKEN = 'ci-dev-bypass-token-for-tests';

describe('Auth Backend', () => {
  let app;
  let originalNodeEnv;
  let originalDevBypass;

  beforeAll(() => {
    originalNodeEnv = process.env.NODE_ENV;
    originalDevBypass = process.env.DEV_BYPASS_TOKEN;
    process.env.NODE_ENV = 'development';
    process.env.DEV_BYPASS_TOKEN = DEV_TOKEN;
    ({ app } = require('./handlers.js'));
  });

  afterAll(() => {
    process.env.NODE_ENV = originalNodeEnv;
    if (originalDevBypass === undefined) {
      delete process.env.DEV_BYPASS_TOKEN;
    } else {
      process.env.DEV_BYPASS_TOKEN = originalDevBypass;
    }
  });

  describe('GET /health', () => {
    it('returns ok status', async () => {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ok');
    });
  });

  describe('GET /api/protected', () => {
    it('returns 401 without token', async () => {
      const res = await request(app).get('/api/protected');
      expect(res.status).toBe(401);
      expect(res.body.error).toBe('Invalid token');
    });

    it('accepts DEV_BYPASS_TOKEN in development', async () => {
      const res = await request(app)
        .get('/api/protected')
        .set('Authorization', `Bearer ${DEV_TOKEN}`);
      expect(res.status).toBe(200);
      expect(res.body.message).toBe('Protected endpoint');
      expect(res.body.user_id).toBe('google-oauth2|102509433531341542550');
      expect(res.body.email).toBe('dev@pistisai.app');
    });

    it('rejects an unrecognized bearer token even in development', async () => {
      const res = await request(app)
        .get('/api/protected')
        .set('Authorization', 'Bearer not-the-configured-bypass');
      expect(res.status).toBe(401);
    });
  });
});
