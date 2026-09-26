// @ts-check
const { test, expect } = require('@playwright/test');
const fs = require('fs');
const { seedSession, gotoApp } = require('../helpers');

/** Adds one unrecognized[] entry directly to a just-seeded session's proposal.json. */
function addUnrecognizedEntry(seeded, entry) {
  const doc = JSON.parse(fs.readFileSync(seeded.proposalPath, 'utf-8'));
  doc.unrecognized.push(entry);
  fs.writeFileSync(seeded.proposalPath, JSON.stringify(doc, null, 2));
}

test.describe('unrecognized folders', () => {
  test('a release-without-artist folder shows up in the sidebar and offers a ready "artist" override', async ({ page }) => {
    const seeded = seedSession('unrecognized-artist');
    const entryPath = `${seeded.sourceFolderPath}\\edbl`;
    addUnrecognizedEntry(seeded, {
      path: entryPath,
      reason: 'release-without-artist-suspected',
      children: ['edbl - minibeats, vol.1 - 01 Track.flac', 'edbl - minibeats, vol.1 - 02 Track.flac'],
    });

    await gotoApp(page);

    const row = page.locator('.release-row').filter({ hasText: 'edbl' });
    await expect(row.locator('.badge')).toHaveText('unrecognized');
    await row.click();

    await expect(page.locator('#unrecognized-panel')).toBeVisible();
    await expect(page.locator('#detail-panel')).toBeHidden();
    await expect(page.locator('#unrecognized-path')).toHaveText(entryPath);
    await expect(page.locator('#unrecognized-reason')).toHaveText('release-without-artist-suspected');
    await expect(page.locator('#unrecognized-children li')).toHaveCount(2);

    // Kind defaults to "artist" for this reason, with the artist name pre-filled from the folder.
    await expect(page.locator('#unrecognized-override-kind')).toHaveValue('artist');
    const json = JSON.parse(await page.locator('#unrecognized-override-json').textContent());
    expect(json.kind).toBe('artist');
    expect(json.artistName).toBe('edbl');
    expect(json.relativePath).toBe('edbl');
  });

  test('a grouping-folder-suspected entry defaults to kind "grouping" with no artist name field', async ({ page }) => {
    const seeded = seedSession('unrecognized-grouping');
    addUnrecognizedEntry(seeded, {
      path: `${seeded.sourceFolderPath}\\Some Collective`,
      reason: 'grouping-folder-suspected',
      children: ['Member One', 'Member Two'],
    });

    await gotoApp(page);
    await page.locator('.release-row').filter({ hasText: 'Some Collective' }).click();

    await expect(page.locator('#unrecognized-override-kind')).toHaveValue('grouping');
    await expect(page.locator('#unrecognized-artist-name-field')).toBeHidden();
    const json = JSON.parse(await page.locator('#unrecognized-override-json').textContent());
    expect(json.kind).toBe('grouping');
    expect(json.artistName).toBeNull();
  });

  test('changing the kind dropdown updates the generated JSON live', async ({ page }) => {
    const seeded = seedSession('unrecognized-change-kind');
    addUnrecognizedEntry(seeded, {
      path: `${seeded.sourceFolderPath}\\Mystery Folder`,
      reason: 'release-without-artist-suspected',
      children: ['track.flac'],
    });

    await gotoApp(page);
    await page.locator('.release-row').filter({ hasText: 'Mystery Folder' }).click();

    await page.locator('#unrecognized-override-kind').selectOption('category');
    const json = JSON.parse(await page.locator('#unrecognized-override-json').textContent());
    expect(json.kind).toBe('category');
  });
});
