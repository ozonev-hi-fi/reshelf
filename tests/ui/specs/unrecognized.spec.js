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
  test('a release-without-artist folder shows up in the sidebar with its path, reason and children', async ({ page }) => {
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
  });

  test('a no-audio-files entry shows up in the sidebar the same way', async ({ page }) => {
    const seeded = seedSession('unrecognized-no-audio');
    addUnrecognizedEntry(seeded, {
      path: `${seeded.sourceFolderPath}\\Empty Folder`,
      reason: 'no-audio-files',
      children: [],
    });

    await gotoApp(page);
    await page.locator('.release-row').filter({ hasText: 'Empty Folder' }).click();

    await expect(page.locator('#unrecognized-panel')).toBeVisible();
    await expect(page.locator('#unrecognized-reason')).toHaveText('no-audio-files');
    await expect(page.locator('#unrecognized-children li')).toHaveCount(0);
  });
});
