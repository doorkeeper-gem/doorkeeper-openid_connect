import { test, expect } from '@playwright/test';
import { setup } from './helpers';

test.describe('Authorization error responses', () => {
  test('refuses a redirect_uri that does not match the client', async ({ page }) => {
    const s = await setup(page, 'err-redirect');
    const params = new URLSearchParams({
      client_id: s.app.uid,
      redirect_uri: 'http://evil.example/cb',
      response_type: 'code',
      scope: 'openid',
      current_user: s.userId,
    });
    await page.goto(`/oauth/authorize?${params}`);

    // The error must be rendered locally, never redirected to the evil host.
    expect(new URL(page.url()).host).toBe('localhost:3000');
    await expect(page.locator('body')).toContainText(/redirect uri/i);
  });

  test('rejects an unknown client_id', async ({ page }) => {
    const s = await setup(page, 'err-client');
    const params = new URLSearchParams({
      client_id: 'this-client-does-not-exist',
      redirect_uri: 'http://localhost:3000/callback',
      response_type: 'code',
      scope: 'openid',
      current_user: s.userId,
    });
    await page.goto(`/oauth/authorize?${params}`);

    expect(new URL(page.url()).host).toBe('localhost:3000');
    await expect(page.locator('body')).toContainText(/client/i);
  });
});
