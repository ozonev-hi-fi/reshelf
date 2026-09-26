// @ts-check
const { test, expect } = require('@playwright/test');
const { seedSession, gotoApp, getState } = require('../helpers');
const fs = require('fs');
const path = require('path');

test.describe('editing and saving', () => {
  test('editing a field marks the release dirty (dot + unsaved counts), Save clears both, and the edit persists on reload', async ({ page }) => {
    const seeded = seedSession('edit-save');
    await gotoApp(page);

    // Uses the "minimal" release (no companions), not "rich" - a loose companion with no
    // proposedFileName yet (the backfill case, see companions.spec.js) marks its release dirty
    // the moment it's rendered, which would make the "nothing dirty yet" assertion below flaky.
    const row = page.locator(`.release-row[data-stable-key="${seeded.minimal.stableKey}"]`);
    await row.click();
    await expect(page.locator('#unsaved-count')).toHaveText('');
    await expect(row).not.toHaveClass(/unsaved/);

    await page.locator('#field-album').fill('Quiet Interlude (Edited)');

    await expect(row).toHaveClass(/unsaved/);
    await expect(page.locator('#unsaved-count')).toHaveText('1 unsaved change');
    await expect(page.locator('#unsaved-count-top')).toHaveText('1 unsaved change');

    await page.locator('#save-btn').click();

    await expect(page.locator('#save-status')).toContainText('Saved');
    await expect(row).not.toHaveClass(/unsaved/);
    await expect(page.locator('#unsaved-count')).toHaveText('');
    await expect(page.locator('#unsaved-count-top')).toHaveText('');

    // Persisted on disk, not just in the page's in-memory state.
    const onDisk = JSON.parse(fs.readFileSync(seeded.proposalPath, 'utf-8'));
    const release = onDisk.artists[0].releases.find((r) => r.stableKey === seeded.minimal.stableKey);
    expect(release.proposed.album).toBe('Quiet Interlude (Edited)');

    // A backup of the PRE-save content exists alongside proposal.json.
    const backupPath = path.join(path.dirname(seeded.proposalPath), 'proposal.backup.json');
    expect(fs.existsSync(backupPath)).toBe(true);
    const backup = JSON.parse(fs.readFileSync(backupPath, 'utf-8'));
    const backupRelease = backup.artists[0].releases.find((r) => r.stableKey === seeded.minimal.stableKey);
    expect(backupRelease.proposed.album).toBe(seeded.minimal.album);

    await page.reload();
    await page.locator(`.release-row[data-stable-key="${seeded.minimal.stableKey}"]`).click();
    await expect(page.locator('#field-album')).toHaveValue('Quiet Interlude (Edited)');
  });

  test('a track title edit updates the proposed file name in the Before/After table, preserving the numeric prefix', async ({ page }) => {
    const seeded = seedSession('edit-track-title');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`).click();

    const firstTitleInput = page.locator('#track-fields-table tbody tr').first().locator('input[type="text"]');
    await firstTitleInput.fill('Renamed Opener');

    const afterCell = page.locator('#before-after-table tbody tr').nth(1).locator('td').nth(1);
    await expect(afterCell).toHaveText('01 Renamed Opener.flac');
  });

  test('making an edit then trying to leave the page triggers the browser\'s own unsaved-changes prompt', async ({ page }) => {
    const seeded = seedSession('edit-beforeunload');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`).click();
    await page.locator('#field-album').fill('Unsaved Edit');

    // beforeunload's own dialog can't be asserted on directly in Chromium/Playwright, but the
    // handler only calls e.preventDefault() when isDirty() - triggering navigation away and
    // confirming a dialog fires proves the guard is wired, without needing to read its (browser-
    // controlled, unconfigurable) text.
    let dialogFired = false;
    page.once('dialog', async (dialog) => {
      dialogFired = true;
      await dialog.dismiss();
    });
    await page.goto(getState().baseURL + '/?other=1').catch(() => {});

    expect(dialogFired).toBe(true);
  });
});
