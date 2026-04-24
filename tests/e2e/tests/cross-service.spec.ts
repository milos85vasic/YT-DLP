import { test, expect } from '@playwright/test';

const METUBE_URL = 'http://localhost:8088';
const DASHBOARD_URL = 'http://localhost:9090';
const LANDING_URL = 'http://localhost:8086';

test.describe('Cross-Service Consistency', () => {
  test('MeTube direct and dashboard proxy return same history structure', async ({ request }) => {
    const direct = await request.get(`${METUBE_URL}/history`);
    const proxy = await request.get(`${DASHBOARD_URL}/api/history`);

    expect(direct.status()).toBe(200);
    expect(proxy.status()).toBe(200);

    const directBody = await direct.json();
    const proxyBody = await proxy.json();

    expect(Object.keys(directBody).sort()).toEqual(Object.keys(proxyBody).sort());
    expect(Array.isArray(directBody.done)).toBe(true);
    expect(Array.isArray(proxyBody.done)).toBe(true);
  });

  test('MeTube direct and dashboard proxy return same version structure', async ({ request }) => {
    const direct = await request.get(`${METUBE_URL}/version`);
    const proxy = await request.get(`${DASHBOARD_URL}/api/version`);

    expect(direct.status()).toBe(200);
    expect(proxy.status()).toBe(200);

    const directBody = await direct.json();
    const proxyBody = await proxy.json();

    expect(directBody.version).toBe(proxyBody.version);
    expect(directBody['yt-dlp']).toBe(proxyBody['yt-dlp']);
  });

  test('landing delete-download proxy returns structured response', async ({ request }) => {
    const resp = await request.post(`${LANDING_URL}/api/delete-download`, {
      data: { ids: ['nonexistent-id'], where: 'done' },
      headers: { 'Content-Type': 'application/json' },
    });
    // Returns 400 for nonexistent ID but still structured JSON
    expect(resp.status()).toBe(400);
    const body = await resp.json();
    expect(body).toHaveProperty('success');
    expect(body.success).toBe(false);
  });

  test('all services respond within 5 seconds', async ({ request }) => {
    const start = Date.now();
    await request.get(METUBE_URL);
    await request.get(DASHBOARD_URL);
    await request.get(LANDING_URL);
    const elapsed = Date.now() - start;
    expect(elapsed).toBeLessThan(5000);
  });

  test('services have CORS or same-origin accessibility', async ({ request }) => {
    // Dashboard proxy must be able to call MeTube
    const resp = await request.get(`${DASHBOARD_URL}/api/history`);
    expect(resp.status()).toBe(200);

    // Landing must be able to proxy to MeTube
    const landingHealth = await request.get(`${LANDING_URL}/health`);
    const landingBody = await landingHealth.json();
    expect(landingBody.metube_reachable).toBe(true);
  });
});
