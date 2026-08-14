import { test, expect } from '@playwright/test';

test.describe('Discovery', () => {
  test('serves the openid-configuration document', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('button', { name: 'GET openid-configuration' }).click();

    const pre = page.locator('#disc_config');
    await expect(pre).toContainText('"issuer": "dummy"');

    const config = JSON.parse((await pre.textContent())!);
    expect(config.authorization_endpoint).toBe('http://localhost:3000/oauth/authorize');
    expect(config.token_endpoint).toBe('http://localhost:3000/oauth/token');
    expect(config.userinfo_endpoint).toBe('http://localhost:3000/oauth/userinfo');
    expect(config.jwks_uri).toBe('http://localhost:3000/oauth/discovery/keys');
    expect(config.scopes_supported).toContain('openid');
    expect(config.response_types_supported).toEqual(
      expect.arrayContaining(['code', 'id_token', 'id_token token']),
    );
    expect(config.code_challenge_methods_supported).toContain('S256');
    expect(config.id_token_signing_alg_values_supported).toEqual(['RS256']);
    expect(config.subject_types_supported).toEqual(['public']);
  });

  test('serves the JWKS with the RSA public key only', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('button', { name: 'GET jwks (discovery/keys)' }).click();

    const pre = page.locator('#disc_keys');
    await expect(pre).toContainText('"kty": "RSA"');

    const jwks = JSON.parse((await pre.textContent())!);
    expect(jwks.keys).toHaveLength(1);
    const key = jwks.keys[0];
    expect(key.use).toBe('sig');
    expect(key.alg).toBe('RS256');
    expect(key.kid).toBeTruthy();
    expect(key.n).toBeTruthy();
    // Never expose private key material.
    expect(key).not.toHaveProperty('d');
    expect(key).not.toHaveProperty('p');
    expect(key).not.toHaveProperty('q');
  });
});
