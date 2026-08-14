import { test, expect } from '@playwright/test';
import { setup, startAuthorization, idTokenPayload } from './helpers';

test.describe('Implicit flow (id_token token)', () => {
  test('returns tokens in the fragment and binds them with at_hash', async ({ page }) => {
    const s = await setup(page, 'implicit');
    const { nonce } = await startAuthorization(page, s, {
      responseType: 'id_token token',
      nonce: true,
    });

    // The callback page relays the fragment parameters back to the dashboard.
    const result = page.locator('#authorize_result');
    await expect(result).toContainText('"access_token"');
    await expect(result).toContainText('"id_token"');
    await expect(result).not.toContainText('"code"');

    const payload = await idTokenPayload(page);
    expect(payload.iss).toBe('dummy');
    expect(payload.sub).toBe(s.userId);
    expect(payload.aud).toBe(s.app.uid);
    expect(payload.nonce).toBe(nonce);
    expect(payload.at_hash).toBeTruthy();

    // The fragment access token is auto-filled; it must work against userinfo.
    await page.getByRole('button', { name: 'Get UserInfo' }).click();
    await expect(page.locator('#userinfo_result')).toContainText(`"sub": "${s.userId}"`);
  });
});
