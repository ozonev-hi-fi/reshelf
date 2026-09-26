const state = {
  currentSessionId: null,
  sessions: [], // [{ sessionId, sourceRoot, stage, updatedAtUtc, hasProposal }]
  proposal: null,
  selectedReleaseKey: null,
  selectedUnrecognizedIndex: null,
  filters: { needsReviewOnly: false, ambiguousOnly: false },
  dirtyReleaseKeys: new Set(),
  lastError: null,
  // {releaseFolder, trackFile, trackNumberPadWidth} from settings.json's namingTemplates, fetched
  // once at startup - lets an Artist/Album/Year edit preview the same folder name Step 6 would
  // actually propose, without waiting for a re-run of 'propose'.
  namingTemplates: { releaseFolder: '{year} {album}', trackFile: '{trackNumber} {title}' },
  view: 'releases', // 'releases' | 'lossy'
  lossy: { entries: [], filterStatus: '' },
};

function isDirty() {
  return state.dirtyReleaseKeys.size > 0;
}

// The local server (Start-ReshelfUiServer.ps1) reads/writes proposal.json itself - it already has
// full disk access as a PowerShell process, unlike the browser. This page never picks or opens a
// folder; it just asks the server for JSON over fetch(), same as any other web page.

async function fetchJson(url, options) {
  const res = await fetch(url, options);
  let body = null;
  try {
    body = await res.json();
  } catch {
    // No JSON body (e.g. a plain error page) - fall through to the generic message below.
  }
  if (!res.ok) {
    const message = body && body.error ? body.error : `Request to ${url} failed (${res.status}).`;
    throw new Error(message);
  }
  return body;
}

function wireStaticControls() {
  document.getElementById('retry-btn').addEventListener('click', loadCurrentSession);
  document.getElementById('session-history-select').addEventListener('change', (e) => {
    if (isDirty() && !window.confirm('You have unsaved changes. Discard them and switch session?')) {
      e.target.value = state.currentSessionId ?? '';
      return;
    }
    onSelectHistorySession(e.target.value);
  });
  document.getElementById('filter-needs-review').addEventListener('change', (e) => {
    state.filters.needsReviewOnly = e.target.checked;
    renderList();
  });
  document.getElementById('filter-ambiguous').addEventListener('change', (e) => {
    state.filters.ambiguousOnly = e.target.checked;
    renderList();
  });
  document.getElementById('save-btn').addEventListener('click', saveProposal);
  document.getElementById('save-btn-top').addEventListener('click', saveProposal);
  document.getElementById('manual-cover-input').addEventListener('change', onManualCoverFileChosen);

  document.getElementById('view-btn-releases').addEventListener('click', () => switchView('releases'));
  document.getElementById('view-btn-lossy').addEventListener('click', () => switchView('lossy'));
  document.getElementById('lossy-filter-status').addEventListener('change', (e) => {
    state.lossy.filterStatus = e.target.value;
    renderLossyTable();
  });
  document.getElementById('lossy-export-csv-btn').addEventListener('click', () => exportLossyLedger('csv'));
  document.getElementById('lossy-export-json-btn').addEventListener('click', () => exportLossyLedger('json'));

  document.getElementById('unrecognized-override-kind').addEventListener('change', renderUnrecognizedOverrideJson);
  document.getElementById('unrecognized-override-artist-name').addEventListener('input', renderUnrecognizedOverrideJson);
  document.getElementById('unrecognized-copy-btn').addEventListener('click', onCopyUnrecognizedOverride);

  const coverModal = document.getElementById('cover-modal');
  document.getElementById('cover-modal-close').addEventListener('click', () => coverModal.close());
  coverModal.addEventListener('click', (e) => {
    if (e.target === coverModal) coverModal.close();
  });
}

function setSessionStatus(text) {
  document.getElementById('session-status').textContent = text;
}

// Deliberately separate from #session-status (which never includes the raw session id - it reads
// as source root + date + stage, meaningful to a person) - this is a second, small label purely so
// a person can name exactly which session they're looking at, e.g. to tell someone else "I reviewed
// 2026-09-26-0002".
function setSessionIdLabel(sessionId) {
  document.getElementById('session-id-label').textContent = sessionId ? `Session ${sessionId}` : '';
}

function showRetry(message) {
  document.getElementById('retry-btn').hidden = false;
  setSessionStatus(message ? `Error: ${message}` : 'Something went wrong.');
}

function hideRetry() {
  document.getElementById('retry-btn').hidden = true;
}

function describeSession(session) {
  const date = new Date(session.updatedAtUtc).toLocaleDateString();
  return `Reviewing: ${session.sourceRoot} (${date}, ${session.stage})`;
}

function clearReleaseView() {
  document.getElementById('detail-panel').hidden = true;
  document.getElementById('unrecognized-panel').hidden = true;
  document.getElementById('release-list').innerHTML = '';
}

function switchView(view) {
  state.view = view;
  // #main-layout carries its own explicit `display: flex` in styles.css (needed for its two-pane
  // layout), which - since an ID selector outranks the `[hidden]` attribute selector's UA-default
  // `display: none` - would otherwise keep it visible even with the hidden attribute set. Toggled
  // via inline style instead; #lossy-view has no such conflicting rule, so `hidden` works for it.
  document.getElementById('main-layout').style.display = view === 'releases' ? 'flex' : 'none';
  document.getElementById('lossy-view').hidden = view !== 'lossy';
  document.getElementById('view-btn-releases').classList.toggle('view-btn-active', view === 'releases');
  document.getElementById('view-btn-lossy').classList.toggle('view-btn-active', view === 'lossy');
  if (view === 'lossy') loadLossyLedger();
}

// --- Loading the current session on page load, and switching between sessions --------

