import { test, expect } from '@playwright/test';

// ISOLATION-TOLERANT: these specs run against a SHARED, possibly-busy stack
// (other downloads from concurrent users/tests may be present in the queue and
// history). They therefore track the SPECIFIC test-injected item by its unique
// URL instead of asserting on global `.list .item` / `.item.pending` counts,
// and use Playwright auto-retrying assertions (poll-until-deadline) instead of
// fixed waitForTimeout + immediate asserts.

test('cleanup single history item', async ({ page, request }) => {
  // Add a download with a recognizable URL so we operate on THIS item only.
  const uniqueUrl = 'https://www.youtube.com/watch?v=jNQXAC9IVRw';
  await request.post('http://localhost:8088/add', {
    data: { url: uniqueUrl },
  });

  // Navigate and wait for OUR item to appear (tolerant of /add → list latency).
  await page.goto('http://localhost:9090/history');
  const testItem = page.locator('.item', { hasText: uniqueUrl });
  await expect(testItem).toBeVisible({ timeout: 15000 });

  // Click the cleanup button SCOPED to our specific item (not a global
  // `.btn-cleanup` that could hit some other concurrent download's row).
  await testItem.locator('.btn-cleanup').click();

  // Verify the toast shows AND our specific item disappeared. We do NOT assert
  // the global history list is empty — concurrent downloads may add rows.
  await expect(page.locator('.toast')).toContainText('Removed from history', {
    timeout: 15000,
  });
  await expect(testItem).toHaveCount(0, { timeout: 15000 });
});

test('start pending download', async ({ page, request }) => {
  // Add a queued (auto_start: false) download with a recognizable URL so we
  // track THIS pending item only.
  const uniqueUrl = 'https://www.youtube.com/watch?v=9bZkp7q19f0';
  await request.post('http://localhost:8088/add', {
    data: { url: uniqueUrl, auto_start: false },
  });

  // Navigate and wait for OUR pending item to appear. Locate by visible url
  // text; assert it is in the pending state via its data-status attribute.
  await page.goto('http://localhost:9090/queue');
  const testItem = page.locator('.item', { hasText: uniqueUrl });
  await expect(testItem).toBeVisible({ timeout: 15000 });
  await expect(testItem).toHaveAttribute('data-status', 'pending', {
    timeout: 15000,
  });

  // Click the start button SCOPED to our specific item (not a global
  // `.btn-start` that could start some other concurrent pending download).
  await testItem.locator('.btn-start').click();

  // Verify OUR item left the pending state. It may transition to
  // downloading/finished or move out of the pending list entirely; either way
  // it is no longer a pending row. We do NOT assert a global pending count of
  // zero — concurrent downloads may add other pending rows at any time.
  await expect(
    page.locator('.item[data-status="pending"]', { hasText: uniqueUrl }),
  ).toHaveCount(0, { timeout: 15000 });
});
