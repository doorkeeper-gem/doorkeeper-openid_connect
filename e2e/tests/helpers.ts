import { Page, expect } from '@playwright/test';

export interface App {
  name: string;
  uid: string;
  secret: string;
}

export interface Setup {
  userId: string;
  userName: string;
  app: App;
}

export interface AuthorizeOptions {
  responseType?: 'code' | 'id_token' | 'id_token token';
  responseMode?: 'query' | 'fragment' | 'form_post';
  nonce?: boolean;
  pkce?: boolean;
  forceConsent?: boolean;
}

// Creates a user through the dashboard form and returns its id.
export async function createUser(page: Page, name: string): Promise<string> {
  await page.goto('/');
  const form = page.locator('form[action="/users"]');
  await form.locator('input[name="name"]').fill(name);
  await form.getByRole('button', { name: 'Create user' }).click();
  const row = page.getByRole('row').filter({ hasText: name }).first();
  await expect(row).toBeVisible();
  return (await row.locator('td').first().textContent())!.trim();
}

// Creates an OAuth application through the dashboard form and returns its
// uid/secret, scraped from the client <select> the dashboard renders.
export async function createApplication(page: Page, name: string): Promise<App> {
  await page.goto('/');
  const form = page.locator('form[action="/applications"]');
  await form.locator('input[name="name"]').fill(name);
  await form.getByRole('button', { name: 'Create application' }).click();
  const option = page.locator('#auth_client option').filter({ hasText: name }).first();
  await expect(option).toBeAttached();
  return {
    name,
    uid: (await option.getAttribute('data-uid'))!,
    secret: (await option.getAttribute('data-secret'))!,
  };
}

// Creates a user + application pair with names unique to this run.
export async function setup(page: Page, prefix: string): Promise<Setup> {
  const suffix = Date.now().toString(36);
  const userName = `${prefix}-user-${suffix}`;
  const userId = await createUser(page, userName);
  const app = await createApplication(page, `${prefix}-app-${suffix}`);
  return { userId, userName, app };
}

// Fills in the dashboard's authorization form and clicks "Authorize →".
// Returns the nonce value when one was requested.
export async function startAuthorization(
  page: Page,
  s: Setup,
  opts: AuthorizeOptions = {},
): Promise<{ nonce?: string }> {
  await page.goto('/');
  await page.selectOption('#current_user', s.userId);
  const clientOption = page.locator('#auth_client option').filter({ hasText: s.app.name }).first();
  await page.selectOption('#auth_client', (await clientOption.getAttribute('value'))!);
  await page.selectOption('#response_type', opts.responseType ?? 'code');
  if (opts.responseMode) await page.selectOption('#response_mode', opts.responseMode);

  let nonce: string | undefined;
  if (opts.nonce) {
    await page.check('#nonce_enabled');
    nonce = await page.inputValue('#nonce');
    expect(nonce).not.toBe('');
  }
  if (opts.pkce) {
    await page.check('#pkce_enabled');
    await expect(page.locator('#code_verifier')).not.toBeEmpty();
  }
  if (opts.forceConsent) await page.check('#force_consent');

  await page.getByRole('button', { name: 'Authorize →' }).click();
  return { nonce };
}

// Runs the full authorization code flow through the dashboard: authorize,
// bounce through /callback, exchange the code. Leaves the page on the
// dashboard with #exchange_result, #idtoken_payload and #userinfo_token set.
export async function runAuthCodeFlow(
  page: Page,
  s: Setup,
  opts: AuthorizeOptions = {},
): Promise<{ nonce?: string }> {
  const { nonce } = await startAuthorization(page, s, opts);
  await expect(page.locator('#authorize_result')).toContainText('"code"');
  await page.getByRole('button', { name: 'Exchange' }).click();
  await expect(page.locator('#exchange_result')).toContainText('"access_token"');
  await expect(page.locator('#exchange_result')).toContainText('"id_token"');
  return { nonce };
}

// Parses the decoded ID token payload the dashboard renders.
export async function idTokenPayload(page: Page): Promise<Record<string, unknown>> {
  await expect(page.locator('#idtoken_payload')).toContainText('"iss"');
  return JSON.parse((await page.locator('#idtoken_payload').textContent())!);
}