async function loadCurrentSession() {
  try {
    hideRetry();
    setSessionStatus('Loading...');
    const data = await fetchJson('/api/current-session');

    if (!data.found) {
      state.currentSessionId = null;
      state.proposal = null;
      setSessionStatus(data.message);
      setSessionIdLabel(null);
      clearReleaseView();
    } else {
      state.currentSessionId = data.sessionId;
      state.proposal = data.proposal;
      state.selectedReleaseKey = null;
      state.dirtyReleaseKeys.clear();
      updateSaveIndicator();
      setSessionStatus(describeSession(data));
      setSessionIdLabel(data.sessionId);
      document.getElementById('detail-panel').hidden = true;
      renderList();
    }
    await refreshSessionHistory();
  } catch (err) {
    state.lastError = err.message;
    showRetry(err.message);
  }
}

async function refreshSessionHistory() {
  try {
    const sessions = await fetchJson('/api/sessions');
    state.sessions = sessions;
    renderSessionHistory(sessions);
  } catch (err) {
    // The main session already loaded fine at this point - a broken history list is a
    // secondary feature, not worth showing as a hard error.
    console.warn('Could not load session history:', err);
  }
}

function renderSessionHistory(sessions) {
  const container = document.getElementById('session-history');
  const select = document.getElementById('session-history-select');

  if (sessions.length <= 1) {
    container.hidden = true;
    return;
  }
  container.hidden = false;
  select.innerHTML = '';

  for (const session of sessions) {
    const option = document.createElement('option');
    option.value = session.sessionId;
    const date = new Date(session.updatedAtUtc).toLocaleDateString();
    const suffix = session.hasProposal ? '' : ' (no proposal yet)';
    option.textContent = `${session.sourceRoot} - ${date} - ${session.stage}${suffix}`;
    select.appendChild(option);
  }
  select.value = state.currentSessionId ?? '';
}

async function onSelectHistorySession(sessionId) {
  const session = state.sessions.find((s) => s.sessionId === sessionId);
  if (!session) return;

  if (!session.hasProposal) {
    state.currentSessionId = sessionId;
    state.proposal = null;
    setSessionStatus(`${session.sourceRoot} has no proposal.json yet.`);
    setSessionIdLabel(sessionId);
    clearReleaseView();
    return;
  }

  try {
    hideRetry();
    const proposal = await fetchJson(`/api/sessions/${sessionId}/proposal`);
    state.currentSessionId = sessionId;
    state.proposal = proposal;
    state.selectedReleaseKey = null;
    state.dirtyReleaseKeys.clear();
    updateSaveIndicator();
    setSessionStatus(describeSession(session));
    setSessionIdLabel(sessionId);
    document.getElementById('detail-panel').hidden = true;
    renderList();
  } catch (err) {
    state.lastError = err.message;
    showRetry(err.message);
  }
}

function flattenReleases(proposal) {
  const flattened = [];
  for (const artist of proposal.artists) {
    for (const release of artist.releases) {
      flattened.push({ artistName: artist.recognizedName, release });
    }
  }
  return flattened;
}

function findRelease(stableKey) {
  return flattenReleases(state.proposal).find((entry) => entry.release.stableKey === stableKey) ?? null;
}

function getReleaseStatus(release) {
  if (release.humanReview.rejected) {
    return 'rejected';
  }
  if (release.discogsMatch.status === 'ambiguous' && !release.humanReview.resolved) {
    return 'ambiguous';
  }
  if ((release.needsReview || release.humanReview.required) && !release.humanReview.resolved) {
    return 'needsReview';
  }
  return 'ready';
}

function renderList() {
  const container = document.getElementById('release-list');
  container.innerHTML = '';

  if (!state.proposal) {
    return;
  }

  // Checking both filters is a union ("needs review" OR "ambiguous"), not an intersection - a
  // release's status is exactly one of these at a time, so combining them with separate AND
  // checks (the previous behavior) meant checking both boxes together always produced zero rows.
  const activeStatusFilters = [];
  if (state.filters.needsReviewOnly) activeStatusFilters.push('needsReview');
  if (state.filters.ambiguousOnly) activeStatusFilters.push('ambiguous');

  const byArtist = new Map();
  for (const entry of flattenReleases(state.proposal)) {
    const status = getReleaseStatus(entry.release);
    if (activeStatusFilters.length > 0 && !activeStatusFilters.includes(status)) continue;

    if (!byArtist.has(entry.artistName)) {
      byArtist.set(entry.artistName, []);
    }
    byArtist.get(entry.artistName).push(entry.release);
  }

  for (const [artistName, releases] of byArtist) {
    const section = document.createElement('section');
    const heading = document.createElement('h3');
    heading.textContent = artistName;
    section.appendChild(heading);

    for (const release of releases) {
      const status = getReleaseStatus(release);
      const row = document.createElement('div');
      row.className = 'release-row';
      row.dataset.stableKey = release.stableKey;
      row.classList.toggle('selected', release.stableKey === state.selectedReleaseKey);
      row.classList.toggle('unsaved', state.dirtyReleaseKeys.has(release.stableKey));

      const label = document.createElement('span');
      label.className = 'release-label';
      label.textContent = `${release.proposed.year ?? ''} ${release.proposed.album}`.trim();

      const badge = document.createElement('span');
      badge.className = `badge badge-${status}`;
      badge.textContent = status;

      row.appendChild(label);
      row.appendChild(badge);
      row.addEventListener('click', () => selectRelease(release.stableKey));

      section.appendChild(row);
    }

    container.appendChild(section);
  }

  const unrecognized = state.proposal.unrecognized ?? [];
  if (unrecognized.length > 0 && activeStatusFilters.length === 0) {
    const section = document.createElement('section');
    const heading = document.createElement('h3');
    heading.textContent = `Unrecognized (${unrecognized.length})`;
    section.appendChild(heading);

    unrecognized.forEach((entry, index) => {
      const row = document.createElement('div');
      row.className = 'release-row';
      row.dataset.unrecognizedIndex = String(index);
      row.classList.toggle('selected', index === state.selectedUnrecognizedIndex);

      const label = document.createElement('span');
      label.className = 'release-label';
      label.textContent = entry.path.split(/[\\/]/).filter(Boolean).pop() ?? entry.path;

      const badge = document.createElement('span');
      badge.className = 'badge badge-unrecognized';
      badge.textContent = 'unrecognized';

      row.appendChild(label);
      row.appendChild(badge);
      row.addEventListener('click', () => selectUnrecognized(index));

      section.appendChild(row);
    });

    container.appendChild(section);
  }
}

