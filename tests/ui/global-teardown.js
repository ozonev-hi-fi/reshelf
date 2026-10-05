// @ts-check
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const STATE_PATH = path.join(__dirname, '.tmp', 'state.json');

module.exports = async function globalTeardown() {
  if (!fs.existsSync(STATE_PATH)) return;
  const state = JSON.parse(fs.readFileSync(STATE_PATH, 'utf-8'));

  if (state.serverPid) {
    try {
      // taskkill /T (tree) /F (force): a plain process.kill(pid) sends a signal pwsh's
      // HttpListener loop has no handler for and may not act on promptly; taskkill reliably ends
      // it and any child process under it on Windows. The server-down.spec.js test kills this
      // same server deliberately mid-suite, so a "process already gone" error here is expected
      // and harmless, not a real teardown failure.
      execFileSync('taskkill', ['/PID', String(state.serverPid), '/T', '/F'], { stdio: 'ignore' });
    } catch {
      // Already stopped (e.g. by server-down.spec.js) - nothing left to do.
    }
  }

  try {
    fs.rmSync(path.dirname(state.dataHome), { recursive: true, force: true });
  } catch {
    // Best-effort cleanup - a leftover temp folder under the OS temp dir is not worth failing the run over.
  }

  fs.rmSync(path.dirname(STATE_PATH), { recursive: true, force: true });
};
