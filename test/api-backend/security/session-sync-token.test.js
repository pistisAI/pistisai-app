import {
  afterEach,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
  jest,
} from '@jest/globals';

const mockSyncSession = jest.fn();

jest.unstable_mockModule('express-oauth2-jwt-bearer', () => ({
  auth: jest.fn(() => (_req, _res, next) => next()),
}));

jest.unstable_mockModule(
  '../../../services/api-backend/auth/auth-service.js',
  () => ({
    AuthService: jest.fn().mockImplementation(() => ({
      initialize: jest.fn().mockResolvedValue(true),
      syncSession: mockSyncSession,
    })),
  }),
);

let syncSession;

beforeAll(async () => {
  process.env.NODE_ENV = 'development';
  ({ syncSession } = await import(
    '../../../services/api-backend/middleware/auth.js'
  ));
});

beforeEach(() => {
  mockSyncSession.mockReset();
  mockSyncSession.mockResolvedValue({ success: true });
});

afterEach(() => {
  jest.useRealTimers();
});

function responseDouble() {
  return {
    status: jest.fn().mockReturnThis(),
    json: jest.fn().mockReturnThis(),
  };
}

function authenticatedRequest(headers = {}) {
  return {
    headers,
    auth: {
      payload: {
        sub: 'auth0|user-1',
        exp: 4102444800,
      },
    },
  };
}

describe('syncSession raw token handling', () => {
  it('does not synchronize a session without a raw bearer token', async () => {
    const req = authenticatedRequest();
    const res = responseDouble();
    const next = jest.fn();

    await syncSession(req, res, next);

    expect(mockSyncSession).not.toHaveBeenCalled();
    expect(next).toHaveBeenCalledTimes(1);
    expect(res.status).not.toHaveBeenCalled();
  });

  it('passes the raw bearer token to session synchronization', async () => {
    const req = authenticatedRequest({ authorization: 'Bearer unique-token' });
    const res = responseDouble();
    const next = jest.fn();

    await syncSession(req, res, next);

    expect(mockSyncSession).toHaveBeenCalledWith(
      req.auth.payload,
      'unique-token',
      req,
    );
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('clears the synchronization timeout after a fast success', async () => {
    jest.useFakeTimers();
    const req = authenticatedRequest({ authorization: 'Bearer unique-token' });

    await syncSession(req, responseDouble(), jest.fn());

    expect(jest.getTimerCount()).toBe(0);
  });
});
