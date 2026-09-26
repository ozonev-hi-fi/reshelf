// @ts-check
const { defineConfig, devices } = require('@playwright/test');

// The server under test is a single-threaded System.Net.HttpListener loop
// (scripts/Start-ReshelfUiServer.ps1) - one blocking GetContext() per request, so concurrent
// requests from parallel workers would just queue up behind each other anyway. workers: 1 makes
// that explicit instead of fighting it, and keeps every spec file's own seeded session data from
// racing another spec file's.
module.exports = defineConfig({
  testDir: './specs',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [['list']],
  timeout: 30_000,
  globalSetup: require.resolve('./global-setup.js'),
  globalTeardown: require.resolve('./global-teardown.js'),
  use: {
    // No static baseURL: global-setup.js picks a free port at runtime and writes it to
    // .tmp/state.json, which every spec reads via helpers.js's gotoApp() - a value here would be
    // frozen at config-load time, before global-setup has even chosen the port.
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'main',
      // testMatch's regex is checked against the full relative path (e.g.
      // "specs/server-down.spec.js"), never just the bare filename - a negative lookahead at the
      // start of the pattern doesn't exclude a later path segment, so this needs testIgnore
      // instead (confirmed empirically: the lookahead version let 'main' run this file too).
      testIgnore: /server-down\.spec\.js/,
      use: { ...devices['Desktop Chrome'] },
    },
    {
      // Kills the shared server, so it must run alone, after everything else that needs it.
      name: 'server-down',
      testMatch: /server-down\.spec\.js/,
      dependencies: ['main'],
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
