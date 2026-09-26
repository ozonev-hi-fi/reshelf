// @ts-check
const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');
const { getState, gotoApp } = require('../helpers');

/** Overwrites lossy-tracking.json in the shared dataHome with exactly these entries. */
function seedLossyLedger(entries) {
  const state = getState();
  fs.writeFileSync(path.join(state.dataHome, 'lossy-tracking.json'), JSON.stringify(entries, null, 2));
}

function makeEntry(overrides = {}) {
  const now = new Date().toISOString().replace(/\.\d+Z$/, '.000Z');
  return {
    stableKey: 'a1b2c3d4e5f60708',
    artist: 'ZZ Top',
    album: 'XXX',
    year: 1999,
    targetPath: 'E:\\Music\\ZZ Top\\1999 XXX',
    format: 'mp3',
    status: 'pending-upgrade',
    firstDetectedUtc: now,
    lastCheckedUtc: now,
    upgradedUtc: null,
    notes: '',
    ...overrides,
  };
}

test.describe('lossy tracker view', () => {
  test('switching to the Lossy tracker tab shows the ledger; switching back shows releases again', async ({ page }) => {
    seedLossyLedger([makeEntry()]);
    await gotoApp(page);

    await expect(page.locator('#main-layout')).toBeVisible();
    await expect(page.locator('#lossy-view')).toBeHidden();

    await page.locator('#view-btn-lossy').click();

    await expect(page.locator('#lossy-view')).toBeVisible();
    await expect(page.locator('#main-layout')).toBeHidden();
    await expect(page.locator('#lossy-table tbody tr')).toHaveCount(1);
    await expect(page.locator('#lossy-table tbody tr').first()).toContainText('ZZ Top');
    await expect(page.locator('#lossy-table tbody tr').first()).toContainText('XXX');

    await page.locator('#view-btn-releases').click();
    await expect(page.locator('#main-layout')).toBeVisible();
    await expect(page.locator('#lossy-view')).toBeHidden();
  });

  test('the status filter narrows the table to matching rows only', async ({ page }) => {
    seedLossyLedger([
      makeEntry({ stableKey: 'a1b2c3d4e5f60708', artist: 'Band Pending', status: 'pending-upgrade' }),
      makeEntry({ stableKey: 'b2b3c4d5e6f70819', artist: 'Band Ignored', status: 'ignored' }),
    ]);
    await gotoApp(page);
    await page.locator('#view-btn-lossy').click();

    await expect(page.locator('#lossy-table tbody tr')).toHaveCount(2);

    await page.locator('#lossy-filter-status').selectOption('ignored');
    await expect(page.locator('#lossy-table tbody tr')).toHaveCount(1);
    await expect(page.locator('#lossy-table tbody tr').first()).toContainText('Band Ignored');
  });

  test('changing a row\'s status persists to disk', async ({ page }) => {
    seedLossyLedger([makeEntry()]);
    await gotoApp(page);
    await page.locator('#view-btn-lossy').click();

    await page.locator('#lossy-table tbody tr').first().locator('select').selectOption('ignored');
    await expect(page.locator('#lossy-status')).toContainText('Saved');

    const state = getState();
    const ledger = JSON.parse(fs.readFileSync(path.join(state.dataHome, 'lossy-tracking.json'), 'utf-8'));
    expect(ledger[0].status).toBe('ignored');
  });

  test('editing a row\'s notes persists to disk', async ({ page }) => {
    seedLossyLedger([makeEntry()]);
    await gotoApp(page);
    await page.locator('#view-btn-lossy').click();

    const notesInput = page.locator('#lossy-table tbody tr').first().locator('input[type="text"]');
    await notesInput.fill('Not chasing this one');
    await notesInput.blur();
    await expect(page.locator('#lossy-status')).toContainText('Saved');

    const state = getState();
    const ledger = JSON.parse(fs.readFileSync(path.join(state.dataHome, 'lossy-tracking.json'), 'utf-8'));
    expect(ledger[0].notes).toBe('Not chasing this one');
  });

  test('deleting a row asks for confirmation and removes it from disk', async ({ page }) => {
    seedLossyLedger([makeEntry()]);
    await gotoApp(page);
    await page.locator('#view-btn-lossy').click();

    page.once('dialog', async (dialog) => {
      expect(dialog.message()).toMatch(/permanently/i);
      await dialog.accept();
    });
    await page.locator('#lossy-table tbody tr').first().locator('button').click();

    await expect(page.locator('#lossy-empty')).toBeVisible();
    const state = getState();
    const ledger = JSON.parse(fs.readFileSync(path.join(state.dataHome, 'lossy-tracking.json'), 'utf-8'));
    expect(ledger).toHaveLength(0);
  });

  test('Export CSV downloads a file containing the visible rows', async ({ page }) => {
    seedLossyLedger([makeEntry()]);
    await gotoApp(page);
    await page.locator('#view-btn-lossy').click();

    const downloadPromise = page.waitForEvent('download');
    await page.locator('#lossy-export-csv-btn').click();
    const download = await downloadPromise;
    const downloadPath = await download.path();
    const content = fs.readFileSync(downloadPath, 'utf-8');

    expect(content).toContain('stableKey');
    expect(content).toContain('ZZ Top');
  });
});
