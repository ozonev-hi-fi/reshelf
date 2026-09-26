// @ts-check
// Prepares an isolated TAGGER_HOME (settings.json + empty sessions folder) and starts a real
// Start-TaggerUiServer.ps1 against it, exactly as a person running `Tagger.ps1 ui start` would -
// this suite drives the real server, not a mock of it. State is written to .tmp/state.json so
// every spec file (loaded after this finishes - Playwright runs globalSetup before collecting
// test files) and global-teardown.js can find the same server/paths without re-deriving them.

const fs = require('fs');
const os = require('os');
const path = require('path');
const net = require('net');
const { spawn, execFileSync } = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const STATE_DIR = path.join(__dirname, '.tmp');
const STATE_PATH = path.join(STATE_DIR, 'state.json');

function findFreePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.unref();
    server.on('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      server.close(() => resolve(port));
    });
  });
}

function runPwsh(args, env) {
  execFileSync('pwsh', ['-NoProfile', '-NoLogo', ...args], {
    env,
    stdio: 'pipe',
  });
}

async function waitUntilReady(url, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let lastError;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(url);
      if (res.ok) return;
    } catch (err) {
      lastError = err;
    }
    await new Promise((r) => setTimeout(r, 200));
  }
  throw new Error(`Tagger UI server never became ready at ${url}: ${lastError?.message ?? 'timed out'}`);
}

module.exports = async function globalSetup() {
  const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'tagger-ui-'));
  const dataHome = path.join(tmpRoot, 'data');
  const targetRoot = path.join(tmpRoot, 'target');
  const sourceRoot = path.join(tmpRoot, 'source');
  for (const dir of [dataHome, targetRoot, sourceRoot]) {
    fs.mkdirSync(dir, { recursive: true });
  }

  const env = { ...process.env, TAGGER_HOME: dataHome };

  // Non-interactive settings.json: real ffmpeg resolves via PATH (settings.default.json's
  // ffmpegPath is "" by design, see plan/01), but taglibSharpPath must be pointed at the repo's
  // own already-downloaded TagLibSharp.dll explicitly - this temp data home has no 'lib' folder
  // of its own, and Import-TaggerTagLibSharp's fallback path is <DataHome>/lib/TagLibSharp.dll.
  runPwsh(['-File', path.join(REPO_ROOT, 'scripts', 'Tagger.ps1'), 'settings', 'init', '-TargetRoot', targetRoot, '-Force'], env);
  const taglibSharpPath = path.join(REPO_ROOT, '.data', 'lib', 'TagLibSharp.dll');
  if (!fs.existsSync(taglibSharpPath)) {
    throw new Error(
      `TagLibSharp.dll not found at '${taglibSharpPath}'. The Playwright suite's end-to-end apply spec needs the same ` +
        'real DLL the rest of the test suite already requires (see plan/01, plan/11).'
    );
  }
  runPwsh(['-File', path.join(REPO_ROOT, 'scripts', 'Tagger.ps1'), 'settings', 'set', '-Key', 'taglibSharpPath', '-Value', taglibSharpPath], env);

  const port = await findFreePort();
  const baseURL = `http://localhost:${port}`;

  const serverProcess = spawn(
    'pwsh',
    ['-NoProfile', '-NoLogo', '-File', path.join(REPO_ROOT, 'scripts', 'Start-TaggerUiServer.ps1'), '-Port', String(port), '-NoBrowser'],
    { env, stdio: 'pipe', windowsHide: true }
  );
  serverProcess.unref();

  let serverOutput = '';
  serverProcess.stdout.on('data', (chunk) => (serverOutput += chunk.toString()));
  serverProcess.stderr.on('data', (chunk) => (serverOutput += chunk.toString()));

  try {
    await waitUntilReady(`${baseURL}/`, 15_000);
  } catch (err) {
    serverProcess.kill();
    throw new Error(`${err.message}\nServer output so far:\n${serverOutput}`);
  }

  fs.mkdirSync(STATE_DIR, { recursive: true });
  fs.writeFileSync(
    STATE_PATH,
    JSON.stringify(
      {
        port,
        baseURL,
        dataHome,
        targetRoot,
        sourceRoot,
        repoRoot: REPO_ROOT,
        serverPid: serverProcess.pid,
      },
      null,
      2
    )
  );
};
