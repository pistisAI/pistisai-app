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
      expect(res.body.user_id).toBe('dev-user');
      expect(res.body.email).toBe('dev@example.com');
    });

    it('rejects an unrecognized bearer token even in development', async () => {
      const res = await request(app)
        .get('/api/protected')
        .set('Authorization', 'Bearer not-the-configured-bypass');
      expect(res.status).toBe(401);
    });
  });
});

describe('Brand-driven auth config (whitelabel)', () => {
  const DEV = 'brand-test-token';
  const saved = {};
  const keys = ['NODE_ENV','DEV_BYPASS_TOKEN','AUTH_ALLOWED_ORIGINS','AUTH_ROLE_CLAIM_NAMESPACE'];

  beforeEach(() => {
    keys.forEach((k) => { saved[k] = process.env[k]; });
    process.env.NODE_ENV = 'development';
    process.env.DEV_BYPASS_TOKEN = DEV;
    process.env.AUTH_ALLOWED_ORIGINS = 'https://iacle.app,https://www.iacle.app';
    process.env.AUTH_ROLE_CLAIM_NAMESPACE = 'https://iacle.app';
  });

  afterEach(() => {
    keys.forEach((k) => {
      if (saved[k] === undefined) delete process.env[k];
      else process.env[k] = saved[k];
    });
  });

  it('allows the brand origin and rejects pistisai.app', async () => {
    let app;
    jest.isolateModules(() => { ({ app } = require('./handlers.js')); });
    const ok = await request(app).get('/health').set('Origin', 'https://iacle.app');
    expect(ok.headers['access-control-allow-origin']).toBe('https://iacle.app');
    const other = await request(app).get('/health').set('Origin', 'https://pistisai.app');
    expect(other.headers['access-control-allow-origin']).toBeUndefined();
  });
});
