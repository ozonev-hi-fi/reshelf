// @ts-check
const { test, expect } = require('@playwright/test');
const { seedSession, gotoApp, mockDiscogsSelection } = require('../helpers');

test.describe('review state: Discogs match, Approve, Reject', () => {
  test('an ambiguous release shows the Discogs candidate picker and the "ambiguous" badge; picking a candidate resolves it', async ({ page }) => {
    await mockDiscogsSelection(page);
    const seeded = seedSession('review-ambiguous');
    await gotoApp(page);

    const row = page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`);
    await expect(row.locator('.badge')).toHaveText('ambiguous');
    await row.click();

    const candidates = page.locator('#discogs-candidates');
    await expect(candidates).toBeVisible();
    const options = page.locator('.discogs-candidate');
    await expect(options).toHaveCount(2);
    await expect(options.nth(0)).toContainText('Original Press');
    await expect(options.nth(1)).toContainText('Reissue');

    await options.nth(1).locator('input[type="radio"]').check();
    await expect(options.nth(1).locator('input[type="radio"]')).toBeChecked();
    await expect(page.locator('#discogs-candidate-status')).toHaveText('Updated.');
    // The recompute (mocked above) flips discogsMatch.status to 'matched' - the picker section
    // hides itself once there's no more ambiguity to resolve (app.js's renderDiscogsCandidates).
    await expect(candidates).toBeHidden();
  });

  test('Approve and Reject are mutually exclusive, and the row badge reflects the current choice', async ({ page }) => {
    const seeded = seedSession('review-approve-reject');
    await gotoApp(page);

    const row = page.locator(`.release-row[data-stable-key="${seeded.minimal.stableKey}"]`);
    await row.click();

    const approve = page.locator('#approve-checkbox');
    const reject = page.locator('#reject-checkbox');

    await approve.check();
    await expect(approve).toBeChecked();
    await expect(reject).not.toBeChecked();
    await expect(row.locator('.badge')).toHaveText('ready');

    await reject.check();
    await expect(reject).toBeChecked();
    await expect(approve).not.toBeChecked();
    await expect(row.locator('.badge')).toHaveText('rejected');

    await approve.check();
    await expect(approve).toBeChecked();
    await expect(reject).not.toBeChecked();
    await expect(row.locator('.badge')).toHaveText('ready');
  });

  test('a release still needing review (not ambiguous, not yet approved) shows the "needsReview" badge', async ({ page }) => {
    const seeded = seedSession('review-needs-review');
    await gotoApp(page);

    // "rich" is seeded with needsReview: true AND an ambiguous Discogs match, so 'ambiguous'
    // takes priority in getReleaseStatus (app.js) - "minimal" is seeded with needsReview: true
    // but a plain 'matched' status, isolating this specific badge path.
    const row = page.locator(`.release-row[data-stable-key="${seeded.minimal.stableKey}"]`);
    await expect(row.locator('.badge')).toHaveText('needsReview');
  });

  test('the "Needs review" and "Ambiguous" filters narrow the list on their own, and show the union when both are checked', async ({ page }) => {
    const seeded = seedSession('review-filters');
    await gotoApp(page);

    const needsReviewRow = page.locator(`.release-row[data-stable-key="${seeded.minimal.stableKey}"]`); // status: needsReview
    const ambiguousRow = page.locator(`.release-row[data-stable-key="${seeded.rich.stableKey}"]`); // status: ambiguous
    const needsReviewFilter = page.locator('#filter-needs-review');
    const ambiguousFilter = page.locator('#filter-ambiguous');

    await expect(needsReviewRow).toBeVisible();
    await expect(ambiguousRow).toBeVisible();

    await needsReviewFilter.check();
    await expect(needsReviewRow).toBeVisible();
    await expect(ambiguousRow).toHaveCount(0);

    await ambiguousFilter.check();
    // Regression: checking both filters together must show the union (both releases), not the
    // empty intersection a release's single status can never satisfy (app.js renderList).
    await expect(needsReviewRow).toBeVisible();
    await expect(ambiguousRow).toBeVisible();

    await needsReviewFilter.uncheck();
    await expect(needsReviewRow).toHaveCount(0);
    await expect(ambiguousRow).toBeVisible();
  });
});
