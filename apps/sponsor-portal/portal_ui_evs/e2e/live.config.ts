import { defineConfig, devices } from '@playwright/test';

// Runs the tests-live/ specs against the LIVE local-stack portal (:8080,
// PORTAL_AUTH_MODE=session) instead of the prebuilt :8010 bundle the main
// config serves. No webServer block — the stack must already be up:
//   PORTAL_AUTH_MODE=session ./deployment/local-stack/local-stack portal
//   npx playwright test --config=live.config.ts
export default defineConfig({
  testDir: './tests-live',
  timeout: 120_000,
  expect: { timeout: 20_000 },
  fullyParallel: false,
  retries: 0,
  reporter: [['list']],
  use: { baseURL: 'http://localhost:8080', trace: 'on-first-retry' },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
