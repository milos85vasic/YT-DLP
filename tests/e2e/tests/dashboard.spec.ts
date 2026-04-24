import { test, expect } from '@playwright/test';

const DASHBOARD_URL = 'http://localhost:9090';

test.describe('Dashboard', () => {
  test('page loads with correct title', async ({ page }) => {
    await page.goto(DASHBOARD_URL);
    await expect(page).toHaveTitle(/YT-DLP Dashboard/);
  });

  test('Angular app renders with navbar', async ({ page }) => {
    await page.goto(DASHBOARD_URL);
    await expect(page.locator('app-root')).toBeAttached();
    // Wait for Angular to bootstrap and render navbar
    await expect(page.locator('nav, .navbar, [class*="nav"]')).toBeVisible({ timeout: 10000 });
  });

  test('navbar contains navigation links', async ({ page }) => {
    await page.goto(DASHBOARD_URL);
    await expect(page.locator('nav, .navbar')).toBeVisible({ timeout: 10000 });
    const navText = await page.locator('nav, .navbar').textContent();
    expect(navText).toMatch(/History|Queue|Downloads/i);
  });

  test('can navigate to History page', async ({ page }) => {
    await page.goto(DASHBOARD_URL);
    await expect(page.locator('nav, .navbar')).toBeVisible({ timeout: 10000 });
    // Click History link if present
    const historyLink = page.locator('nav a, .navbar a, [routerlink="/history"]').filter({ hasText: /History/i });
    if (await historyLink.isVisible().catch(() => false)) {
      await historyLink.click();
      await page.waitForURL('**/history', { timeout: 5000 });
    }
    // Either way, assert history content or route
    await expect(page.locator('app-history')).toBeVisible({ timeout: 5000 });
  });

  test('can navigate to Queue page', async ({ page }) => {
    await page.goto(DASHBOARD_URL);
    await expect(page.locator('nav, .navbar')).toBeVisible({ timeout: 10000 });
    const queueLink = page.locator('nav a, .navbar a, [routerlink="/queue"]').filter({ hasText: /Queue/i });
    if (await queueLink.isVisible().catch(() => false)) {
      await queueLink.click();
      await page.waitForURL('**/queue', { timeout: 5000 });
    }
    await expect(page.locator('app-queue')).toBeVisible({ timeout: 5000 });
  });

  test('API proxy returns history data', async ({ request }) => {
    const resp = await request.get(`${DASHBOARD_URL}/api/history`);
    expect(resp.status()).toBe(200);
    const body = await resp.json();
    expect(body).toHaveProperty('done');
    expect(body).toHaveProperty('queue');
    expect(body).toHaveProperty('pending');
    expect(Array.isArray(body.done)).toBe(true);
  });

  test('API proxy returns version data', async ({ request }) => {
    const resp = await request.get(`${DASHBOARD_URL}/api/version`);
    expect(resp.status()).toBe(200);
    const body = await resp.json();
    expect(body).toHaveProperty('version');
    expect(body).toHaveProperty('yt-dlp');
  });

  test('404 page handles unknown routes gracefully', async ({ page }) => {
    await page.goto(`${DASHBOARD_URL}/nonexistent-route`);
    await expect(page.locator('body')).toBeVisible();
    // Angular SPA should still render the app shell
    await expect(page.locator('app-root')).toBeAttached();
  });
});