function selectRelease(stableKey) {
  state.selectedReleaseKey = stableKey;
  state.selectedUnrecognizedIndex = null;
  document.getElementById('unrecognized-panel').hidden = true;
  renderList();
  renderDetail();
}

function selectUnrecognized(index) {
  state.selectedUnrecognizedIndex = index;
  state.selectedReleaseKey = null;
  document.getElementById('detail-panel').hidden = true;
  renderList();
  renderUnrecognizedDetail(state.proposal.unrecognized[index]);
}

// Mirrors Get-ReshelfRelativePath (Reshelf.Common.psm1) closely enough for building an
// overrides.json relativePath from the source root and this entry's absolute path.
function getSourceRootRelativePath(sourceRoot, absolutePath) {
  const root = sourceRoot.replace(/[\\/]+$/, '');
  if (absolutePath.toLowerCase().startsWith(root.toLowerCase())) {
    return absolutePath.slice(root.length).replace(/^[\\/]+/, '');
  }
  return absolutePath;
}

function guessOverrideKind(reason) {
  if (reason === 'grouping-folder-suspected') return 'grouping';
  return 'artist';
}

function renderUnrecognizedDetail(entry) {
  const panel = document.getElementById('unrecognized-panel');
  panel.hidden = false;

  document.getElementById('unrecognized-title').textContent = entry.path.split(/[\\/]/).filter(Boolean).pop() ?? entry.path;
  document.getElementById('unrecognized-path').textContent = entry.path;
  document.getElementById('unrecognized-reason').textContent = entry.reason;

  const list = document.getElementById('unrecognized-children');
  list.innerHTML = '';
  for (const child of entry.children ?? []) {
    const li = document.createElement('li');
    li.textContent = child;
    list.appendChild(li);
  }

  const kindSelect = document.getElementById('unrecognized-override-kind');
  kindSelect.value = guessOverrideKind(entry.reason);
  const artistNameInput = document.getElementById('unrecognized-override-artist-name');
  artistNameInput.value = document.getElementById('unrecognized-title').textContent;

  renderUnrecognizedOverrideJson();
}

function renderUnrecognizedOverrideJson() {
  const entry = state.proposal?.unrecognized?.[state.selectedUnrecognizedIndex];
  if (!entry) return;

  const kind = document.getElementById('unrecognized-override-kind').value;
  const artistName = document.getElementById('unrecognized-override-artist-name').value;
  const needsArtistName = kind === 'artist' || kind === 'band-member';

  const override = {
    relativePath: getSourceRootRelativePath(state.proposal.sourceRoot, entry.path),
    kind,
    parentArtistName: null,
    artistName: needsArtistName ? (artistName || null) : null,
    notes: '',
  };

  document.getElementById('unrecognized-artist-name-field').hidden = !needsArtistName;
  document.getElementById('unrecognized-override-json').textContent = JSON.stringify(override, null, 2);
}

async function onCopyUnrecognizedOverride() {
  const status = document.getElementById('unrecognized-copy-status');
  const text = document.getElementById('unrecognized-override-json').textContent;
  try {
    await navigator.clipboard.writeText(text);
    status.textContent = 'Copied.';
  } catch (err) {
    status.textContent = `Could not copy automatically: ${err.message}`;
  }
}

function renderDetail() {
  const found = findRelease(state.selectedReleaseKey);
  const panel = document.getElementById('detail-panel');
  if (!found) {
    panel.hidden = true;
    return;
  }
  panel.hidden = false;

  const { artistName, release } = found;
  document.getElementById('detail-title').textContent = `${artistName} - ${release.proposed.album}`;

  renderBeforeAfterTable(release);
  renderReleaseFields(release);
  renderTrackFieldsTable(release);
  renderCompanionTable(release);
  renderCoverGallery(release);
  renderDiscogsCandidates(release);
  document.getElementById('manual-cover-status').textContent = '';

  const notesField = document.getElementById('notes-field');
  notesField.value = release.humanReview.notes;
  notesField.oninput = () => onEditNotes(release, notesField.value);

  const approveCheckbox = document.getElementById('approve-checkbox');
  approveCheckbox.checked = release.humanReview.resolved && !release.humanReview.rejected;
  approveCheckbox.onchange = () => onToggleApprove(release, approveCheckbox.checked);

  const rejectCheckbox = document.getElementById('reject-checkbox');
  rejectCheckbox.checked = release.humanReview.rejected;
  rejectCheckbox.onchange = () => onToggleReject(release, rejectCheckbox.checked);
}

