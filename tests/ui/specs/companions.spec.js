// @ts-check
const { test, expect } = require('@playwright/test');
const { seedSession, gotoApp } = require('../helpers');

// The "rich" release is seeded (seed-session.ps1) with 3 companions:
//   row 0 - nested photo (Scans/inner.jpg) - locked, include-only
//   row 1 - loose booklet (01 back.jpg) with a real proposedFileName ("Booklet 01 back.jpg")
//   row 2 - loose "other" (02 extra.jpg) with proposedFileName == null (the backfill case)
// and 2 ignored files: a playlist and an unused cue.

test.describe('companion (other) files', () => {
  test('shows one row per companion with Include/Before/Kind, and one row per ignored file, greyed out with its reason', async ({ page }) => {
    const seeded = seedSession('companions-table');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`).click();

    const rows = page.locator('#companion-table tbody tr.companion-row');
    await expect(rows).toHaveCount(3);
    await expect(rows.nth(0)).toContainText('Scans\\inner.jpg');
    await expect(rows.nth(0)).toContainText('photo');
    await expect(rows.nth(1)).toContainText('01 back.jpg');
    await expect(rows.nth(1)).toContainText('booklet');

    const ignoredRows = page.locator('#companion-table tbody tr.companion-row-ignored');
    await expect(ignoredRows).toHaveCount(2);
    await expect(ignoredRows.nth(0)).toContainText('Not copied: playlist-file');
    await expect(ignoredRows.nth(1)).toContainText('Not copied: cue-sheet-not-used');
  });

  test('a nested companion is name-locked (plain text, same relative path); a loose companion has an editable, pre-filled After field', async ({ page }) => {
    const seeded = seedSession('companions-nested-vs-loose');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`).click();

    const nestedRow = page.locator('#companion-table tbody tr.companion-row').nth(0);
    await expect(nestedRow.locator('td').nth(2).locator('input')).toHaveCount(0);
    await expect(nestedRow.locator('td').nth(2)).toContainText('Scans\\inner.jpg');

    const looseRow = page.locator('#companion-table tbody tr.companion-row').nth(1);
    const looseInput = looseRow.locator('td').nth(2).locator('input');
    await expect(looseInput).toHaveValue('Booklet 01 back.jpg');
  });

  test('a loose companion with no proposedFileName yet is backfilled with its original name (not left empty) and marks the release dirty', async ({ page }) => {
    const seeded = seedSession('companions-backfill');
    await gotoApp(page);
    const row = page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`);
    await row.click();

    const backfillRow = page.locator('#companion-table tbody tr.companion-row').nth(2);
    const input = backfillRow.locator('td').nth(2).locator('input');
    // Backfilled with the ORIGINAL name, not left empty - "Name is required" specifically must
    // not appear. The seeded original name ('02 extra.jpg') still starts with a digit though, so
    // "Must start with a letter" legitimately fires - the checklist this replaces only ever
    // promised the empty-name warning wouldn't appear, not that renaming becomes unnecessary.
    await expect(input).toHaveValue('02 extra.jpg');
    await expect(backfillRow.locator('.companion-warning')).not.toHaveText('Name is required.');
    await expect(backfillRow.locator('.companion-warning')).toHaveText('Must start with a letter.');
    // Backfilling silently changed in-memory state (so the fill gets saved) - this is real app
    // behavior (renderCompanionTable's markDirty call in app.js), not something the user did.
    await expect(row).toHaveClass(/unsaved/);
  });

  test('editing a loose companion name keeps focus while typing and marks the release dirty', async ({ page }) => {
    const seeded = seedSession('companions-edit-name');
    await gotoApp(page);
    const row = page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`);
    await row.click();

    const looseInput = page.locator('#companion-table tbody tr.companion-row').nth(1).locator('td').nth(2).locator('input');
    await looseInput.fill('Booklet Back Cover.jpg');

    await expect(looseInput).toHaveValue('Booklet Back Cover.jpg');
    await expect(row).toHaveClass(/unsaved/);
  });

  test('clearing a loose name, or one starting with a digit/symbol, shows an inline warning that does not block saving', async ({ page }) => {
    const seeded = seedSession('companions-warn-invalid');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`).click();

    const row = page.locator('#companion-table tbody tr.companion-row').nth(1);
    const input = row.locator('td').nth(2).locator('input');
    const warning = row.locator('.companion-warning');

    await input.fill('');
    await expect(warning).toHaveText('Name is required.');

    await input.fill('1 test.jpg');
    await expect(warning).toHaveText('Must start with a letter.');

    // Not blocked - Save is still usable (this suite doesn't need to actually click Save here;
    // Implementation's own equivalent validation is exercised for real in the end-to-end test
    // below).
    await expect(page.locator('#save-btn')).toBeEnabled();
  });

  test('a loose name matching another included companion\'s name shows a collision warning', async ({ page }) => {
    // A track-vs-companion name collision ("Same name as a track file.") isn't reachable through
    // the real UI edit flow: deriveTrackFileName (app.js) always keeps a track's own leading "NN "
    // prefix, so a track's proposedFileName can never become letter-first, and a loose companion
    // name that collides with it would already be rejected for not starting with a letter first
    // (manifesto SS4.5). That exact guard is covered directly at the module level instead, in
    // Tagger.Implementation.Tests.ps1's Invoke-TaggerReleaseStaging Describe.
    const seeded = seedSession('companions-warn-collision');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`).click();

    const looseRow1 = page.locator('#companion-table tbody tr.companion-row').nth(1);
    const looseRow2 = page.locator('#companion-table tbody tr.companion-row').nth(2);

    await looseRow1.locator('td').nth(2).locator('input').fill('Same Extra.jpg');
    await looseRow2.locator('td').nth(2).locator('input').fill('Same Extra.jpg');
    await expect(looseRow2.locator('.companion-warning')).toHaveText('Same name as another included file.');
  });

  test('unchecking Include suppresses the warning even with a bad name; re-checking brings it back', async ({ page }) => {
    const seeded = seedSession('companions-warn-excluded');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`).click();

    const row = page.locator('#companion-table tbody tr.companion-row').nth(1);
    const input = row.locator('td').nth(2).locator('input');
    const includeCheckbox = row.locator('td').nth(0).locator('input[type="checkbox"]');
    const warning = row.locator('.companion-warning');

    await input.fill('1 bad name.jpg');
    await expect(warning).toHaveText('Must start with a letter.');

    await includeCheckbox.uncheck();
    await expect(warning).toBeHidden();

    await includeCheckbox.check();
    await expect(warning).toHaveText('Must start with a letter.');
  });

  test('a release with no companion or ignored files shows "No other files" instead of the table', async ({ page }) => {
    const seeded = seedSession('companions-empty-state');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.minimal.stableKey}"]`).click();

    await expect(page.locator('#companion-table')).toBeHidden();
    await expect(page.locator('#companion-empty')).toBeVisible();
    await expect(page.locator('#companion-empty')).toHaveText('No other files');
  });

  test('end-to-end: renaming a loose companion and excluding a nested one, then Save + apply, produces the expected target layout', async ({ page }) => {
    const { runApply } = require('../helpers');
    const seeded = seedSession('companions-e2e-apply');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`).click();

    const nestedRow = page.locator('#companion-table tbody tr.companion-row').nth(0);
    const looseRow = page.locator('#companion-table tbody tr.companion-row').nth(1);
    const backfillRow = page.locator('#companion-table tbody tr.companion-row').nth(2);

    await nestedRow.locator('td').nth(0).locator('input[type="checkbox"]').uncheck();
    await looseRow.locator('td').nth(2).locator('input').fill('Renamed Back Cover.jpg');
    // The backfilled companion ("02 extra.jpg", see the backfill test above) is real-behavior
    // pre-filled with its ORIGINAL, still digit-prefixed name - selecting the release marked it
    // dirty and left its "Must start with a letter" warning up, same as a real reviewer would see.
    // A real apply run enforces that guard (Invoke-TaggerReleaseStaging,
    // Tagger.Implementation.psm1) and fails the whole release if it's ignored - completing the
    // rename here is what "finished reviewing" actually looks like, not an optional nicety.
    await backfillRow.locator('td').nth(2).locator('input').fill('Extra Booklet Page.jpg');
    await expect(backfillRow.locator('.companion-warning')).toBeHidden();
    // Also resolve the ambiguous match and approve, since apply (without -IncludeUnresolved in
    // real usage) would otherwise skip an unresolved release - this test passes -IncludeUnresolved
    // to runApply anyway (see helpers.js), but approving here matches how a person would actually
    // finish reviewing before applying.
    await page.locator('.discogs-candidate').nth(0).locator('input[type="radio"]').check();
    await page.locator('#approve-checkbox').check();
    await page.locator('#save-btn').click();
    await expect(page.locator('#save-status')).toContainText('Saved');

    const result = runApply(seeded.sessionId);
    // All 3 seeded releases in this session apply (only an ambiguous-AND-unresolved release is
    // skipped by default - see plan/08 - and this test resolved+approved "rich"; "minimal" and
    // "empty" were never ambiguous to begin with), so all 3 succeed, not just the one under test.
    expect(result.Applied).toBe(3);
    expect(result.Failed ?? 0).toBe(0);

    const fs = require('fs');
    const path = require('path');
    const { getState } = require('../helpers');
    const targetReleaseDir = path.join(getState().targetRoot, 'Aurora Fields', `${seeded.rich.year} ${seeded.rich.album}`);

    expect(fs.existsSync(path.join(targetReleaseDir, 'Renamed Back Cover.jpg'))).toBe(true);
    expect(fs.existsSync(path.join(targetReleaseDir, 'Extra Booklet Page.jpg'))).toBe(true);
    expect(fs.existsSync(path.join(targetReleaseDir, 'Scans', 'inner.jpg'))).toBe(false);
    expect(fs.existsSync(path.join(targetReleaseDir, '01 Track.flac'))).toBe(true);
    expect(fs.existsSync(path.join(targetReleaseDir, '02 Track.flac'))).toBe(true);
  });
});
