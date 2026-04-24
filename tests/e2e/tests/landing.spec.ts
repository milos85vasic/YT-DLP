import { test, expect } from '@playwright/test';

const LANDING_URL = 'http://localhost:8086';

test.describe('Landing Page', () => {
  test('page loads with correct title', async ({ page }) => {
    await page.goto(LANDING_URL);
    await expect(page).toHaveTitle(/MeTube/);
  });

  test('displays main heading and subtitle', async ({ page }) => {
    await page.goto(LANDING_URL);
    await expect(page.locator('h1')).toHaveText('MeTube');
    await expect(page.locator('.subtitle')).toContainText('YouTube Video Downloader');
  });

  test('shows 3-step authentication flow', async ({ page }) => {
    await page.goto(LANDING_URL);
    const steps = page.locator('.step-progress .step');
    await expect(steps).toHaveCount(3);
    // Step state depends on cookie presence; just verify steps exist
    const step1Class = await page.locator('#step1').getAttribute('class');
    expect(step1Class).toMatch(/step/);
  });

  test('has cookie upload zone', async ({ page }) => {
    await page.goto(LANDING_URL);
    // Upload zone may be hidden if cookies are already present
    const dropZone = page.locator('#dropZone');
    await expect(dropZone).toBeAttached();
    await expect(page.locator('#cookieFile')).toHaveAttribute('accept', '.txt');
  });

  test('has link to MeTube dashboard', async ({ page }) => {
    await page.goto(LANDING_URL);
    const link = page.locator('#metubeLink');
    await expect(link).toBeVisible();
    // Href is dynamically set to dashboard URL
    const href = await link.getAttribute('href');
    expect(href).toMatch(/\/app|9090/);
  });

  test('cookie status API is reachable from browser context', async ({ request }) => {
    const resp = await request.get(`${LANDING_URL}/api/cookie-status`);
    expect(resp.status()).toBe(200);
    const body = await resp.json();
    expect(body).toHaveProperty('has_cookies');
    expect(body).toHaveProperty('metube_reachable');
  });

  test('health endpoint returns ok', async ({ request }) => {
    const resp = await request.get(`${LANDING_URL}/health`);
    expect(resp.status()).toBe(200);
    const body = await resp.json();
    expect(body.status).toBe('ok');
    expect(body).toHaveProperty('metube_reachable');
  });
});
