// @ts-check
const { test, expect } = require('@playwright/test');
const path = require('path');
const { seedSession, gotoApp } = require('../helpers');

test.describe('cover art', () => {
  test('shows original size and embedded size for an oversized cover, "(embedded as is)" for one already under the limit', async ({ page }) => {
    const seeded = seedSession('covers-sizes');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`).click();

    const candidates = page.locator('.cover-candidate');
    await expect(candidates).toHaveCount(3);

    // 3120x3200 at a 600px target: scale = min(1, 600/3120, 600/3200) = 600/3200 = 0.1875 ->
    // 3120*0.1875 = 585, 3200*0.1875 = 600 - matches the exact example from the (now-retired)
    // manual checklist and computeEmbeddedCoverSize's own math in app.js.
    await expect(candidates.nth(0).locator('.cover-size')).toHaveText('3120x3200 → 585x600 embedded');
    // 500x500 is already <= 600 on both sides - shown as-is, not "500x500 -> 500x500".
    await expect(candidates.nth(1).locator('.cover-size')).toHaveText('500x500 (embedded as is)');
  });

  test('a local cover candidate is served through /api/.../local-file, a remote-style URL is left untouched', async ({ page }) => {
    const seeded = seedSession('covers-src');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`).click();

    const images = page.locator('.cover-candidate img');
    const largeSrc = await images.nth(0).getAttribute('src');
    const smallSrc = await images.nth(1).getAttribute('src');
    const remoteSrc = await images.nth(2).getAttribute('src');

    expect(largeSrc).toContain(`/api/sessions/${seeded.sessionId}/local-file?path=`);
    expect(smallSrc).toContain(`/api/sessions/${seeded.sessionId}/local-file?path=`);
    // See seed-session.ps1's NOTE: a genuinely reachable remote URL isn't available in this
    // suite, so this only proves resolveCoverImageSrc() (app.js) leaves an http(s) URL as-is
    // instead of routing it through the local-file proxy - not that the image itself loads.
    expect(remoteSrc).toBe('https://example.invalid/cover-remote.jpg');

    // The two local candidates are real, decodable images - not broken <img> placeholders.
    await expect(images.nth(0)).toBeVisible();
    await expect(images.nth(1)).toBeVisible();
    expect(await images.nth(0).evaluate((img) => img.naturalWidth)).toBeGreaterThan(0);
    expect(await images.nth(1).evaluate((img) => img.naturalWidth)).toBeGreaterThan(0);
  });

  test('selecting a different cover candidate marks the release dirty and updates the chosen candidate', async ({ page }) => {
    const seeded = seedSession('covers-select');
    await gotoApp(page);
    const row = page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`);
    await row.click();

    const candidates = page.locator('.cover-candidate');
    await expect(candidates.nth(0).locator('input[type="radio"]')).toBeChecked();

    await candidates.nth(1).locator('input[type="radio"]').check();

    await expect(candidates.nth(1).locator('input[type="radio"]')).toBeChecked();
    await expect(candidates.nth(0).locator('input[type="radio"]')).not.toBeChecked();
    await expect(row).toHaveClass(/unsaved/);
  });

  test('clicking a thumbnail opens a lightbox with the full-size image, without changing the selected candidate; Close/outside-click/Escape all close it', async ({ page }) => {
    const seeded = seedSession('covers-lightbox');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`).click();

    const candidates = page.locator('.cover-candidate');
    await expect(candidates.nth(0).locator('input[type="radio"]')).toBeChecked();

    await candidates.nth(1).locator('img').click();
    const modal = page.locator('#cover-modal');
    await expect(modal).toBeVisible();
    // Clicking the thumbnail to preview it must not have changed which candidate is chosen.
    await expect(candidates.nth(0).locator('input[type="radio"]')).toBeChecked();

    await page.locator('#cover-modal-close').click();
    await expect(modal).toBeHidden();

    await candidates.nth(1).locator('img').click();
    await expect(modal).toBeVisible();
    // #cover-modal has zero padding (styles.css) so its box exactly wraps the <img> - a click
    // anywhere inside that box lands on the image, not the dialog itself. The real "outside
    // click" this is testing only happens on the ::backdrop, i.e. a page coordinate clearly
    // outside the (centered) dialog's rendered box - the viewport corner is always outside it.
    await page.mouse.click(5, 5);
    await expect(modal).toBeHidden();

    await candidates.nth(1).locator('img').click();
    await expect(modal).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(modal).toBeHidden();
  });

  test('uploading a valid image adds it as a new, auto-selected candidate; an unsaved upload is gone after reload but its file stays on disk', async ({ page }) => {
    const seeded = seedSession('covers-upload');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.minimal.stableKey}"]`).click();

    await expect(page.locator('.cover-candidate')).toHaveCount(1);

    await page.locator('#manual-cover-input').setInputFiles(path.join(__dirname, '..', 'fixtures', 'upload-cover.png'));

    await expect(page.locator('#manual-cover-status')).toContainText('Uploaded', { timeout: 10_000 });
    const candidates = page.locator('.cover-candidate');
    await expect(candidates).toHaveCount(2);
    await expect(candidates.nth(1).locator('input[type="radio"]')).toBeChecked();

    const uploadedSrc = await candidates.nth(1).locator('img').getAttribute('src');
    expect(uploadedSrc).toContain(`/api/sessions/${seeded.sessionId}/local-file?path=`);

    // Extract the manual-cover file's disk path from the encoded query string so it can be
    // checked directly (the endpoint refuses any path not already whitelisted or under
    // manual-covers/, so a raw fs.existsSync on the encoded path is the simplest direct check).
    const encodedPath = new URL(uploadedSrc, 'http://placeholder').searchParams.get('path');
    const fs = require('fs');
    expect(fs.existsSync(encodedPath)).toBe(true);

    await page.reload();
    await page.locator(`.release-row[data-stable-key="${seeded.minimal.stableKey}"]`).click();
    // Never saved - proposal.json on disk never gained the candidate.
    await expect(page.locator('.cover-candidate')).toHaveCount(1);
    // But the uploaded bytes are still on disk under manual-covers/ (Save-ReshelfUiManualCoverFile
    // writes immediately, independent of the deferred-Save-only proposal.json edit - see app.js's
    // uploadManualCover comment).
    expect(fs.existsSync(encodedPath)).toBe(true);
  });

  test('adding a manual cover to a release that already has candidates appends it, keeping the existing ones selectable', async ({ page }) => {
    const seeded = seedSession('covers-upload-append');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`).click();
    await expect(page.locator('.cover-candidate')).toHaveCount(3);

    await page.locator('#manual-cover-input').setInputFiles(path.join(__dirname, '..', 'fixtures', 'upload-cover.png'));
    await expect(page.locator('#manual-cover-status')).toContainText('Uploaded', { timeout: 10_000 });

    const candidates = page.locator('.cover-candidate');
    await expect(candidates).toHaveCount(4);
    // Still selectable, not removed/replaced by the new upload.
    await candidates.nth(0).locator('input[type="radio"]').check();
    await expect(candidates.nth(0).locator('input[type="radio"]')).toBeChecked();
  });

  test('a release with no cover candidates at all still shows the "Add cover from file…" control', async ({ page }) => {
    const seeded = seedSession('covers-empty-gallery');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.empty.stableKey}"]`).click();

    await expect(page.locator('.cover-candidate')).toHaveCount(0);
    await expect(page.locator('#manual-cover-btn')).toBeVisible();
  });

  test('uploading a non-image file shows an inline error and adds nothing to the gallery', async ({ page }) => {
    const seeded = seedSession('covers-upload-reject');
    await gotoApp(page);
    await page.locator(`.release-row[data-stable-key="${seeded.minimal.stableKey}"]`).click();
    await expect(page.locator('.cover-candidate')).toHaveCount(1);

    await page.locator('#manual-cover-input').setInputFiles(path.join(__dirname, '..', 'fixtures', 'not-an-image.txt'));

    await expect(page.locator('#manual-cover-status')).toContainText('Upload failed', { timeout: 10_000 });
    await expect(page.locator('.cover-candidate')).toHaveCount(1);
  });
});
