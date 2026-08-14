import { test, expect } from '@playwright/test';
import { setup, runAuthCodeFlow } from './helpers';

test.describe('response_mode=form_post', () => {
  test('delivers the code via POST and the exchange still succeeds', async ({ page }) => {
    const s = await setup(page, 'formpost');
    await runAuthCodeFlow(page, s, { responseMode: 'form_post', nonce: true });
    await expect(page.locator('#exchange_result')).toContainText('"id_token"');
  });
});
