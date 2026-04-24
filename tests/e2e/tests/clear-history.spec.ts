import { test, expect } from '@playwright/test';

test('clear all history via dashboard UI', async ({ page, request }) => {
  // 1. Clear all existing history first for clean state
  const historyResp = await request.get('http://localhost:8088/history');
  const history = await historyResp.json();
  const doneUrls = (history.done || []).map((item: any) => item.url);
  if (doneUrls.length > 0) {
    await request.post('http://localhost:8088/delete', {
      data: { ids: doneUrls, where: 'done' },
    });
  }

  // 2. Add a test download
  await request.post('http://localhost:8088/add', {
    data: { url: 'https://www.youtube.com/watch?v=jNQXAC9IVRw' }
  });
  await page.waitForTimeout(3000);

  // 3. Navigate to dashboard history
  await page.goto('http://localhost:9090/history');
  await expect(page.locator('.list .item')).toHaveCount(1);

  // 4. Handle confirm dialog
  page.on('dialog', dialog => dialog.accept());

  // 5. Click Clear All
  await page.click('.btn-clear-all');

  // 6. Wait for toast and verify list is empty
  await expect(page.locator('.toast')).toContainText('History cleared');
  await expect(page.locator('.list .item')).toHaveCount(0);
});
