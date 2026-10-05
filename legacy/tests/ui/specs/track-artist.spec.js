// @ts-check
const { test, expect } = require('@playwright/test');
const { seedSession, gotoApp } = require('../helpers');
const fs = require('fs');

// The "compilation" release is seeded (seed-session.ps1) as a Various-Artists compilation:
//   Album Artist "Various", isCompilation true, 2 tracks each with its own Artist
//   ("First Act" / "Second Act").

test.describe('per-track Artist and Compilation flag', () => {
  test("the track table shows each track's own Artist, and Album Artist/Compilation reflect the release", async ({ page }) => {
    const seeded = seedSession('track-artist-show');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.compilation.stableKey}"]`).click();

    await expect(page.locator('#field-artist')).toHaveValue('Various');
    await expect(page.locator('#field-compilation')).toBeChecked();

    const trackRows = page.locator('#track-fields-table tbody tr');
    await expect(trackRows.nth(0).locator('input[data-field="artist"]')).toHaveValue('First Act');
    await expect(trackRows.nth(1).locator('input[data-field="artist"]')).toHaveValue('Second Act');
  });

  test("editing one track's Artist saves only that track, leaving the other and Album Artist unchanged", async ({ page }) => {
    const seeded = seedSession('track-artist-edit-one');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.compilation.stableKey}"]`).click();

    const trackRows = page.locator('#track-fields-table tbody tr');
    await trackRows.nth(0).locator('input[data-field="artist"]').fill('Renamed Act');

    await page.locator('#save-btn').click();
    await expect(page.locator('#save-status')).toContainText('Saved');

    const onDisk = JSON.parse(fs.readFileSync(seeded.proposalPath, 'utf-8'));
    const release = onDisk.artists[0].releases.find((r) => r.stableKey === seeded.compilation.stableKey);
    expect(release.tracks[0].tags.artist).toBe('Renamed Act');
    expect(release.tracks[1].tags.artist).toBe('Second Act');
    expect(release.tracks[0].tags.albumArtist).toBe('Various');
    expect(release.tracks[1].tags.albumArtist).toBe('Various');

    await page.reload();
    await page.locator(`.release-row[data-stable-key="${seeded.compilation.stableKey}"]`).click();
    await expect(trackRows.nth(0).locator('input[data-field="artist"]')).toHaveValue('Renamed Act');
    await expect(trackRows.nth(1).locator('input[data-field="artist"]')).toHaveValue('Second Act');
  });

  test("editing Album Artist keeps each track's own custom Artist unchanged", async ({ page }) => {
    const seeded = seedSession('track-artist-albumartist-edit');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.compilation.stableKey}"]`).click();

    await page.locator('#field-artist').fill('VA');

    const trackRows = page.locator('#track-fields-table tbody tr');
    await expect(trackRows.nth(0).locator('input[data-field="artist"]')).toHaveValue('First Act');
    await expect(trackRows.nth(1).locator('input[data-field="artist"]')).toHaveValue('Second Act');

    await page.locator('#save-btn').click();
    await expect(page.locator('#save-status')).toContainText('Saved');

    const onDisk = JSON.parse(fs.readFileSync(seeded.proposalPath, 'utf-8'));
    const release = onDisk.artists[0].releases.find((r) => r.stableKey === seeded.compilation.stableKey);
    expect(release.tracks[0].tags.albumArtist).toBe('VA');
    expect(release.tracks[1].tags.albumArtist).toBe('VA');
    expect(release.tracks[0].tags.artist).toBe('First Act');
    expect(release.tracks[1].tags.artist).toBe('Second Act');
  });

  test('unchecking Compilation clears isCompilation on the release and every track', async ({ page }) => {
    const seeded = seedSession('track-artist-compilation-toggle');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.compilation.stableKey}"]`).click();

    await page.locator('#field-compilation').uncheck();
    await page.locator('#save-btn').click();
    await expect(page.locator('#save-status')).toContainText('Saved');

    const onDisk = JSON.parse(fs.readFileSync(seeded.proposalPath, 'utf-8'));
    const release = onDisk.artists[0].releases.find((r) => r.stableKey === seeded.compilation.stableKey);
    expect(release.proposed.isCompilation).toBe(false);
    expect(release.tracks[0].tags.isCompilation).toBe(false);
    expect(release.tracks[1].tags.isCompilation).toBe(false);
  });

  test("clearing a track's Artist field falls back to Album Artist on blur", async ({ page }) => {
    const seeded = seedSession('track-artist-empty-fallback');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.compilation.stableKey}"]`).click();

    const firstArtistInput = page.locator('#track-fields-table tbody tr').first().locator('input[data-field="artist"]');
    await firstArtistInput.fill('');
    // A blur (not an input event) is what triggers the empty-value fallback.
    await page.locator('#field-album').focus();

    await expect(firstArtistInput).toHaveValue('Various');
  });
});
