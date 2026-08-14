import { test, expect } from '@playwright/test';
import { setup, startAuthorization } from './helpers';

// force_consent=1 disables the development-mode skip_authorization, so the
// real Doorkeeper consent screen renders. Each test runs in a fresh browser
// context, so the session-stored current_user never leaks between tests.
test.describe('Consent screen', () => {
  test('approving issues a code that can be exchanged', async ({ page }) => {
    const s = await setup(page, 'consent-ok');
    await startAuthorization(page, s, { forceConsent: true });

    await expect(page.locator('body')).toContainText('Authorization required');
    await expect(page.locator('body')).toContainText(s.app.name);

    await page.getByRole('button', { name: 'Authorize' }).click();

    await expect(page.locator('#authorize_result')).toContainText('"code"');
    await page.getByRole('button', { name: 'Exchange' }).click();
    await expect(page.locator('#exchange_result')).toContainText('"access_token"');
  });

  test('denying redirects back with access_denied', async ({ page }) => {
    const s = await setup(page, 'consent-ng');
    await startAuthorization(page, s, { forceConsent: true });

    await expect(page.locator('body')).toContainText('Authorization required');
    await page.getByRole('button', { name: 'Deny' }).click();

    await expect(page.locator('#authorize_result')).toContainText('access_denied');
    await expect(page.locator('#authorize_result')).not.toContainText('"code"');
  });
});
