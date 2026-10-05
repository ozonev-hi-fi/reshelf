// @ts-check
const { test, expect } = require('@playwright/test');
const { execFileSync } = require('child_process');
const { seedSession, gotoApp, getState } = require('../helpers');

// Runs in its own Playwright project (see playwright.config.js), after every other spec, since it
// deliberately kills the one shared server the rest of the suite depends on. Once the server is
// dead, a full page.reload()/goto() can't be used to test the "retry" path either - the server
// also serves the static page itself, so a real navigation would just fail outright with its own
// browser-level network error, never reaching app.js's own error handling. Every assertion here
// instead uses a fetch() the already-loaded page makes on its own, matching what a person actually
// sees: the page they have open stops working, not a blank reload.
test.describe('server stopped mid-session', () => {
  test('Save and a live session switch both show a visible error/retry message, not a silent failure', async ({ page }) => {
    seedSession('server-down-older');
    await new Promise((r) => setTimeout(r, 1100));
    const current = seedSession('server-down-current');

    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${current.rich.stableKey}"]`).click();
    await page.locator('#field-album').fill('Edit before server dies');

    const state = getState();
    execFileSync('taskkill', ['/PID', String(state.serverPid), '/T', '/F'], { stdio: 'ignore' });

    await page.locator('#save-btn').click();
    await expect(page.locator('#save-status')).toContainText('Save failed', { timeout: 10_000 });

    // Switching sessions still goes through the same isDirty() confirm as when the server is up -
    // accept it, then the switch's own fetchJson() call is what actually fails.
    page.once('dialog', (dialog) => dialog.accept());
    await page.locator('#session-history-select').selectOption({ index: 1 });

    await expect(page.locator('#retry-btn')).toBeVisible({ timeout: 10_000 });
    await expect(page.locator('#session-status')).toContainText('Error');
  });
});
