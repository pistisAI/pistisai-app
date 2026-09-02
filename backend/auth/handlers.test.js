const request = require('supertest');
const { app } = require('./handlers.js');

describe('Auth Backend', () => {
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

    it('accepts mock dev token in development', async () => {
      const res = await request(app)
        .get('/api/protected')
        .set('Authorization', 'Bearer mock_dev_access_token');
      expect(res.status).toBe(200);
      expect(res.body.message).toBe('Protected endpoint');
      expect(res.body.user_id).toBe('google-oauth2|102509433531341542550');
      expect(res.body.email).toBe('dev@pistisai.app');
    });
  });
});