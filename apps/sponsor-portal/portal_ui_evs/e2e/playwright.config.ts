import { defineConfig, devices } from '@playwright/test';

// Serves the prebuilt portal_ui_evs web bundle (../build/web). The bundle is
// built pointed at the live portal_server_evs (PORTAL_SERVER_URL=:8084) which
// must already be running (Postgres-backed). See e2e/README or run-link-e2e.sh.
export default defineConfig({
  testDir: './tests',
  timeout: 120_000,
  expect: { timeout: 20_000 },
  fullyParallel: false,
  retries: 0,
  reporter: [['list']],
  use: { baseURL: 'http://localhost:8010', trace: 'on-first-retry' },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    command: 'npx --yes serve ../build/web -l 8010 --no-clipboard -s',
    url: 'http://localhost:8010',
    reuseExistingServer: true,
    timeout: 60_000,
  },
});
