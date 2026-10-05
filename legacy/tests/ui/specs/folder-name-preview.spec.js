// @ts-check
const { test, expect } = require('@playwright/test');
const { seedSession, gotoApp } = require('../helpers');

test.describe('live folder name preview', () => {
  test('editing Artist/Album/Year updates the Artist Folder/Release Folder fields and the After cell', async ({ page }) => {
    const seeded = seedSession('folder-preview');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.minimal.stableKey}"]`).click();

    await page.locator('#field-artist').fill('aoki takamasa');
    await page.locator('#field-album').fill('Indigo Rose');
    await page.locator('#field-year').fill('2002');

    await expect(page.locator('#field-artist-folder')).toHaveValue('aoki takamasa');
    await expect(page.locator('#field-release-folder')).toHaveValue('2002 Indigo Rose');

    const folderAfterCell = page.locator('#before-after-table tbody tr').first().locator('td').nth(1);
    await expect(folderAfterCell).toHaveText('aoki takamasa\\2002 Indigo Rose');
  });

  test('editing the Release Folder Name field by hand also updates the After cell', async ({ page }) => {
    const seeded = seedSession('folder-preview-manual');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.minimal.stableKey}"]`).click();

    await page.locator('#field-release-folder').fill('Custom Folder Name');

    const folderAfterCell = page.locator('#before-after-table tbody tr').first().locator('td').nth(1);
    await expect(folderAfterCell).toContainText('Custom Folder Name');
  });

  test('a later Artist/Album/Year edit overwrites a hand-typed folder name', async ({ page }) => {
    const seeded = seedSession('folder-preview-overwrite');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.minimal.stableKey}"]`).click();

    await page.locator('#field-release-folder').fill('Custom Folder Name');
    await page.locator('#field-album').fill('Another Album');

    await expect(page.locator('#field-release-folder')).not.toHaveValue('Custom Folder Name');
    await expect(page.locator('#field-release-folder')).toHaveValue(/Another Album/);
  });

  test('invalid filesystem characters in Artist/Album are sanitized in the folder name preview', async ({ page }) => {
    const seeded = seedSession('folder-preview-sanitize');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.minimal.stableKey}"]`).click();

    await page.locator('#field-artist').fill('AC/DC');
    await expect(page.locator('#field-artist-folder')).toHaveValue('AC_DC');
  });
});
