// @ts-check
// Shared helpers for every spec file: reading the state global-setup.js wrote, and seeding a
// fresh session for a test to use.

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const STATE_PATH = path.join(__dirname, '.tmp', 'state.json');

/** @returns {{ port: number, baseURL: string, dataHome: string, targetRoot: string, sourceRoot: string, repoRoot: string }} */
function getState() {
  return JSON.parse(fs.readFileSync(STATE_PATH, 'utf-8'));
}

/**
 * Seeds one fresh session (see seed-session.ps1) and returns its {sessionId, proposalPath,
 * sourceFolderPath, rich, minimal, empty, compilation}. Each call creates a brand new session with
 * fresh stableKeys and a fresh source folder, so tests never see another test's leftover edits.
 * @param {string} label - short, human-readable tag folded into the seeded folder/album names,
 *   shows up in the "Past sessions" dropdown text - pass something that identifies the caller
 *   (e.g. the spec file name) to make a failure's seeded data easy to find on disk afterward.
 */
function seedSession(label) {
  const state = getState();
  const output = execFileSync(
    'pwsh',
    [
      '-NoProfile',
      '-NoLogo',
      '-File',
      path.join(__dirname, 'seed-session.ps1'),
      '-DataHome',
      state.dataHome,
      '-SourceRoot',
      state.sourceRoot,
      '-Label',
      label,
    ],
    { env: { ...process.env, RESHELF_HOME: state.dataHome }, encoding: 'utf-8' }
  );
  return JSON.parse(output.trim());
}

/**
 * Runs `Reshelf.ps1 apply -SessionId <id>` for real against the shared temp target root, exactly
 * as a person would from a terminal. Returns the parsed {Applied, Skipped, Rejected, Failed}.
 */
function runApply(sessionId) {
  const state = getState();
  const rawOutput = execFileSync(
    'pwsh',
    ['-NoProfile', '-NoLogo', '-File', path.join(state.repoRoot, 'scripts', 'Reshelf.ps1'), 'apply', '-SessionId', sessionId, '-IncludeUnresolved'],
    // PSStyle: PowerShell 7.2+ writes ANSI color codes into Format-List output by default even
    // when stdout is redirected (not a real terminal) - NO_COLOR is the standard opt-out env var
    // it honors, so the captured text can be parsed as plain lines below.
    { env: { ...process.env, RESHELF_HOME: state.dataHome, NO_COLOR: '1' }, encoding: 'utf-8' }
  );
  const output = rawOutput.replace(/\x1b\[[0-9;]*m/g, '');
  const result = {};
  for (const line of output.split(/\r?\n/)) {
    const match = line.match(/^(Applied|Skipped|Rejected|Failed)\s*:\s*(\d+)/);
    if (match) result[match[1]] = Number(match[2]);
  }
  return result;
}

/** Navigates to the app's root page, using the runtime baseURL from global-setup.js. */
async function gotoApp(page, path = '/') {
  const state = getState();
  await page.goto(state.baseURL + path);
}

/**
 * Intercepts the Discogs-candidate-selection endpoint (POST .../discogs-selection) and fulfills it
 * locally instead of letting the real server call out to the live Discogs API for a release detail.
 * This suite runs with no real network access to Discogs (see seed-session.ps1's own note on this),
 * but the real endpoint (Update-ReshelfReleaseForDiscogsSelection) always makes a live
 * /releases/{id} call - every seeded candidate's releaseId is a made-up small integer, not a real
 * Discogs release, so without this it would either hang/fail on a blocked connection, or (worse, if
 * the runner *does* have outbound access) actually fetch and apply some unrelated real release's
 * data. Only discogsMatch flips to 'matched' here; every other field (tracks, proposed, coverArt,
 * ...) is left out so the client keeps its existing copy - app.js merges the response with
 * Object.assign, which never deletes a key the response omits.
 */
async function mockDiscogsSelection(page) {
  await page.route('**/discogs-selection', async (route) => {
    const body = JSON.parse(route.request().postData());
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ discogsMatch: { status: 'matched', selectedReleaseId: body.releaseId, candidates: [] } }),
    });
  });
}

module.exports = { getState, seedSession, runApply, gotoApp, mockDiscogsSelection };
