# 05 — Providers: Discogs, Library

Status: Draft | Version: 0.4 | Last updated: 2026-11-03

## Today vs next-gen

| Topic | Today (legacy) | Next-gen |
|---|---|---|
| Providers | Discogs only. Bandcamp is planned but not implemented (`legacy/plan/13-bandcamp-fallback.md`). | Discogs (primary), Library. No Bandcamp (D69). |
| Candidates | Up to 5 kept in `discogsMatch.candidates`. The UI shows them only when the status is `ambiguous`. | Top 5 per provider, always visible, each with a link, a score and a reason |
| Changing the choice | A picked candidate **cannot be undone** or changed to another candidate | The selection is reversible at any time |
| Custom link | Not possible ("no way to paste a Discogs release URL", README) | Custom URL field |
| Without Discogs | Releases become `not-found` | No-provider mode works fully |

## Requirements

### NG-PRV-001 — Provider set
Priority: Must | Status: Draft | Source: D12, D32, D69

| Provider | Role | Priority |
|---|---|---|
| Discogs | Primary source of truth for names, tags and covers | Must |
| Library | Data of the release copy that is already in the library (NG-PRV-010) | Must |

Bandcamp is not a provider (D69: no official API, scraping is not viable). The design allows more providers later.

### NG-PRV-002 — No-provider mode
Priority: Must | Status: Draft | Source: D44 | Depends on: NG-VIS-004

The app works fully without any provider. That includes no token, no network, or nothing found. Propose then builds the Proposed layer from recognized data (folder and file names, structure, existing tags) and the naming templates.

### NG-PRV-003 — Show everything that was found
Priority: Must | Status: Draft | Source: RAW, D12

Propose keeps the **top 5 candidates per provider**. For each candidate the app stores and shows:
- the provider;
- a link to the provider page;
- title, year, format;
- the score;
- why it was chosen or not chosen.

Nothing is matched silently. The user sees every candidate on the review page.

### NG-PRV-004 — Reversible selection
Priority: Must | Status: Draft | Source: D12

The user can select any candidate at any time, and change the selection again later. Selecting a candidate never deletes the other candidates or their snapshots. A wrong click is always undone by selecting another candidate.

### NG-PRV-005 — Snapshots
Priority: Must | Status: Draft | Source: D12

Each fetched candidate's data is stored as a **snapshot**. Switching back to an earlier candidate uses its snapshot, with no new request. The Proposed layer is built from the snapshot of the selected candidate.

### NG-PRV-006 — Re-sync at any time
Priority: Must | Status: Draft | Source: RAW, D12

The user can always re-sync a release with its selected candidate. Re-sync fetches fresh data and replaces that candidate's snapshot. User overrides follow NG-LAY-008.

### NG-PRV-007 — Custom provider URL
Priority: Must | Status: Draft | Source: RAW, D12, D69

The review page has a field for a custom provider URL. Accepted URLs: a Discogs release URL and a Discogs master URL. The app fetches the page data, adds it as a candidate, and selects it.

### NG-PRV-008 — Search order
Priority: Must | Status: Draft | Source: RAW, D12, D69

- Propose searches Discogs first.
- When Discogs finds nothing, no other external provider is searched (D69). The release goes on in no-provider mode (NG-PRV-002).
- The user can run "search on <provider>" for any release at any time, even when Discogs found a match.

### NG-PRV-009 — Bandcamp needs research first
Priority: Could | Status: Withdrawn | Source: D12, D69

Withdrawn by D69: next-gen does not support Bandcamp at all. Kept for ID stability (doc rule 5). Original text:

Bandcamp has no public API. Reading its public pages is fragile, because the page format can change. Before Bandcamp is implemented, a research spike and an ADR must decide whether it is feasible and how to do it.

### NG-PRV-010 — Library as a provider
Priority: Must | Status: Draft | Source: D32, D19 | Depends on: NG-LIB-001

When a release already exists in the library (NG-LIB-004), the library copy is a candidate of the **Library** provider. Its snapshot holds the folder and file names, the tags and the cover of the library copy. The user selects it like any other candidate. Example use: keep the same names and tags as the existing library copy when you add a better-quality version.

### NG-PRV-011 — Provider IDs as optional tags
Priority: Should | Status: Draft | Source: D45

Apply can write the IDs of the selected candidate as extra tags, for example `DISCOGS_RELEASE_ID` and `DISCOGS_MASTER_ID`. This is controlled by a setting (default: on). The IDs are only helpful extra information. Release identity and library matching never depend on them (NG-LIB-002).

### NG-PRV-012 — Provider response cache
Priority: Must | Status: Draft | Source: D10

Provider responses are cached, as in legacy. A re-run of propose after re-recognize (NG-SES-005) is then fast.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Initial version (Docs part A). |
| 0.2 | 2026-10-04 | Phase 0 done: fixed the legacy plan link after the move to `legacy/`. |
| 0.3 | 2026-11-03 | D69 (no Bandcamp): Bandcamp removed from the title, the summary table, NG-PRV-001, NG-PRV-007 and NG-PRV-008. NG-PRV-009 Withdrawn. |
| 0.4 | 2026-11-03 | Consistency review (D70): NG-PRV-002 moves NG-VIS-004 from `Source:` to `Depends on:` (a requirement is not a source). |
