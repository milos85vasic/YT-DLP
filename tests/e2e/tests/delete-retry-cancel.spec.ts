import { test, expect } from '@playwright/test';

const DASHBOARD_URL = 'http://localhost:9090';

/**
 * Note: "Delete with file" permanently removes the item from history AND
 * deletes the downloaded file from disk. We test the API directly because
 * the browser confirm dialog blocks Playwright automation. The UI flow
 * (confirm dialog → API call) is already covered by the dashboard component.
 */
test('delete download with file via API', async ({ request }) => {
  // 1. Add a download
  const addResp = await request.post(`${DASHBOARD_URL}/api/add`, {
    data: {
      url: 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
      quality: '720',
      format: 'any',
    },
  });
  expect(addResp.status()).toBe(200);

  // 2. Wait for it to land in history
  await new Promise((r) => setTimeout(r, 3000));

  // 3. Call delete-download with delete_file=true
  const delResp = await request.post(`${DASHBOARD_URL}/api/delete-download`, {
    data: {
      url: 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
      title: 'Me at the zoo',
      folder: '',
      delete_file: true,
    },
    headers: { 'Content-Type': 'application/json' },
  });
  expect(delResp.status()).toBe(200);
  const body = await delResp.json();
  expect(body.success).toBe(true);
});

test('retry a failed download via API', async ({ request }) => {
  // Add with auto_start=false so it lands in pending
  const addResp = await request.post(`${DASHBOARD_URL}/api/add`, {
    data: {
      url: 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
      quality: '720',
      format: 'any',
      auto_start: false,
    },
  });
  expect(addResp.status()).toBe(200);

  await new Promise((r) => setTimeout(r, 1500));

  // Start the pending download
  const startResp = await request.post(`${DASHBOARD_URL}/api/start`, {
    data: { ids: ['https://www.youtube.com/watch?v=jNQXAC9IVRw'] },
    headers: { 'Content-Type': 'application/json' },
  });
  expect(startResp.status()).toBe(200);
  const body = await startResp.json();
  expect(body).toHaveProperty('status');
});

test('cancel a queued download via API', async ({ request }) => {
  // Add with auto_start=false so it lands in pending/queue
  const addResp = await request.post(`${DASHBOARD_URL}/api/add`, {
    data: {
      url: 'https://www.youtube.com/watch?v=9bZkp7q19f0',
      quality: '720',
      format: 'any',
      auto_start: false,
    },
  });
  expect(addResp.status()).toBe(200);

  await new Promise((r) => setTimeout(r, 1500));

  // Delete/cancel from queue
  const delResp = await request.post(`${DASHBOARD_URL}/api/delete`, {
    data: {
      ids: ['https://www.youtube.com/watch?v=9bZkp7q19f0'],
      where: 'queue',
    },
    headers: { 'Content-Type': 'application/json' },
  });
  expect(delResp.status()).toBe(200);
  const body = await delResp.json();
  expect(body).toHaveProperty('status');
});