function renderBeforeAfterTable(release) {
  const tbody = document.querySelector('#before-after-table tbody');
  const beforeHeader = document.getElementById('before-after-before-header');
  tbody.innerHTML = '';

  const isMultiDisc = new Set(release.tracks.map((t) => t.proposedDiscNumber)).size > 1;
  beforeHeader.colSpan = isMultiDisc ? 2 : 1;

  const folderRow = document.createElement('tr');
  const folderBefore = document.createElement('td');
  folderBefore.textContent = release.sourceFolderPath;
  if (isMultiDisc) folderBefore.colSpan = 2;
  const folderAfter = document.createElement('td');
  folderAfter.textContent = `${release.proposed.artistFolderName}\\${release.proposed.releaseFolderName}`;
  folderRow.appendChild(folderBefore);
  folderRow.appendChild(folderAfter);
  tbody.appendChild(folderRow);

  if (!isMultiDisc) {
    for (const track of release.tracks) {
      const row = document.createElement('tr');
      const before = document.createElement('td');
      before.textContent = track.originalFileName;
      const after = document.createElement('td');
      after.textContent = track.proposedFileName;
      row.appendChild(before);
      row.appendChild(after);
      tbody.appendChild(row);
    }
    return;
  }

  // Group tracks by disc, in first-seen order, labeled by the source's own discFolder name
  // (e.g. "Disc 1") when it had one, falling back to the proposed disc number otherwise (e.g. a
  // multi-disc cue release with no named subfolder).
  const discGroups = new Map();
  for (const track of release.tracks) {
    const label = track.discFolder ?? `Disc ${track.proposedDiscNumber}`;
    if (!discGroups.has(label)) discGroups.set(label, []);
    discGroups.get(label).push(track);
  }

  for (const [label, tracks] of discGroups) {
    tracks.forEach((track, index) => {
      const row = document.createElement('tr');
      if (index === 0) {
        const discCell = document.createElement('td');
        discCell.textContent = label;
        discCell.rowSpan = tracks.length;
        row.appendChild(discCell);
      }
      const before = document.createElement('td');
      before.textContent = track.originalFileName;
      const after = document.createElement('td');
      after.textContent = track.proposedFileName;
      row.appendChild(before);
      row.appendChild(after);
      tbody.appendChild(row);
    });
  }
}

function renderReleaseFields(release) {
  const artistField = document.getElementById('field-artist');
  artistField.value = release.tracks[0]?.tags.artist ?? release.proposed.artistFolderName;
  artistField.oninput = () => onEditArtist(release, artistField.value);

  const albumField = document.getElementById('field-album');
  albumField.value = release.proposed.album;
  albumField.oninput = () => onEditAlbum(release, albumField.value);

  const yearField = document.getElementById('field-year');
  yearField.value = release.proposed.year ?? '';
  yearField.oninput = () => onEditYear(release, yearField.value);

  const artistFolderField = document.getElementById('field-artist-folder');
  artistFolderField.value = release.proposed.artistFolderName;
  artistFolderField.oninput = () => onEditArtistFolderName(release, artistFolderField.value);

  const releaseFolderField = document.getElementById('field-release-folder');
  releaseFolderField.value = release.proposed.releaseFolderName;
  releaseFolderField.oninput = () => onEditReleaseFolderName(release, releaseFolderField.value);
}

function renderTrackFieldsTable(release) {
  const tbody = document.querySelector('#track-fields-table tbody');
  tbody.innerHTML = '';

  for (const track of release.tracks) {
    const row = document.createElement('tr');

    const discCell = document.createElement('td');
    const discInput = document.createElement('input');
    discInput.type = 'number';
    discInput.value = track.proposedDiscNumber;
    discInput.oninput = () => onEditTrackField(release, track, 'proposedDiscNumber', discInput.value);
    discCell.appendChild(discInput);

    const trackCell = document.createElement('td');
    const trackInput = document.createElement('input');
    trackInput.type = 'number';
    trackInput.value = track.proposedTrackNumber;
    trackInput.oninput = () => onEditTrackField(release, track, 'proposedTrackNumber', trackInput.value);
    trackCell.appendChild(trackInput);

    const titleCell = document.createElement('td');
    const titleInput = document.createElement('input');
    titleInput.type = 'text';
    titleInput.value = track.proposedTitle;
    titleInput.oninput = () => onEditTrackField(release, track, 'proposedTitle', titleInput.value);
    titleCell.appendChild(titleInput);

    row.appendChild(discCell);
    row.appendChild(trackCell);
    row.appendChild(titleCell);
    tbody.appendChild(row);
  }
}

// --- Other (non-media) files -------------------------------------------------------------
// Recognition/EditProposal already classified these (kind, placement) and, for a loose one,
// proposed a letter-first name (New-ReshelfCompanionProposal, Reshelf.EditProposal.psm1) - this
// table just makes that visible and lets the user override the name or drop the file from
// copying (manifesto SS4.5 / SS7.2: "we need to see them in Editing module").

// Display-only: mirrors Get-ReshelfRelativePath (Reshelf.Common.psm1) closely enough for showing a
// "Before" path, but keeps native backslashes since this is text shown to a Windows user, not a
// value written back into a document.
function getCompanionRelativePath(release, sourcePath) {
  const root = release.sourceFolderPath.replace(/[\\/]+$/, '');
  if (sourcePath.toLowerCase().startsWith(root.toLowerCase())) {
    return sourcePath.slice(root.length).replace(/^[\\/]+/, '');
  }
  return sourcePath;
}

// Mirrors Test-ReshelfLooseCompanionFileName (Reshelf.Common.psm1) - a loose companion must start
// with a letter (manifesto SS4.5), including non-ASCII letters, so normal alphabetical sorting in
// a file explorer always puts numbered tracks first.
function startsWithLetter(name) {
  return /^\p{L}/u.test(name ?? '');
}

