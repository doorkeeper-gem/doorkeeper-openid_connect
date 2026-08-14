import { test, expect } from '@playwright/test';
import { setup, startAuthorization, runAuthCodeFlow } from './helpers';

test.describe('PKCE (S256)', () => {
  test('exchanges the code when the verifier matches', async ({ page }) => {
    const s = await setup(page, 'pkce');
    await runAuthCodeFlow(page, s, { pkce: true });
    await expect(page.locator('#exchange_result')).toContainText('"access_token"');
  });

  test('rejects the exchange with a missing or wrong verifier', async ({ page }) => {
    const s = await setup(page, 'pkce-neg');
    await startAuthorization(page, s, { pkce: true });
    await expect(page.locator('#authorize_result')).toContainText('"code"');

    // Missing verifier → invalid_request (missing required parameter).
    await page.locator('#tok_code_verifier').clear();
    await page.getByRole('button', { name: 'Exchange' }).click();
    await expect(page.locator('#exchange_result')).toContainText('invalid_request');

    // Wrong verifier → invalid_grant (challenge mismatch).
    await page.locator('#tok_code_verifier').fill('wrong-verifier-wrong-verifier-wrong-verifier');
    await page.getByRole('button', { name: 'Exchange' }).click();
    await expect(page.locator('#exchange_result')).toContainText('invalid_grant');
  });
});
