# 11 — Lossy tracking (as-is, merged)

Status: Draft | Version: 0.3 | Last updated: 2026-10-14

## Scope

Area **LSY**. The lossy ledger (a library-wide list of releases kept in a
lossy format, such as mp3, so they can be upgraded to lossless later) and the
propose-time logic that reads and writes it. Sources:
`br/as-is-from-docs/11-lossy-tracking.md` (`AS-DOC-LSY-001`–`032`, from
`legacy/tests/Reshelf.LossyTracking.Tests.ps1`,
`legacy/tests/Reshelf.EditProposal.Tests.ps1`, `legacy/plan/09-lossy-lossless-
tracking.md`, `legacy/plan/06-edit-proposal-module.md`, `MANIFESTO.md` §6 and
`legacy/README.md`) and `br/as-is-from-code/11-lossy-tracking.md`
(`AS-CODE-LSY-001`–`014`, read only from
`legacy/scripts/common/Reshelf.LossyTracking.psm1`).

**ID numbering for this area:** 22 `AS-LSY-*` requirements, `AS-LSY-001`–
`022`. The ledger-CRUD half (`AS-DOC-LSY-001`–`019` against
`AS-CODE-LSY-001`–`014`) merges cleanly, with four doc items that all stem
from the single code fact "re-add only refreshes `lastCheckedUtc` and
`targetPath`" folded into one item (`AS-LSY-007`), the same way `AS-DSC-002`
folds three sources into one. The propose-time half
(`AS-DOC-LSY-020`–`031`) describes the exact same code this area's own
`AS-CODE-LSY-*` reading never saw — that logic lives in
`Reshelf.EditProposal.psm1`, read as area **PRP**'s code view, not LSY's —
and the PRP merge (`08-proposal-naming-and-tags.md`) had already reconciled
most of it by the time this area was merged, deferring "the other lossy
cases" here explicitly (see `AS-PRP-092`). Two doc items
(`AS-DOC-LSY-023`, `029`) turned out to be exact duplicates of facts
`AS-PRP-097` and `AS-PRP-078` already state in full — no new `AS-LSY` item is
created for them, the same way the APL merge redirected `AS-DOC-APL-046`–
`048` to `AS-REC-085`–`089` with no gap. The remaining doc items in that range
(`020`–`022`, `024`–`028`) keep their own `AS-LSY` items, since they own
detail — the `previousLossy` object's shape, which ledger fields a propose
run actually touches — that no `AS-PRP` item states. `AS-DOC-LSY-030`/`031`
are themselves pure duplicates-with-extra-sources of already-merged
`AS-APL-061`/`062` ("same rule... keeps its plan and README sources" per the
doc's own text); no new `AS-LSY` item is created for them either, and their
extra `plan`/`README` citations have been folded back into `AS-APL-061`/`062`
directly (see that file's changelog). `AS-DOC-LSY-032` becomes `AS-LSY-022`.

**Contradictions resolved while merging this area:** none. Neither source
file for LSY carries an `AS-DOC-DEF-*`/`AS-CODE-DEF-*` entry of type
"Contradiction".

**Suspected defects carried forward:** one new finding — `Set-
ReshelfLossyTrackingIgnored` (the dedicated ignore mutator, used by `lossy
ignore`) leaves `upgradedUtc` untouched, while the generic status setter
clears it on every move away from `upgraded`; ignoring a previously-upgraded
entry through the dedicated path can leave a stale `upgradedUtc` behind
alongside `status = ignored`. See `91-suspected-defects-carryforward.md`
(`CF-LSY-001`).

## Ledger file

### AS-LSY-001 — One library-wide ledger file, in the data home
Status: Draft | Source: AS-DOC-LSY-001; AS-CODE-LSY-001

Releases with lossy source files are logged in `lossy-tracking.json`,
directly under the data home (the same folder as the apply log, not a
subfolder). There is one ledger for the whole library, not one per session —
it keeps entries across every run and session. Data home location: see
[01-data-and-storage.md](01-data-and-storage.md).

Example: `<dataHome>\lossy-tracking.json`.

### AS-LSY-002 — Missing file reads as empty; a schema-invalid file throws, naming the path
Status: Draft | Source: AS-DOC-LSY-002; AS-DOC-LSY-003; AS-CODE-LSY-002

When the ledger file doesn't exist, reading it returns an empty list — no
error. When the file exists but fails the `lossy-tracking` schema, reading it
throws `"Lossy-tracking ledger at '<path>' does not match the lossy-tracking
schema."`, naming the file.

Example: new data home, no file → 0 entries.

Example: file content `[{"stableKey":"missing-other-fields"}]` → error
naming `<dataHome>\lossy-tracking.json`.

### AS-LSY-003 — An entry holds the release, its location, its format and its status; status is one of exactly three values
Status: Draft | Source: AS-DOC-LSY-004; AS-CODE-LSY-006

Each entry has: `stableKey`, `artist`, `album`, `year`, `targetPath` (latest
known location), `format`, `status`, `firstDetectedUtc`, `lastCheckedUtc`,
`upgradedUtc` and `notes`. `status` is exactly one of `pending-upgrade`,
`upgraded`, `ignored`, enforced by `ValidateSet` on the generic status setter
and matched by the default a new entry gets.

Example:
```json
{ "stableKey": "a1b2c3d4e5f60708", "artist": "ZZ Top", "album": "XXX", "year": 1999,
  "targetPath": "E:\\Music\\ZZ Top\\1999 XXX", "format": "mp3", "status": "pending-upgrade",
  "firstDetectedUtc": "2026-09-19T10:00:00.000Z", "lastCheckedUtc": "2026-09-19T10:00:00.000Z",
  "upgradedUtc": null, "notes": "" }
```

### AS-LSY-004 — Every mutation rewrites the whole ledger as one schema-valid file
Status: Draft | Source: AS-DOC-LSY-005; AS-CODE-LSY-013

Add, set target path, set status, remove and ignore each write the entire
ledger array back to disk as one JSON file (schema `lossy-tracking`, depth
10) — there is no row-level or partial persistence; every mutation
round-trips the full in-memory ledger, and the result always passes the
schema check.

Example: add `ZZ Top / XXX`, then add `John 5 / God Told Me To`, then remove
the first → the file is still schema-valid.

## Reading one entry

### AS-LSY-005 — An entry is found by its stable key, or nothing is returned
Status: Draft | Source: AS-DOC-LSY-006; AS-CODE-LSY-003

A lookup by stable key returns the first matching row. When no entry has that
key, it returns nothing — no error.

Example: key `a1b2c3d4e5f60708` → entry with `artist = ZZ Top`. Example: key
`doesnotexist00000` → nothing.

## Adding an entry

### AS-LSY-006 — A new entry starts pending-upgrade, with matching timestamps and empty notes
Status: Draft | Source: AS-DOC-LSY-007; AS-CODE-LSY-005

Adding an entry for a stable key with no existing row creates it with:
`status = pending-upgrade`, `firstDetectedUtc = lastCheckedUtc` = the current
time (UTC, `yyyy-MM-ddTHH:mm:ss.fffZ`), `upgradedUtc = null`, `notes = ''`
(empty string, not null).

Example: add `ZZ Top / XXX / 1999`, `mp3`, at `2026-09-19T10:00:00Z` →
`status = pending-upgrade`, `firstDetectedUtc = lastCheckedUtc`, `upgradedUtc
= null`.

### AS-LSY-007 — Re-adding an existing entry only refreshes lastCheckedUtc and targetPath; everything else, including status, stays
Status: Draft | Source: AS-DOC-LSY-008; AS-DOC-LSY-009; AS-DOC-LSY-010; AS-DOC-LSY-011; AS-CODE-LSY-004

Adding an entry for a stable key that already exists does not create a
second row. It sets `lastCheckedUtc` to the current time and `targetPath` to
the newly given value — every other field (`artist`, `album`, `year`,
`format`, `status`, `firstDetectedUtc`, `notes`, `upgradedUtc`) is left
exactly as it was. The target path is treated as "latest known location", not
a first-sighting snapshot, since `targetRoot` or the naming templates can
change between runs and leave a stale path otherwise. This holds whatever the
current status is: an `ignored` entry stays `ignored`, an `upgraded` entry
stays `upgraded` with its `upgradedUtc` unchanged, on a repeat sighting.

Example: add at `2026-09-19T10:00:00Z`, add again at
`2026-09-20T11:00:00Z` → `firstDetectedUtc = 2026-09-19T10:00:00Z`,
`lastCheckedUtc = 2026-09-20T11:00:00Z`.

Example: first `E:\OldRoot\ZZ Top\1999 XXX`, then
`E:\Music\ZZ Top\1999 XXX` → `targetPath = E:\Music\ZZ Top\1999 XXX`,
`status` unchanged.

Example: entry `ignored`, added again → `status = ignored`. Example: entry
`upgraded` with `upgradedUtc = 2026-09-21T00:00:00.000Z`, added again →
`status = upgraded`, `upgradedUtc = 2026-09-21T00:00:00Z`.

## Changing an entry

### AS-LSY-008 — Setting the target path changes only that field
Status: Draft | Source: AS-DOC-LSY-012; AS-CODE-LSY-008

The target path of an existing entry can be set directly. Status and every
other field stay.

Example: `E:\Music\ZZ Top\1999 XXX` → set to
`E:\Music\ZZ Top\1999 XXX (Edited)`; `status = pending-upgrade`.

### AS-LSY-009 — Setting status to upgraded stamps upgradedUtc, but only if it isn't already set
Status: Draft | Source: AS-DOC-LSY-013; AS-DOC-LSY-014; AS-CODE-LSY-010

The generic status setter accepts any of the three status values. Setting it
to `upgraded` sets `upgradedUtc` to the current time — but only when it isn't
already set, so re-saving an already-`upgraded` entry (for example, a
notes-only edit) does not bump the timestamp forward again.

Example: `pending-upgrade` → set `upgraded` → `upgradedUtc` is not empty.

### AS-LSY-010 — Moving status away from upgraded always clears upgradedUtc
Status: Draft | Source: AS-DOC-LSY-015; AS-CODE-LSY-010

When the generic status setter changes status from `upgraded` to anything
else, `upgradedUtc` becomes empty again — unconditionally.

Example: set `upgraded`, then set `pending-upgrade` → `upgradedUtc = null`.

### AS-LSY-011 — Notes change only when new notes are explicitly given; an empty string is a deliberate clear, not "no change"
Status: Draft | Source: AS-DOC-LSY-016; AS-CODE-LSY-011

A status change can also set the notes. When `Notes` isn't supplied at all,
the old notes stay. The setter tells "not supplied" apart from "supplied as
an empty string" (which clears the notes) by checking whether the parameter
was bound (`$PSBoundParameters.ContainsKey('Notes')`), not by the string
value itself — a plain string parameter can't otherwise distinguish an
omitted argument from an explicit `''`, since PowerShell binds both the same
way.

Example: set `ignored` with notes `not chasing this one` → `notes = not
chasing this one`. Example: set `ignored` with `first note`, then set
`pending-upgrade` without notes → `notes = first note`.

### AS-LSY-012 — An operation on an unknown stable key warns and changes nothing; never a thrown error
Status: Draft | Source: AS-DOC-LSY-017; AS-CODE-LSY-007; AS-CODE-LSY-014

Set target path, set status, remove and ignore, given a stable key that
isn't in the ledger, each emit a warning and return the ledger unchanged —
never a thrown exception. This is consistent across all four mutators; only
`Add` creates a row when one is missing (`AS-LSY-006`) — every other function
treats "nothing to do" as a soft, non-fatal outcome.

Example: ledger with `a1b2c3d4e5f60708` (`pending-upgrade`,
`E:\Music\ZZ Top\1999 XXX`); set status `ignored` for `doesnotexist0000` →
warning; still 1 entry with `status = pending-upgrade`.

### AS-LSY-013 — Remove permanently deletes the entry; other entries stay
Status: Draft | Source: AS-DOC-LSY-018; AS-CODE-LSY-012

Remove deletes the row with the given stable key, distinct from marking it
`ignored` (which keeps the row, just flagged as deliberately not upgrading).
It's for a mistaken or duplicate entry, or one the user no longer wants
tracked at all.

Example: entries `a1b2c3d4e5f60708` (ZZ Top) and `b2c3d4e5f6070819`
(John 5); remove the first → only `b2c3d4e5f6070819` remains.

### AS-LSY-014 — Ignore keeps the entry and records the decision, but — unlike the generic setter — never touches upgradedUtc itself — carries CF-LSY-001
Status: Draft | Source: AS-DOC-LSY-019; AS-CODE-LSY-009; carried forward: see `91-suspected-defects-carryforward.md` (`CF-LSY-001`)

Ignore sets the status to `ignored`. The entry stays in the ledger, so "I
know this one is mp3, I don't care" stays different from "never noticed".
The dedicated ignore setter only ever touches `status` — unlike the generic
status setter (`AS-LSY-010`), it does not clear `upgradedUtc` when moving an
entry away from `upgraded`.

Example: ignore `a1b2c3d4e5f60708` → `status = ignored`, entry still
present.

Carried forward: `lossy ignore` (the CLI command, per `AS-LSY-022`) calls
this dedicated setter, not the generic one. Ignoring an entry that was
previously `upgraded` leaves its old `upgradedUtc` timestamp in place even
though `status` no longer says `upgraded` — an inconsistent combination
`AS-LSY-010`'s own rule would never produce through the generic setter. No
test exercises ignoring an already-`upgraded` entry.

## Lossy parts of the proposal

The target-action decision itself (`skip-existing-identical`, `create-new`,
`update-existing`, `conflict`) and most of its lossy-specific branches are
merged in [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md)
(`AS-PRP-078`–`081`, `089`, `092`, `094`, `097`) — that code lives in
`Reshelf.EditProposal.psm1`, read as area PRP's code view. The items below
own what's specific to the ledger side of that interaction: which ledger
fields a propose run actually touches, and the shape of the `previousLossy`
object, neither of which any `AS-PRP` item states.

### AS-LSY-015 — Propose logs every lossy source release as pending-upgrade, with its proposed target path — resolves AS-DOC-DEF-099, carries CF-LSY-002
Status: Draft | Source: AS-DOC-LSY-020; AS-DOC-LSY-021; cross-referenced with `AS-PRP-097` (the `log-for-upgrade` action and the unconditional upsert), `AS-LSY-006`/`007` (add/refresh mechanics); resolves `AS-DOC-DEF-099` (see `90-contradictions-resolution.md`); carried forward: see `91-suspected-defects-carryforward.md` (`CF-LSY-002`, citing `AS-DOC-DEF-098`)

When a release's source files are lossy, the proposal marks it `isLossy =
true` with `lossyLossless.action = log-for-upgrade`, and propose itself adds
(or refreshes) the release's ledger entry — before review and apply — with
the release's *proposed* target path, using the same add mechanics as
`AS-LSY-006`/`007`.

Example: `Some Band\2010 Some Album\01 Track.mp3` →
`lossyLossless = { isLossy: true, action: log-for-upgrade }`; ledger entry
for its stable key, `status = pending-upgrade`,
`targetPath = <targetRoot>\Some Band\2010 Some Album`.

`AS-DOC-DEF-099` asked whether propose logs a lossy release only when it
proposes `create-new`, per plan 09, or always, per the README/MANIFESTO §6.
**Resolved: the README/MANIFESTO are right, plan 09 understates it** —
`AS-PRP-097` already establishes that the ledger upsert happens whenever the
source is lossy, independently of `targetAction` (so also on `conflict` or
`skip-existing-identical`, which no test exercises directly but which the
same unconditional code path covers).

Carried forward: `AS-DOC-DEF-098` observed that this unconditional,
before-review logging means a rejected or never-applied release still
leaves a `pending-upgrade` ledger entry pointing at a target path that may
never come to exist. See `CF-LSY-002`.

### AS-LSY-016 — Propose never resets an ignored or upgraded ledger entry back to pending
Status: Draft | Source: AS-DOC-LSY-022; cross-referenced with `AS-LSY-007`

When propose sees a lossy release whose ledger entry is already `ignored` (or
`upgraded`), the entry keeps that status — only its `lastCheckedUtc` and
`targetPath` move, per the ledger's own re-add rule (`AS-LSY-007`).

Example: `Some Band / Some Album / 2010` entry set to `ignored`, then propose
runs on `01 Track.mp3` → `status = ignored`.

A lossless release with no lossy target and no matching ledger entry gets
`lossyLossless = { isLossy: false, action: none }` — this is the `else`
branch of `AS-PRP-097`'s own action priority; no new item is needed here
(`AS-DOC-LSY-023` redirects straight to `AS-PRP-097`).

### AS-LSY-017 — A lossless source over a lossy target at the same proposed path needs no ledger entry
Status: Draft | Source: AS-DOC-LSY-024; cross-referenced with `AS-PRP-092` (the `update-existing` decision), `AS-PRP-097` (the `replace-existing` summary action)

When the existing target folder is found at the proposed path, holds lossy
files, and the source is lossless, the proposal is the upgrade case:
`targetAction = update-existing`, `lossyLossless.action = replace-existing`.
No ledger entry is needed for this case — the upgrade is detected purely from
comparing the source to the on-disk target.

Example: source `Some Band\2010 Some Album\01 Track.flac`, target
`Some Band\2010 Some Album\01 Track.mp3`, no ledger entry →
`update-existing` / `replace-existing`.

### AS-LSY-018 — A lossy folder found via the apply log at a different path is left alone; the previousLossy object describes it
Status: Draft | Source: AS-DOC-LSY-025; cross-referenced with `AS-PRP-092` (the `create-new`-when-different-path decision)

When the lossy folder found for this stable key (via the apply log) sits at
a path other than the proposed one, apply would only write the new, proposed
path and leave the old folder as-is. The proposal is
`targetAction = create-new` with
`lossyLossless.action = previously-lossy-different-location`, and needs
review. `previousLossy` describes the old folder; without a ledger entry for
it, its `format` comes from the extension of the first audio file found
there, and `firstDetectedUtc` from the folder's own creation time on disk.

Example: apply-log entry for `Some Band / Some Album / 2010` points to
`Some Band\2010 Some Album (Old Name)` with `01 Track.mp3`; source is flac →
`create-new`, `previously-lossy-different-location`,
`previousLossy.targetPath = <targetRoot>\Some Band\2010 Some Album (Old Name)`,
`previousLossy.format = mp3`, review required.

### AS-LSY-019 — A ledger name-search hit with a surviving old folder also gives previously-lossy-different-location
Status: Draft | Source: AS-DOC-LSY-026; cross-referenced with `AS-PRP-079`, `AS-PRP-080`, `AS-PRP-081`, `AS-PRP-097`

When nothing is found by stable key (plain `create-new`) and the source is
lossless, the app also searches the ledger by name — every `pending-upgrade`
entry, by normalized artist, exact year, and the same-release album check
(`AS-PRP-078`). When a match's old folder still holds lossy files,
`lossyLossless.action = previously-lossy-different-location` with
`previousLossy.targetExists = true`; the release needs review;
`targetAction` stays `create-new`; the old ledger entry stays
`pending-upgrade`, untouched; nothing touches the old folder.

Example: ledger `The Egg / Forwards Special Edition / 2006` at
`The Egg\2006 Forwards Special Edition` (mp3); new source
`The Egg\2006 Forwards` (flac) → `create-new`,
`previously-lossy-different-location`,
`previousLossy.targetPath = <targetRoot>\The Egg\2006 Forwards Special Edition`,
`targetExists = true`; old folder still exists; old entry stays
`pending-upgrade`.

### AS-LSY-020 — A name-search hit whose old folder is gone gives previously-lossy-target-missing
Status: Draft | Source: AS-DOC-LSY-027; cross-referenced with `AS-PRP-097`

When the name search finds a pending entry but its old target folder no
longer exists, `lossyLossless.action = previously-lossy-target-missing` with
`previousLossy.targetExists = false`. The release needs review — the folder
may have been deleted, or the configured target root isn't the real
collection.

Example: ledger `Some Band / Some Album (Deluxe Edition) / 2010` at
`Some Band\Deleted Folder` (missing); source `Some Band\2010 Some Album`
(flac) → `previously-lossy-target-missing`, `targetExists = false`, review
required.

### AS-LSY-021 — Ignored ledger entries are invisible to the name search
Status: Draft | Source: AS-DOC-LSY-028; cross-referenced with `AS-PRP-079`

The name search only scans `pending-upgrade` entries. An `ignored` entry
gives no previously-lossy warning at all.

Example: ledger `Some Band / Some Album (Deluxe Edition) / 2010` set to
`ignored`; source `Some Band\2010 Some Album` (flac) →
`lossyLossless.action = none`.

The same-release check behind the name search — a noisier old album name
(edition words, parenthetical groups) matching a cleaner new one — is
`AS-PRP-078`'s own rule; `AS-DOC-LSY-029` redirects straight there, with no
new item here.

## After apply

Apply's two ledger updates — marking a `replace-existing` release `upgraded`,
and writing a `log-for-upgrade` release's real committed path — are merged
in [10-apply.md](10-apply.md) as `AS-APL-061` and `AS-APL-062`.
`AS-DOC-LSY-030`/`031` restate those same two facts from this area's own
plan/README sources with no new content; rather than duplicate them here,
their citations have been folded into `AS-APL-061`/`062`'s own `Source:`
lines (see that file's changelog) and no new `AS-LSY` item is created.

## User actions on the ledger

### AS-LSY-022 — The user can list, ignore, mark upgraded, remove and export entries
Status: Draft | Source: AS-DOC-LSY-032

The user can list the ledger, filtered by status. The user can ignore an
entry, mark it upgraded by hand (for example after a replacement made
outside the tool), remove it, and export it to CSV or JSON, filtered by
status. The list of `pending-upgrade` entries is the upgrade backlog.
Command syntax: see [12-cli.md](12-cli.md) (`AS-CLI-026`–`029`).

Example: `lossy list -Status pending-upgrade` shows the backlog;
`lossy ignore a1b2c3d4e5f60708` → `status = ignored`.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-13 | Area LSY merged: 22 `AS-LSY-*` requirements (`AS-LSY-001`–`022`) reconciling 32 `AS-DOC-LSY-*` + 14 `AS-CODE-LSY-*`. No contradictions (neither source carried a `Contradiction`-type entry for this area). 1 new suspected defect found while merging and carried forward (`CF-LSY-001`: the dedicated ignore setter leaves a stale `upgradedUtc` on an entry ignored after being upgraded, unlike the generic status setter). Two doc items (`AS-DOC-LSY-023`, `029`) redirected with no new item to already-merged `AS-PRP-097`/`078`; two more (`AS-DOC-LSY-030`/`031`) redirected to already-merged `AS-APL-061`/`062`, whose `Source:` lines were extended to cite them. The propose-time half of this area (`AS-DOC-LSY-020`–`028`) cross-references the PRP merge's target-comparison items (`AS-PRP-078`–`081`, `092`, `097`) for the decision logic, owning only the ledger-field and `previousLossy`-schema detail PRP's own items don't state. |
| 0.2 | 2026-10-13 | During the CLI merge: the dangling `(not yet merged)` reference to `12-cli.md` resolved to a real link (`AS-CLI-026`–`029`). |
| 0.3 | 2026-10-14 | During the BND/ERR merge (the last area): found that the original 0.1 merge missed two pre-existing phase-1 `AS-DOC-DEF-*` entries filed under Area: LSY. `AS-DOC-DEF-097` (upgrade detection needing a ledger entry, per plan 09, vs the tests' target-content-only detection) is resolved via the already-merged `AS-PRP-092` — no change needed here. `AS-DOC-DEF-099` (propose logs a lossy release always, or only on `create-new`?) is resolved directly by this file's own `AS-LSY-015`, now updated to say so explicitly. `AS-DOC-DEF-098` (the unconditional, before-review ledger write can point at a target that's never created) is carried forward as `CF-LSY-002`. See `90-contradictions-resolution.md` and `91-suspected-defects-carryforward.md`. |