function renderCompanionTable(release) {
  const table = document.getElementById('companion-table');
  const tbody = table.querySelector('tbody');
  const emptyMsg = document.getElementById('companion-empty');
  tbody.innerHTML = '';

  const companions = release.companionFiles ?? [];
  const ignored = release.ignoredFiles ?? [];

  if (companions.length === 0 && ignored.length === 0) {
    table.hidden = true;
    emptyMsg.hidden = false;
    return;
  }
  table.hidden = false;
  emptyMsg.hidden = true;

  for (const companion of companions) {
    const row = document.createElement('tr');
    row.className = 'companion-row';
    row.dataset.sourcePath = companion.sourcePath;
    const isLoose = companion.placement === 'loose';

    const includeCell = document.createElement('td');
    const includeCheckbox = document.createElement('input');
    includeCheckbox.type = 'checkbox';
    includeCheckbox.checked = companion.include !== false;
    includeCheckbox.onchange = () => onToggleCompanionInclude(release, companion, includeCheckbox.checked);
    includeCell.appendChild(includeCheckbox);

    const beforeName = getCompanionRelativePath(release, companion.sourcePath);
    const beforeCell = document.createElement('td');
    beforeCell.textContent = beforeName;

    // A loose companion without a proposed name (e.g. a session saved before a rename
    // suggestion existed for it) would otherwise show an empty "After" field and a
    // spurious "Name is required" warning - fall back to the original file name instead.
    if (isLoose && !companion.proposedFileName) {
      companion.proposedFileName = beforeName;
      markDirty(release);
    }

    const afterCell = document.createElement('td');
    if (isLoose) {
      const nameInput = document.createElement('input');
      nameInput.type = 'text';
      nameInput.value = companion.proposedFileName ?? '';
      nameInput.oninput = () => onEditCompanionName(release, companion, nameInput.value);
      afterCell.appendChild(nameInput);
    } else {
      // Nested companions (in a subfolder) are never renamed here - only excluded via the
      // Include checkbox - so the After column just repeats the same relative path.
      afterCell.appendChild(document.createTextNode(getCompanionRelativePath(release, companion.sourcePath)));
    }
    const warningEl = document.createElement('div');
    warningEl.className = 'companion-warning';
    warningEl.hidden = true;
    afterCell.appendChild(warningEl);

    const kindCell = document.createElement('td');
    kindCell.textContent = companion.kind;

    row.append(includeCell, beforeCell, afterCell, kindCell);
    tbody.appendChild(row);
  }

  for (const entry of ignored) {
    const row = document.createElement('tr');
    row.className = 'companion-row-ignored';

    const includeCell = document.createElement('td');
    const beforeCell = document.createElement('td');
    beforeCell.textContent = getCompanionRelativePath(release, entry.sourcePath);
    const afterCell = document.createElement('td');
    afterCell.textContent = `Not copied: ${entry.reason}`;
    const kindCell = document.createElement('td');

    row.append(includeCell, beforeCell, afterCell, kindCell);
    tbody.appendChild(row);
  }

  refreshCompanionWarnings(release);
}

// Re-validates every included loose companion's proposed name in place, without rebuilding the
// table - a full rebuild on every keystroke would reset the text input's cursor/focus while
// typing. Mirrors the checks Invoke-ReshelfReleaseStaging makes before copying anything
// (Reshelf.Implementation.psm1), so a problem is visible here before an apply run would fail it.
function refreshCompanionWarnings(release) {
  const trackFileNames = new Set(release.tracks.map((t) => t.proposedFileName.toLowerCase()));
  const includedNamesSeen = new Set();

  for (const row of document.querySelectorAll('#companion-table tbody tr.companion-row')) {
    const companion = release.companionFiles.find((c) => c.sourcePath === row.dataset.sourcePath);
    const warningEl = row.querySelector('.companion-warning');
    let warning = '';

    if (companion.placement === 'loose' && companion.include !== false) {
      const name = companion.proposedFileName ?? '';
      const lowerName = name.toLowerCase();
      if (!name) {
        warning = 'Name is required.';
      } else if (!startsWithLetter(name)) {
        warning = 'Must start with a letter.';
      } else if (trackFileNames.has(lowerName)) {
        warning = 'Same name as a track file.';
      } else if (includedNamesSeen.has(lowerName)) {
        warning = 'Same name as another included file.';
      } else {
        includedNamesSeen.add(lowerName);
      }
    }

    warningEl.textContent = warning;
    warningEl.hidden = !warning;
    row.classList.toggle('companion-row-warning', !!warning);
  }
}

function onEditCompanionName(release, companion, value) {
  companion.proposedFileName = toSafeFileName(value);
  markDirty(release);
  refreshCompanionWarnings(release);
}

function onToggleCompanionInclude(release, companion, checked) {
  companion.include = checked;
  markDirty(release);
  refreshCompanionWarnings(release);
}

// Shared by the cover gallery and the Discogs candidate picker - both are just a
// radio-button list with different label content, so the list-building/wiring is
// written once here instead of duplicated per caller.
function renderRadioList(container, { items, name, className, isChecked, onSelect, buildContent }) {
  container.innerHTML = '';

  for (const item of items) {
    const label = document.createElement('label');
    label.className = className;

    const radio = document.createElement('input');
    radio.type = 'radio';
    radio.name = name;
    radio.checked = isChecked(item);
    radio.addEventListener('change', () => onSelect(item));

    label.appendChild(radio);
    label.appendChild(buildContent(item));
    container.appendChild(label);
  }
}

