import { test, expect } from '@playwright/test';
import { setup, runAuthCodeFlow } from './helpers';

test.describe('Introspection and revocation', () => {
  test('introspects an active token, revokes it and sees it die', async ({ page }) => {
    const s = await setup(page, 'tokmgmt');
    await runAuthCodeFlow(page, s);

    const accessToken = await page.inputValue('#userinfo_token');
    expect(accessToken).not.toBe('');

    // The token-management section authenticates with the selected client.
    const clientOption = page.locator('#tm_client option').filter({ hasText: s.app.name }).first();
    await page.selectOption('#tm_client', (await clientOption.getAttribute('value'))!);

    await page.locator('#introspect_token').fill(accessToken);
    await page.getByRole('button', { name: 'Introspect' }).click();
    await expect(page.locator('#introspect_result')).toContainText('"active": true');

    await page.locator('#revoke_token').fill(accessToken);
    await page.getByRole('button', { name: 'Revoke' }).click();
    await expect(page.locator('#revoke_result')).toContainText('Revoked');

    await page.getByRole('button', { name: 'Introspect' }).click();
    await expect(page.locator('#introspect_result')).toContainText('"active": false');

    // The 401 carries its error only in the WWW-Authenticate header.
    await page.getByRole('button', { name: 'Get UserInfo' }).click();
    await expect(page.locator('#userinfo_result')).toContainText('HTTP 401');
    await expect(page.locator('#userinfo_result')).toContainText('invalid_token');
  });
});
