// @ts-check
const { test, expect } = require('@playwright/test');
const { seedSession, gotoApp } = require('../helpers');

test.describe('loading and switching sessions', () => {
  test('auto-loads the most recently updated session with a proposal, no folder picker or session id shown', async ({ page }) => {
    const seeded = seedSession('load-auto');

    await gotoApp(page);

    await expect(page.locator('#session-status')).toContainText(seeded.sourceFolderPath, { timeout: 10_000 });
    await expect(page.locator('#session-status')).not.toContainText(seeded.sessionId);
    await expect(page.locator('.release-row')).toHaveCount(3);
  });

  test('reload loads the same session again', async ({ page }) => {
    const seeded = seedSession('load-reload');
    await gotoApp(page);
    await expect(page.locator('.release-row')).toHaveCount(3);

    await page.reload();

    await expect(page.locator('#session-status')).toContainText(seeded.sourceFolderPath);
    await expect(page.locator('.release-row')).toHaveCount(3);
  });

  test('with 2+ sessions, the Past sessions dropdown lists both, labeled by source root + date + stage (never the raw session id)', async ({ page }) => {
    const older = seedSession('load-history-older');
    await new Promise((r) => setTimeout(r, 1100)); // updatedAtUtc has 1-second string resolution
    const newer = seedSession('load-history-newer');

    await gotoApp(page);

    const history = page.locator('#session-history');
    await expect(history).toBeVisible();
    const select = page.locator('#session-history-select');
    const optionTexts = await select.locator('option').allTextContents();

    expect(optionTexts.some((t) => t.includes(older.sourceFolderPath) && t.includes('reviewed'))).toBe(true);
    expect(optionTexts.some((t) => t.includes(newer.sourceFolderPath) && t.includes('reviewed'))).toBe(true);
    for (const text of optionTexts) {
      expect(text).not.toContain(older.sessionId);
      expect(text).not.toContain(newer.sessionId);
    }
    // The newest session (by updatedAtUtc) is the one auto-loaded and pre-selected.
    await expect(select).toHaveValue(newer.sessionId);
  });

  test('switching sessions with unsaved changes prompts a confirm; cancelling keeps the current session', async ({ page }) => {
    seedSession('load-switch-older');
    await new Promise((r) => setTimeout(r, 1100));
    const current = seedSession('load-switch-current');

    await gotoApp(page);
    await page.locator('.release-row').first().click();
    await page.locator('#field-album').fill('Edited Album Name');

    let dialogSeen = false;
    page.once('dialog', async (dialog) => {
      dialogSeen = true;
      expect(dialog.message()).toMatch(/unsaved/i);
      await dialog.dismiss();
    });
    // Sessions list newest-first (Get-ReshelfSession's own sort) and the current session is
    // already selected at index 0 - index 1 is the older one, actually changing the <select>'s
    // value so a 'change' event fires at all.
    await page.locator('#session-history-select').selectOption({ index: 1 });

    expect(dialogSeen).toBe(true);
    await expect(page.locator('#session-history-select')).toHaveValue(current.sessionId);
  });
});
