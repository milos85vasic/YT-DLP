import { test, expect } from '@playwright/test';

test('cleanup single history item', async ({ page, request }) => {
  // Clear all history first to ensure clean state
  const historyResp = await request.get('http://localhost:8088/history');
  const history = await historyResp.json();
  const doneUrls = (history.done || []).map((item: any) => item.url);
  if (doneUrls.length > 0) {
    await request.post('http://localhost:8088/delete', {
      data: { ids: doneUrls, where: 'done' },
    });
  }

  await request.post('http://localhost:8088/add', {
    data: { url: 'https://www.youtube.com/watch?v=jNQXAC9IVRw' }
  });
  await page.waitForTimeout(3000);

  await page.goto('http://localhost:9090/history');
  await expect(page.locator('.list .item')).toHaveCount(1);

  await page.click('.btn-cleanup');
  await expect(page.locator('.toast')).toContainText('Removed from history');
  await expect(page.locator('.list .item')).toHaveCount(0);
});

test('start pending download', async ({ page, request }) => {
  // Clear queue first
  const historyResp = await request.get('http://localhost:8088/history');
  const history = await historyResp.json();
  const pendingUrls = (history.pending || []).map((item: any) => item.url);
  if (pendingUrls.length > 0) {
    await request.post('http://localhost:8088/delete', {
      data: { ids: pendingUrls, where: 'queue' },
    });
  }

  await request.post('http://localhost:8088/add', {
    data: { url: 'https://www.youtube.com/watch?v=9bZkp7q19f0', auto_start: false }
  });
  await page.waitForTimeout(1000);

  await page.goto('http://localhost:9090/queue');
  await expect(page.locator('.item.pending')).toHaveCount(1);

  await page.click('.btn-start');
  await page.waitForTimeout(1500);
  await expect(page.locator('.item.pending')).toHaveCount(0);
});
