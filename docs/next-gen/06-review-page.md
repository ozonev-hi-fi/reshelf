# 06 — Review page

Status: Draft | Version: 0.2 | Last updated: 2026-11-03

## Today vs next-gen

| Topic | Today (legacy) | Next-gen |
|---|---|---|
| Place | The whole UI is the review page | One screen of the full UI (NG-APP-003) |
| Review reasons | `recognize` writes codes. `propose` writes **free text** in `notes`. | Every reason is a code with a severity |
| Order | Grouped by artist | Configurable sort. Default: most suspicious first. |
| Filters | `Needs review only`, `Ambiguous match only` | By status and by reason code |
| Source view | A Before/After table of tracks | A tree view of the source folder |
| Pictures | One gallery: Discogs images, master image, embedded, local files, manual upload | Separate sections with size info |

## Requirements

### NG-REV-001 — Review is a separate screen
Priority: Must | Status: Draft | Source: RAW

The review page is one screen of the app. It shows the releases of one session.

### NG-REV-002 — Reason codes with severity
Priority: Must | Status: Draft | Source: D14

Every review reason, from recognize **and** from propose, is a code from the reference data (NG-CFG-009). Each code has a severity:

| Severity | Effect |
|---|---|
| Blocking | The release cannot be approved until the reason is resolved |
| Warning | The release gets `Needs review` and needs attention |
| Info | Shown for information only |

The legacy free-text notes of `propose` become codes. Examples: track count differs from the provider, year unresolved, no cover candidates.

### NG-REV-003 — Default sort
Priority: Must | Status: Draft | Source: RAW, D14

By default, releases are sorted by status, most suspicious first, in the order of NG-SES-011 (`Error` first, `Applied` last). Then by artist, then by year.

### NG-REV-004 — Other sorts
Priority: Must | Status: Draft | Source: RAW, D14

The user can sort by artist, year, status, source path, or number of warnings.

### NG-REV-005 — Filters
Priority: Must | Status: Draft | Source: D14

The user can filter by status and by reason code.

D14 says this sort and filter set is enough for the first iteration.

### NG-REV-006 — Provider candidates on the page
Priority: Must | Status: Draft | Source: RAW, D12

For every release, the page shows all provider candidates with their links. It also shows the selection, the custom URL field, re-sync, and "search on <provider>". The rules are in [05-providers.md](05-providers.md) (NG-PRV-003 to NG-PRV-008).

### NG-REV-007 — Source tree per release
Priority: Must | Status: Draft | Source: RAW, D17 | Depends on: NG-LAY-005

The page shows the release's source folder as a tree, so the user understands the "before" structure without opening a file explorer. Each file is marked as one of:
- track;
- companion (cover, booklet, lyrics, ...);
- cue sheet, with its virtual tracks below it;
- ignored, with the reason.

### NG-REV-008 — Source tree per session
Priority: Must | Status: Draft | Source: D17

The session has a tree view of the whole source folder. It shows recognized releases and **unrecognized** folders, each with its reason code.

### NG-REV-009 — Mark an unrecognized folder as a release
Priority: Should | Status: Draft | Source: D17

From the session tree, the user can mark an unrecognized folder as a release and give its artist. Today the only fix is to rename folders on disk and run recognize again.

### NG-REV-010 — Picture sections
Priority: Must | Status: Draft | Source: RAW, D13

The cover chooser shows separate sections:
1. **Embedded**: the picture already in the audio file tags.
2. **In folder**: image files in the source release folder.
3. **Provider**: one group per provider for the selected candidate. Pictures of the other candidates sit in a collapsed group.
4. **Manual upload**: pictures the user uploads.

### NG-REV-011 — Picture details and size warning
Priority: Must | Status: Draft | Source: D13

Each picture shows its size in pixels and in bytes. A picture whose longest side is smaller than the cover max dimension (NG-CFG-002) gets a warning.

### NG-REV-012 — Cover choice
Priority: Must | Status: Draft | Source: D13

The user chooses one picture as the cover. An in-folder image can be the cover and also stay a companion file.

### NG-REV-013 — Library match on the page
Priority: Must | Status: Draft | Source: D30 | Depends on: NG-LIB-009

When a release matches a library release, the page shows the match status and an action selector (Skip, Overwrite, Keep both), with the default from NG-LIB-009.

## Open points

- Default sort (NG-REV-003): the raw note says "more 'suspicious' releases first, 'ready' latest". NG-REV-003 follows NG-SES-011, where `Ready` comes before `Approved`, `Rejected` and `Applied`. No decision records this change. Which order is right? → Phase 4, area REV (review UI).

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Initial version (Docs part A). |
| 0.2 | 2026-11-03 | Consistency review: new open point on the default sort ("ready" latest in the raw note vs NG-SES-011 order) → phase 4, area REV. |
