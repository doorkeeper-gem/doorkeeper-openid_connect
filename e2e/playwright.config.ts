import { defineConfig, devices } from '@playwright/test';

// The dummy app must listen on port 3000: applications created through the
// dashboard default to a http://localhost:3000/callback redirect URI.
export default defineConfig({
  testDir: './tests',
  timeout: 30_000,
  fullyParallel: false,
  workers: 1, // one shared server + one sqlite file
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    // A fresh DB every run; DATABASE_URL keeps db/development.sqlite3 untouched.
    command: 'rm -f db/e2e.sqlite3* && bin/rails db:schema:load && exec bin/rails server -p 3000',
    cwd: '../spec/dummy',
    url: 'http://localhost:3000/',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    stdout: 'pipe',
    stderr: 'pipe',
    env: { RAILS_ENV: 'development', DATABASE_URL: 'sqlite3:db/e2e.sqlite3' },
  },
});
