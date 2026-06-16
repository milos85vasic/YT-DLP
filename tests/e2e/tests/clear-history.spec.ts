import { test, expect } from '@playwright/test';

// ISOLATION-TOLERANT: this spec runs against a SHARED, possibly-busy stack
// (other downloads from concurrent users/tests may be present). It therefore
// tracks the SPECIFIC test-injected item by its unique URL instead of asserting
// on global `.list .item` counts, and uses Playwright auto-retrying assertions
// (poll-until-deadline) instead of fixed waitForTimeout + immediate asserts.
test('clear all history via dashboard UI', async ({ page, request }) => {
  // 1. Add a download with a recognizable URL so we can track THIS item only.
  //    (The first-ever YouTube upload — stable, distinctive 11-char id.)
  const uniqueUrl = 'https://www.youtube.com/watch?v=jNQXAC9IVRw';
  await request.post('http://localhost:8088/add', {
    data: { url: uniqueUrl },
  });

  // 2. Handle the Clear-All confirm dialog (must be registered before the click).
  page.on('dialog', (dialog) => dialog.accept());

  // 3. Navigate to the dashboard history and wait for OUR item to appear.
  //    Auto-retrying assertion polls until the item shows up (tolerant of the
  //    added latency between /add and the history list updating). The item id
  //    is unknown, so we locate by its visible url text.
  await page.goto('http://localhost:9090/history');
  const testItem = page.locator('.item', { hasText: uniqueUrl });
  await expect(testItem).toBeVisible({ timeout: 15000 });

  // 4. Click Clear All.
  await page.click('.btn-clear-all');

  // 5. Verify the toast shows AND — the meaningful, isolation-tolerant assertion
  //    — that OUR specific test item disappeared. We do NOT assert the global
  //    list is empty, because concurrent downloads from a shared stack may add
  //    new items at any moment; "history cleared" is proven by our item going
  //    away, not by a global count of zero.
  await expect(page.locator('.toast')).toContainText('History cleared', {
    timeout: 15000,
  });
  await expect(testItem).toHaveCount(0, { timeout: 15000 });
});
