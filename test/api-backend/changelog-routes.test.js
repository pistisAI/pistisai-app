/**
 * Behavior tests for changelog routes.
 */

import { describe, it, expect, jest, beforeEach } from '@jest/globals';

const mockService = {
  getAllVersions: jest.fn(),
  formatChangelogEntry: jest.fn((entry) => ({ ...entry, formatted: true })),
  getLatestVersion: jest.fn(),
  getReleaseNotes: jest.fn(),
  getChangelogStats: jest.fn(),
};

jest.unstable_mockModule(
  '../../services/api-backend/services/changelog-service.js',
  () => ({
    default: jest.fn().mockImplementation(() => mockService),
  }),
);

const request = (await import('supertest')).default;
const express = (await import('express')).default;
const changelogRoutes = (
  await import('../../services/api-backend/routes/changelog.js')
).default;

describe('changelog routes', () => {
  let app;

  beforeEach(() => {
    jest.clearAllMocks();
    mockService.formatChangelogEntry.mockImplementation((entry) => ({
      ...entry,
      formatted: true,
    }));
    app = express();
    app.use('/changelog', changelogRoutes);
  });

  it('GET / returns paginated changelog entries', async () => {
    mockService.getAllVersions.mockReturnValue({
      versions: [{ version: '1.0.0', changes: [] }],
      total: 1,
    });
    const res = await request(app).get('/changelog?limit=5&offset=0').expect(200);
    expect(mockService.getAllVersions).toHaveBeenCalledWith(5, 0);
    expect(res.body.versions[0].formatted).toBe(true);
  });

  it('GET / clamps limit to a maximum of 100', async () => {
    mockService.getAllVersions.mockReturnValue({ versions: [], total: 0 });
    await request(app).get('/changelog?limit=500').expect(200);
    expect(mockService.getAllVersions).toHaveBeenCalledWith(100, 0);
  });

  it('GET /latest returns the newest entry', async () => {
    mockService.getLatestVersion.mockReturnValue({ version: '2.0.0' });
    const res = await request(app).get('/changelog/latest').expect(200);
    expect(res.body.version).toBe('2.0.0');
    expect(res.body.formatted).toBe(true);
  });

  it('GET /latest returns 404 when empty', async () => {
    mockService.getLatestVersion.mockReturnValue(null);
    const res = await request(app).get('/changelog/latest').expect(404);
    expect(res.body.error).toMatch(/No changelog/);
  });

  it('GET /:version validates semantic version format', async () => {
    const res = await request(app).get('/changelog/not-a-version').expect(400);
    expect(res.body.error).toMatch(/Invalid version format/);
  });

  it('GET /:version returns release notes', async () => {
    mockService.getReleaseNotes.mockReturnValue({
      version: '1.2.3',
      notes: 'fixed bugs',
    });
    const res = await request(app).get('/changelog/1.2.3').expect(200);
    expect(res.body.version).toBe('1.2.3');
  });

  it('GET /:version returns 404 when notes are missing', async () => {
    mockService.getReleaseNotes.mockReturnValue(null);
    const res = await request(app).get('/changelog/9.9.9').expect(404);
    expect(res.body.error).toMatch(/not found/);
  });

  it('GET / returns 500 when service throws', async () => {
    mockService.getAllVersions.mockImplementation(() => {
      throw new Error('parse failed');
    });
    const res = await request(app).get('/changelog').expect(500);
    expect(res.body.error).toMatch(/Failed to retrieve changelog/);
  });
});