// A cover candidate's url is either a remote Discogs image (loads directly) or a local companion
// file's absolute path (e.g. "D:\...\Front.jpg") - the browser can't load a raw filesystem path,
// so that case is routed through the server's local-file endpoint instead, which only serves a
// path this session's own proposal.json already names as a cover candidate.
function resolveCoverImageSrc(url) {
  if (/^https?:\/\//i.test(url)) return url;
  return `/api/sessions/${state.currentSessionId}/local-file?path=${encodeURIComponent(url)}`;
}

function openCoverModal(candidate) {
  const modalImg = document.getElementById('cover-modal-img');
  modalImg.src = resolveCoverImageSrc(candidate.url);
  modalImg.alt = candidate.sourceEdition;
  document.getElementById('cover-modal').showModal();
}

// Mirrors Invoke-ReshelfFfmpegResize's scale-down-only, aspect-preserving filter.
function computeEmbeddedCoverSize(width, height, maxDimension) {
  const scale = Math.min(1, maxDimension / width, maxDimension / height);
  return {
    width: Math.round(width * scale),
    height: Math.round(height * scale),
    resized: scale < 1,
  };
}

function renderCoverGallery(release) {
  renderRadioList(document.getElementById('cover-gallery'), {
    items: release.coverArt.candidates,
    name: 'cover-candidate',
    className: 'cover-candidate',
    isChecked: (candidate) => candidate.url === release.coverArt.chosenCandidateUrl,
    onSelect: (candidate) => onSelectCover(release, candidate.url),
    buildContent: (candidate) => {
      const fragment = document.createDocumentFragment();

      const maxDimension = release.coverArt.targetMaxDimension;
      const embedded = computeEmbeddedCoverSize(candidate.width, candidate.height, maxDimension);
      const size = document.createElement('span');
      size.className = 'cover-size';
      size.textContent = embedded.resized
        ? `${candidate.width}x${candidate.height} → ${embedded.width}x${embedded.height} embedded`
        : `${candidate.width}x${candidate.height} (embedded as is)`;
      size.title = `Embedded cover is limited to ${maxDimension}px on the longest side`;
      fragment.appendChild(size);

      const img = document.createElement('img');
      img.src = resolveCoverImageSrc(candidate.url);
      img.alt = candidate.sourceEdition;
      img.addEventListener('click', (e) => {
        e.preventDefault();
        openCoverModal(candidate);
      });
      fragment.appendChild(img);

      return fragment;
    },
  });
}

function renderDiscogsCandidates(release) {
  const container = document.getElementById('discogs-candidates');

  if (release.discogsMatch.status !== 'ambiguous') {
    container.hidden = true;
    return;
  }
  container.hidden = false;

  renderRadioList(document.getElementById('discogs-candidates-list'), {
    items: release.discogsMatch.candidates,
    name: 'discogs-candidate',
    className: 'discogs-candidate',
    isChecked: (candidate) => candidate.releaseId === release.discogsMatch.selectedReleaseId,
    onSelect: (candidate) => onSelectDiscogsCandidate(release, candidate.releaseId),
    buildContent: (candidate) => {
      const text = document.createElement('span');
      text.textContent = `${candidate.title} (${candidate.year}, ${candidate.format}) - score ${candidate.score}`;
      return text;
    },
  });
}

function markDirty(release) {
  state.dirtyReleaseKeys.add(release.stableKey);
  updateReleaseRowBadge(release);
  updateSaveIndicator();
}

// Only patches the one row's badge/label in place instead of rebuilding the whole
// sidebar on every keystroke - full rebuilds get visibly slow once a session has
// hundreds of releases. If the row isn't currently rendered (e.g. hidden by an
// active filter), there's nothing to patch; renderList() will pick up the new
// status next time filters or selection change it back into view.
function updateReleaseRowBadge(release) {
  const row = document.querySelector(`.release-row[data-stable-key="${release.stableKey}"]`);
  if (!row) return;

  const status = getReleaseStatus(release);
  const badge = row.querySelector('.badge');
  badge.className = `badge badge-${status}`;
  badge.textContent = status;

  const label = row.querySelector('.release-label');
  label.textContent = `${release.proposed.year ?? ''} ${release.proposed.album}`.trim();

  row.classList.toggle('unsaved', state.dirtyReleaseKeys.has(release.stableKey));
}

function updateSaveIndicator() {
  const count = state.dirtyReleaseKeys.size;
  const text = count > 0 ? `${count} unsaved change${count === 1 ? '' : 's'}` : '';
  document.getElementById('unsaved-count').textContent = text;
  document.getElementById('unsaved-count-top').textContent = text;
}

// Mirrors New-ReshelfProposedReleaseNames/Expand-ReshelfNamingTemplate (Reshelf.EditProposal.psm1):
// the artist folder name is just the sanitized artist, and the release folder name is the
// {year}/{album} template with the sanitized album substituted in. toSafeFileName (below) mirrors
// ConvertTo-SafeFileName closely enough for a live preview - it doesn't reproduce the
// reserved-device-name suffixing, which 'propose' still applies for real on Save.
function deriveProposedFolderNames(artist, album, year) {
  const artistFolderName = toSafeFileName(artist);
  const releaseFolderName = state.namingTemplates.releaseFolder
    .replaceAll('{year}', year ?? '')
    .replaceAll('{album}', toSafeFileName(album))
    .trim();
  return { artistFolderName, releaseFolderName };
}

// Called after every Artist/Album/Year edit - a folder name typed by hand is overwritten by the
// next one of these, same as re-running 'propose' would recompute it from scratch.
function updateProposedFolderNames(release) {
  const artist = document.getElementById('field-artist').value;
  const album = document.getElementById('field-album').value;
  const year = document.getElementById('field-year').value;
  const { artistFolderName, releaseFolderName } = deriveProposedFolderNames(artist, album, year);

  release.proposed.artistFolderName = artistFolderName;
  release.proposed.releaseFolderName = releaseFolderName;
  document.getElementById('field-artist-folder').value = artistFolderName;
  document.getElementById('field-release-folder').value = releaseFolderName;
  renderBeforeAfterTable(release);
}

function onEditArtist(release, value) {
  for (const track of release.tracks) {
    track.tags.artist = value;
    track.tags.albumArtist = value;
  }
  updateProposedFolderNames(release);
  markDirty(release);
}

function onEditAlbum(release, value) {
  release.proposed.album = value;
  for (const track of release.tracks) {
    track.tags.album = value;
  }
  updateProposedFolderNames(release);
  markDirty(release);
}

function onEditYear(release, value) {
  const year = value === '' ? null : parseInt(value, 10);
  release.proposed.year = year;
  for (const track of release.tracks) {
    track.tags.year = year;
  }
  updateProposedFolderNames(release);
  markDirty(release);
}

function onEditArtistFolderName(release, value) {
  release.proposed.artistFolderName = value;
  renderBeforeAfterTable(release);
  markDirty(release);
}

function onEditReleaseFolderName(release, value) {
  release.proposed.releaseFolderName = value;
  renderBeforeAfterTable(release);
  markDirty(release);
}

// Mirrors ConvertTo-SafeFileName (Reshelf.Common.psm1) so a title edit here produces
// the same safe filename the Implementation module would derive from it.
const INVALID_FILENAME_CHARS = /[\x00-\x1f<>:"/\\|?*]/g;
const RESERVED_DEVICE_NAMES = new Set([
  'CON', 'PRN', 'AUX', 'NUL',
  'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
  'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
]);

function toSafeFileName(name) {
  let result = name.replace(INVALID_FILENAME_CHARS, '_').replace(/[. ]+$/, '');
  if (RESERVED_DEVICE_NAMES.has(result.toUpperCase())) result += '_';
  return result;
}

// The leading "NN " / "NN - " prefix is the continuous cross-disc filename number
// (never the per-disc proposedTrackNumber), so it's kept as-is and only the title
// body is replaced - mirrors Split-ReshelfTrackFileName (Reshelf.Implementation.psm1).
function deriveTrackFileName(currentFileName, newTitle) {
  const dot = currentFileName.lastIndexOf('.');
  const extension = dot >= 0 ? currentFileName.slice(dot) : '';
  const withoutExtension = dot >= 0 ? currentFileName.slice(0, dot) : currentFileName;
  const prefixMatch = withoutExtension.match(/^(\d+\s*[-–]\s*|\d+\s+)/);
  const prefix = prefixMatch ? prefixMatch[0] : '';
  return prefix + toSafeFileName(newTitle) + extension;
}

function onEditTrackField(release, track, field, value) {
  if (field === 'proposedDiscNumber' || field === 'proposedTrackNumber') {
    // Unlike year, these are non-nullable integers (>= 1) in the schema, so an
    // empty/incomplete number input (parseInt('', 10) === NaN) must be ignored
    // rather than written through - a stray NaN/null here would silently corrupt
    // track ordering data with no validation warning until 'apply' runs.
    const parsed = parseInt(value, 10);
    if (!Number.isInteger(parsed) || parsed < 1) {
      return;
    }
    if (field === 'proposedDiscNumber') {
      track.proposedDiscNumber = parsed;
      track.tags.discNumber = parsed;
    } else {
      track.proposedTrackNumber = parsed;
      track.tags.track = parsed;
    }
  } else if (field === 'proposedTitle') {
    track.proposedTitle = value;
    track.tags.title = value;
    track.proposedFileName = deriveTrackFileName(track.proposedFileName, value);
    renderBeforeAfterTable(release);
  }
  markDirty(release);
}

function onSelectCover(release, url) {
  release.coverArt.chosenCandidateUrl = url;
  markDirty(release);
}

// Unlike every other edit in this file, the uploaded file's bytes are written to disk
// immediately (via the manual-cover endpoint) rather than staying purely in-memory until Save -
// Implementation reads cover art from a disk path (chosenCandidateUrl), not from proposal.json's
// in-memory shape, so the bytes must exist on disk before Apply can ever run. Only the candidate
// pointer added to release.coverArt below follows the normal deferred-Save path via markDirty.
async function onManualCoverFileChosen(e) {
  const file = e.target.files[0];
  e.target.value = ''; // allow re-choosing the same filename again later
  if (!file) return;

  const found = findRelease(state.selectedReleaseKey);
  if (!found) return;
  await uploadManualCover(found.release, file);
}

async function uploadManualCover(release, file) {
  const status = document.getElementById('manual-cover-status');
  status.textContent = 'Uploading...';
  try {
    const url = `/api/sessions/${state.currentSessionId}/manual-cover?filename=${encodeURIComponent(file.name)}`;
    const result = await fetchJson(url, {
      method: 'POST',
      headers: { 'Content-Type': file.type || 'application/octet-stream' },
      body: file,
    });
    release.coverArt.candidates.push({
      url: result.url,
      sourceEdition: 'manual upload',
      width: result.width,
      height: result.height,
    });
    release.coverArt.chosenCandidateUrl = result.url;
    renderCoverGallery(release);
    markDirty(release);
    status.textContent = 'Uploaded - click Save to keep this selection.';
  } catch (err) {
    status.textContent = `Upload failed: ${err.message}`;
  }
}

function onSelectDiscogsCandidate(release, releaseId) {
  release.discogsMatch.selectedReleaseId = releaseId;
  markDirty(release);
}

function onEditNotes(release, value) {
  release.humanReview.notes = value;
  markDirty(release);
}

function onToggleApprove(release, checked) {
  release.humanReview.resolved = checked;
  if (checked && release.humanReview.rejected) {
    // Approve and Reject are mutually exclusive - a release can't be both "apply this" and
    // "never apply this" at once.
    release.humanReview.rejected = false;
    document.getElementById('reject-checkbox').checked = false;
  }
  markDirty(release);
}

function onToggleReject(release, checked) {
  release.humanReview.rejected = checked;
  if (checked) {
    // Rejecting is itself a completed review decision (see plan/03/07), and mutually exclusive
    // with Approve - a release can't be both "apply this" and "never apply this" at once.
    release.humanReview.resolved = true;
    document.getElementById('approve-checkbox').checked = false;
  }
  markDirty(release);
}

async function saveProposal() {
  const saveStatus = document.getElementById('save-status');
  try {
    await fetchJson(`/api/sessions/${state.currentSessionId}/proposal`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(state.proposal, null, 2),
    });
    state.dirtyReleaseKeys.clear();
    updateSaveIndicator();
    renderList();
    saveStatus.textContent = `Saved at ${new Date().toLocaleTimeString()}`;
  } catch (err) {
    saveStatus.textContent = `Save failed: ${err.message}`;
  }
}

window.addEventListener('beforeunload', (e) => {
  if (isDirty()) {
    e.preventDefault();
    e.returnValue = '';
  }
});

// --- Lossy tracker view --------------------------------------------------------------

async function loadLossyLedger() {
  const status = document.getElementById('lossy-status');
  try {
    status.textContent = 'Loading...';
    state.lossy.entries = await fetchJson('/api/lossy');
    status.textContent = '';
    renderLossyTable();
  } catch (err) {
    status.textContent = `Error: ${err.message}`;
  }
}

function getFilteredLossyEntries() {
  const entries = state.lossy.entries;
  if (!state.lossy.filterStatus) return entries;
  return entries.filter((e) => e.status === state.lossy.filterStatus);
}

function renderLossyTable() {
  const table = document.getElementById('lossy-table');
  const tbody = table.querySelector('tbody');
  const emptyMsg = document.getElementById('lossy-empty');
  tbody.innerHTML = '';

  const rows = getFilteredLossyEntries();
  if (rows.length === 0) {
    table.hidden = true;
    emptyMsg.hidden = false;
    return;
  }
  table.hidden = false;
  emptyMsg.hidden = true;

  for (const entry of rows) {
    const row = document.createElement('tr');

    const cell = (text) => {
      const td = document.createElement('td');
      td.textContent = text ?? '';
      return td;
    };
    row.appendChild(cell(entry.artist));
    row.appendChild(cell(entry.album));
    row.appendChild(cell(entry.year));
    row.appendChild(cell(entry.format));

    const statusCell = document.createElement('td');
    const statusSelect = document.createElement('select');
    for (const value of ['pending-upgrade', 'upgraded', 'ignored']) {
      const option = document.createElement('option');
      option.value = value;
      option.textContent = value;
      option.selected = value === entry.status;
      statusSelect.appendChild(option);
    }
    statusSelect.addEventListener('change', () => onLossyRowChange(entry, { status: statusSelect.value }));
    statusCell.appendChild(statusSelect);
    row.appendChild(statusCell);

    row.appendChild(cell(entry.targetPath));
    row.appendChild(cell(entry.firstDetectedUtc));
    row.appendChild(cell(entry.lastCheckedUtc));

    const notesCell = document.createElement('td');
    const notesInput = document.createElement('input');
    notesInput.type = 'text';
    notesInput.value = entry.notes ?? '';
    notesInput.addEventListener('change', () => onLossyRowChange(entry, { notes: notesInput.value }));
    notesCell.appendChild(notesInput);
    row.appendChild(notesCell);

    const deleteCell = document.createElement('td');
    const deleteBtn = document.createElement('button');
    deleteBtn.type = 'button';
    deleteBtn.textContent = 'Delete';
    deleteBtn.addEventListener('click', () => onLossyRowDelete(entry));
    deleteCell.appendChild(deleteBtn);
    row.appendChild(deleteCell);

    tbody.appendChild(row);
  }
}

async function onLossyRowChange(entry, changes) {
  const status = document.getElementById('lossy-status');
  const body = { status: entry.status, notes: entry.notes ?? '', ...changes };
  try {
    const updated = await fetchJson(`/api/lossy/${entry.stableKey}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    Object.assign(entry, updated);
    status.textContent = `Saved at ${new Date().toLocaleTimeString()}`;
    renderLossyTable();
  } catch (err) {
    status.textContent = `Save failed: ${err.message}`;
  }
}

async function onLossyRowDelete(entry) {
  if (!window.confirm(`Permanently remove the lossy-tracking entry for "${entry.artist} - ${entry.album}"? This cannot be undone.`)) {
    return;
  }
  const status = document.getElementById('lossy-status');
  try {
    await fetchJson(`/api/lossy/${entry.stableKey}`, { method: 'DELETE' });
    state.lossy.entries = state.lossy.entries.filter((e) => e.stableKey !== entry.stableKey);
    status.textContent = 'Removed.';
    renderLossyTable();
  } catch (err) {
    status.textContent = `Delete failed: ${err.message}`;
  }
}

function triggerDownload(filename, mimeType, content) {
  const blob = new Blob([content], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

function toCsvValue(value) {
  const text = value === null || value === undefined ? '' : String(value);
  if (/[",\n]/.test(text)) return `"${text.replace(/"/g, '""')}"`;
  return text;
}

function exportLossyLedger(format) {
  const rows = getFilteredLossyEntries();
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');

  if (format === 'json') {
    triggerDownload(`lossy-tracking-${timestamp}.json`, 'application/json', JSON.stringify(rows, null, 2));
    return;
  }

  const columns = ['stableKey', 'artist', 'album', 'year', 'format', 'status', 'targetPath', 'firstDetectedUtc', 'lastCheckedUtc', 'upgradedUtc', 'notes'];
  const lines = [columns.join(',')];
  for (const row of rows) {
    lines.push(columns.map((c) => toCsvValue(row[c])).join(','));
  }
  triggerDownload(`lossy-tracking-${timestamp}.csv`, 'text/csv', lines.join('\n'));
}

async function loadNamingTemplates() {
  try {
    const templates = await fetchJson('/api/naming-templates');
    state.namingTemplates = templates;
  } catch (err) {
    // Keeps the built-in default (state's initial value) - a live folder-name preview that's
    // occasionally out of sync with a non-default template is far less harmful than losing the
    // whole page over a secondary feature.
    console.warn('Could not load naming templates, using default:', err);
  }
}

window.addEventListener('DOMContentLoaded', () => {
  wireStaticControls();
  loadNamingTemplates();
  loadCurrentSession();
});
