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
    process.env.AUTH0_DOMAIN =
      process.env.AUTH0_DOMAIN || 'test.example.auth0.com';
    process.env.AUTH0_AUDIENCE =
      process.env.AUTH0_AUDIENCE || 'https://api.example.com';
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
  const keys = [
    'NODE_ENV',
    'DEV_BYPASS_TOKEN',
    'AUTH_ALLOWED_ORIGINS',
    'AUTH_ROLE_CLAIM_NAMESPACE',
    'AUTH0_DOMAIN',
    'AUTH0_AUDIENCE',
  ];

  beforeEach(() => {
    keys.forEach((k) => { saved[k] = process.env[k]; });
    process.env.NODE_ENV = 'development';
    process.env.DEV_BYPASS_TOKEN = DEV;
    process.env.AUTH_ALLOWED_ORIGINS = 'https://brand.example.com,https://www.brand.example.com';
    process.env.AUTH_ROLE_CLAIM_NAMESPACE = 'https://brand.example.com';
    process.env.AUTH0_DOMAIN = 'test.example.auth0.com';
    process.env.AUTH0_AUDIENCE = 'https://api.example.com';
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
    const ok = await request(app).get('/health').set('Origin', 'https://brand.example.com');
    expect(ok.headers['access-control-allow-origin']).toBe('https://brand.example.com');
    const other = await request(app).get('/health').set('Origin', 'https://pistisai.app');
    expect(other.headers['access-control-allow-origin']).toBeUndefined();
  });
});

describe('Auth0 config fail-closed', () => {
  const saved = {};
  const keys = ['AUTH0_DOMAIN', 'AUTH0_AUDIENCE', 'NODE_ENV', 'DEV_BYPASS_TOKEN'];

  beforeEach(() => {
    keys.forEach((k) => { saved[k] = process.env[k]; });
  });

  afterEach(() => {
    keys.forEach((k) => {
      if (saved[k] === undefined) delete process.env[k];
      else process.env[k] = saved[k];
    });
  });

  it('throws when AUTH0_DOMAIN is missing instead of using a fake domain', () => {
    delete process.env.AUTH0_DOMAIN;
    process.env.AUTH0_AUDIENCE = 'https://api.example.com';
    expect(() => {
      jest.isolateModules(() => {
        require('./handlers.js');
      });
    }).toThrow(/AUTH0_DOMAIN/);
  });

  it('throws when AUTH0_AUDIENCE is missing instead of using a fake audience', () => {
    process.env.AUTH0_DOMAIN = 'test.example.auth0.com';
    delete process.env.AUTH0_AUDIENCE;
    expect(() => {
      jest.isolateModules(() => {
        require('./handlers.js');
      });
    }).toThrow(/AUTH0_AUDIENCE/);
  });
});
