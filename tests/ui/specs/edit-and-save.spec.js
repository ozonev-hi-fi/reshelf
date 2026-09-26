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

  test('a Track number edit updates the file-name number (missing track keeps its gap) and survives Save and reload', async ({ page }) => {
    const seeded = seedSession('edit-track-number');
    await gotoApp(page);
    const selectRich = () => page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`).click();
    await selectRich();

    // Like a real release whose source is missing track 1: tracks are really 2 and 3.
    const trackRows = page.locator('#track-fields-table tbody tr');
    await trackRows.nth(1).locator('input[type="number"]').nth(1).fill('3');
    await trackRows.nth(0).locator('input[type="number"]').nth(1).fill('2');

    const afterCell = (n) => page.locator('#before-after-table tbody tr').nth(n).locator('td').last();
    await expect(afterCell(1)).toHaveText('02 First Track.flac');
    await expect(afterCell(2)).toHaveText('03 Second Track.flac');

    await page.locator('#save-btn').click();
    await expect(page.locator('#save-status')).toContainText('Saved');

    const onDisk = JSON.parse(fs.readFileSync(seeded.proposalPath, 'utf-8'));
    const release = onDisk.artists[0].releases.find((r) => r.stableKey === seeded.rich.stableKey);
    expect(release.tracks.map((t) => t.proposedFileName)).toEqual(['02 First Track.flac', '03 Second Track.flac']);
    expect(release.tracks.map((t) => t.tags.track)).toEqual([2, 3]);

    await page.reload();
    await selectRich();
    await expect(afterCell(1)).toHaveText('02 First Track.flac');
    await expect(afterCell(2)).toHaveText('03 Second Track.flac');
  });

  test('on a multi-disc release, a later disc\'s file numbers start after the highest Track of earlier discs', async ({ page }) => {
    const seeded = seedSession('edit-multi-disc-number');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`).click();

    const trackRows = page.locator('#track-fields-table tbody tr');
    const discInput = (n) => trackRows.nth(n).locator('input[type="number"]').nth(0);
    const trackInput = (n) => trackRows.nth(n).locator('input[type="number"]').nth(1);
    await discInput(1).fill('2');
    await trackInput(1).fill('1');

    const afterCell = (n) => page.locator('#before-after-table tbody tr').nth(n).locator('td').last();
    await expect(afterCell(1)).toHaveText('01 First Track.flac');
    await expect(afterCell(2)).toHaveText('02 Second Track.flac');

    // Disc 1 now has 3 tracks (1 and 2 missing on the source), so disc 2 starts at 04.
    await trackInput(0).fill('3');
    await expect(afterCell(1)).toHaveText('03 First Track.flac');
    await expect(afterCell(2)).toHaveText('04 Second Track.flac');
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
