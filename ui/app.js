const state = {
  dirHandle: null,
  fileHandle: null,
  proposal: null,
  selectedReleaseKey: null,
  filters: { needsReviewOnly: false, ambiguousOnly: false },
  dirty: false,
  lastError: null,
};

function checkBrowserSupport() {
  const supported = 'showDirectoryPicker' in window;
  if (!supported) {
    document.getElementById('unsupported-banner').hidden = false;
    document.getElementById('open-folder-btn').disabled = true;
  }
  return supported;
}

function wireStaticControls() {
  document.getElementById('open-folder-btn').addEventListener('click', openSessionFolder);
  document.getElementById('permission-retry-btn').addEventListener('click', retryPermission);
  document.getElementById('filter-needs-review').addEventListener('change', (e) => {
    state.filters.needsReviewOnly = e.target.checked;
    renderList();
  });
  document.getElementById('filter-ambiguous').addEventListener('change', (e) => {
    state.filters.ambiguousOnly = e.target.checked;
    renderList();
  });
  document.getElementById('save-btn').addEventListener('click', saveProposal);
}

function setSessionStatus(text) {
  document.getElementById('session-status').textContent = text;
}

function showPermissionRetry() {
  document.getElementById('permission-retry-btn').hidden = false;
  setSessionStatus(state.lastError ? `Error: ${state.lastError}` : 'Permission needed.');
}

function hidePermissionRetry() {
  document.getElementById('permission-retry-btn').hidden = true;
}

async function openSessionFolder() {
  try {
    state.dirHandle = await window.showDirectoryPicker();
    await loadProposal();
  } catch (err) {
    if (err.name !== 'AbortError') {
      state.lastError = err.message;
      showPermissionRetry();
    }
  }
}

async function verifyPermission(handle, mode) {
  const options = { mode };
  if ((await handle.queryPermission(options)) === 'granted') {
    return true;
  }
  return (await handle.requestPermission(options)) === 'granted';
}

async function loadProposal() {
  try {
    state.fileHandle = await state.dirHandle.getFileHandle('proposal.json');

    if (!(await verifyPermission(state.fileHandle, 'readwrite'))) {
      state.lastError = 'Read/write permission was not granted for this folder.';
      showPermissionRetry();
      return;
    }

    const file = await state.fileHandle.getFile();
    state.proposal = JSON.parse(await file.text());
    state.selectedReleaseKey = null;
    state.dirty = false;
    state.lastError = null;

    hidePermissionRetry();
    setSessionStatus(`Loaded: proposal.json (session ${state.proposal.sessionId})`);
    document.getElementById('detail-panel').hidden = true;
    renderList();
  } catch (err) {
    state.lastError = err.message;
    showPermissionRetry();
  }
}

async function retryPermission() {
  if (!state.dirHandle) {
    await openSessionFolder();
    return;
  }
  await loadProposal();
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

  const byArtist = new Map();
  for (const entry of flattenReleases(state.proposal)) {
    const status = getReleaseStatus(entry.release);
    if (state.filters.needsReviewOnly && status !== 'needsReview') continue;
    if (state.filters.ambiguousOnly && status !== 'ambiguous') continue;

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
}

function selectRelease(stableKey) {
  state.selectedReleaseKey = stableKey;
  renderList();
  renderDetail();
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
  renderCoverGallery(release);
  renderDiscogsCandidates(release);

  const notesField = document.getElementById('notes-field');
  notesField.value = release.humanReview.notes;
  notesField.oninput = () => onEditNotes(release, notesField.value);

  const approveCheckbox = document.getElementById('approve-checkbox');
  approveCheckbox.checked = release.humanReview.resolved;
  approveCheckbox.onchange = () => onToggleApprove(release, approveCheckbox.checked);
}

function renderBeforeAfterTable(release) {
  const tbody = document.querySelector('#before-after-table tbody');
  tbody.innerHTML = '';

  const folderRow = document.createElement('tr');
  const folderBefore = document.createElement('td');
  folderBefore.textContent = release.sourceFolderPath;
  const folderAfter = document.createElement('td');
  folderAfter.textContent = `${release.proposed.artistFolderName}\\${release.proposed.releaseFolderName}`;
  folderRow.appendChild(folderBefore);
  folderRow.appendChild(folderAfter);
  tbody.appendChild(folderRow);

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

function renderCoverGallery(release) {
  renderRadioList(document.getElementById('cover-gallery'), {
    items: release.coverArt.candidates,
    name: 'cover-candidate',
    className: 'cover-candidate',
    isChecked: (candidate) => candidate.url === release.coverArt.chosenCandidateUrl,
    onSelect: (candidate) => onSelectCover(release, candidate.url),
    buildContent: (candidate) => {
      const img = document.createElement('img');
      img.src = candidate.url;
      img.alt = candidate.sourceEdition;
      return img;
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
  state.dirty = true;
  updateReleaseRowBadge(release);
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
}

function onEditArtist(release, value) {
  for (const track of release.tracks) {
    track.tags.artist = value;
    track.tags.albumArtist = value;
  }
  release.proposed.artistFolderName = value;
  markDirty(release);
}

function onEditAlbum(release, value) {
  release.proposed.album = value;
  for (const track of release.tracks) {
    track.tags.album = value;
  }
  markDirty(release);
}

function onEditYear(release, value) {
  const year = value === '' ? null : parseInt(value, 10);
  release.proposed.year = year;
  for (const track of release.tracks) {
    track.tags.year = year;
  }
  markDirty(release);
}

function onEditReleaseFolderName(release, value) {
  release.proposed.releaseFolderName = value;
  markDirty(release);
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
  } else if (field === 'proposedFileName') {
    track.proposedFileName = value;
  }
  markDirty(release);
}

function onSelectCover(release, url) {
  release.coverArt.chosenCandidateUrl = url;
  markDirty(release);
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
  markDirty(release);
}

async function saveProposal() {
  const saveStatus = document.getElementById('save-status');
  try {
    if (!(await verifyPermission(state.fileHandle, 'readwrite'))) {
      showPermissionRetry();
      return;
    }

    const previousText = await (await state.fileHandle.getFile()).text();

    const backupHandle = await state.dirHandle.getFileHandle('proposal.backup.json', { create: true });
    const backupWritable = await backupHandle.createWritable();
    await backupWritable.write(previousText);
    await backupWritable.close();

    const writable = await state.fileHandle.createWritable();
    await writable.write(JSON.stringify(state.proposal, null, 2));
    await writable.close();

    state.dirty = false;
    saveStatus.textContent = `Saved at ${new Date().toLocaleTimeString()}`;
  } catch (err) {
    saveStatus.textContent = `Save failed: ${err.message}`;
  }
}

window.addEventListener('DOMContentLoaded', () => {
  if (!checkBrowserSupport()) return;
  wireStaticControls();
});
