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
 * sourceFolderPath, rich, minimal}. Each call creates a brand new session with fresh stableKeys
 * and a fresh source folder, so tests never see another test's leftover edits.
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
    { env: { ...process.env, TAGGER_HOME: state.dataHome }, encoding: 'utf-8' }
  );
  return JSON.parse(output.trim());
}

/**
 * Runs `Tagger.ps1 apply -SessionId <id>` for real against the shared temp target root, exactly
 * as a person would from a terminal. Returns the parsed {Applied, Skipped, Rejected, Failed}.
 */
function runApply(sessionId) {
  const state = getState();
  const rawOutput = execFileSync(
    'pwsh',
    ['-NoProfile', '-NoLogo', '-File', path.join(state.repoRoot, 'scripts', 'Tagger.ps1'), 'apply', '-SessionId', sessionId, '-IncludeUnresolved'],
    // PSStyle: PowerShell 7.2+ writes ANSI color codes into Format-List output by default even
    // when stdout is redirected (not a real terminal) - NO_COLOR is the standard opt-out env var
    // it honors, so the captured text can be parsed as plain lines below.
    { env: { ...process.env, TAGGER_HOME: state.dataHome, NO_COLOR: '1' }, encoding: 'utf-8' }
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

module.exports = { getState, seedSession, runApply, gotoApp };
