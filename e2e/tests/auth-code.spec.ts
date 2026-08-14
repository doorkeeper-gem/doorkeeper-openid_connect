import { test, expect } from '@playwright/test';
import { setup, runAuthCodeFlow, idTokenPayload } from './helpers';

test.describe('Authorization code flow', () => {
  test('issues a code, exchanges it for tokens and serves userinfo', async ({ page }) => {
    const s = await setup(page, 'authcode');
    const { nonce } = await runAuthCodeFlow(page, s, { nonce: true });

    const payload = await idTokenPayload(page);
    expect(payload.iss).toBe('dummy');
    expect(payload.sub).toBe(s.userId);
    expect(payload.aud).toBe(s.app.uid);
    expect(payload.nonce).toBe(nonce);
    expect(typeof payload.exp).toBe('number');
    expect(typeof payload.iat).toBe('number');
    expect(payload.exp as number).toBeGreaterThan(payload.iat as number);
    // Custom claims: without an explicit `response:` option they are
    // userinfo-only, so the ID token carries just the id_token-targeted ones.
    expect(payload).not.toHaveProperty('name');
    expect(payload).toHaveProperty('id_token_response');
    expect(payload).toHaveProperty('both_responses');
    expect(payload).not.toHaveProperty('user_info_response');

    await page.getByRole('button', { name: 'Get UserInfo' }).click();
    const userinfo = page.locator('#userinfo_result');
    await expect(userinfo).toContainText(`"sub": "${s.userId}"`);
    // `name` defaults to the profile scope, which this client was not granted.
    await expect(userinfo).not.toContainText('"name"');
    await expect(userinfo).toContainText('"variable_name": "openid-name"');
    await expect(userinfo).toContainText('"user_info_response": "user_info"');
    await expect(userinfo).toContainText('"both_responses": "both"');
    await expect(userinfo).not.toContainText('"id_token_response"');
  });

  test('rejects an already used authorization code', async ({ page }) => {
    const s = await setup(page, 'authcode-reuse');
    await runAuthCodeFlow(page, s);

    // The code was consumed by the first exchange; replaying it must fail.
    await page.getByRole('button', { name: 'Exchange' }).click();
    await expect(page.locator('#exchange_result')).toContainText('invalid_grant');
  });
});
