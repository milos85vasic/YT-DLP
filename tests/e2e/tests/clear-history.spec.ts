import { test, expect } from '@playwright/test';

test('clear all history via dashboard UI', async ({ page, request }) => {
  // 1. Add a test download
  await request.post('http://localhost:8088/add', {
    data: { url: 'https://www.youtube.com/watch?v=jNQXAC9IVRw' }
  });
  await page.waitForTimeout(3000);

  // 2. Navigate to dashboard history
  await page.goto('http://localhost:9090/history');
  await expect(page.locator('.list .item')).toHaveCount(1);

  // 3. Handle confirm dialog
  page.on('dialog', dialog => dialog.accept());

  // 4. Click Clear All
  await page.click('.btn-clear-all');

  // 5. Wait for toast and verify list is empty
  await expect(page.locator('.toast')).toContainText('History cleared');
  await expect(page.locator('.list .item')).toHaveCount(0);
});
