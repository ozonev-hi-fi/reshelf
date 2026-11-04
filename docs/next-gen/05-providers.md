# 05 — Providers: Discogs, Library

Status: Draft | Version: 0.5 | Last updated: 2026-11-04

## Today vs next-gen

| Topic | Today (legacy) | Next-gen |
|---|---|---|
| Providers | Discogs only. | Discogs (primary), Library. |
| Candidates | Up to 5 kept in `discogsMatch.candidates`. The UI shows them only when the status is `ambiguous`. | Top 5 per provider, always visible, each with a link, a score and a reason |
| Changing the choice | A picked candidate **cannot be undone** or changed to another candidate | The selection is reversible at any time |
| Custom link | Not possible ("no way to paste a Discogs release URL", README) | Custom URL field |
| Without Discogs | Releases become `not-found` | No-provider mode works fully |

## Requirements

### NG-PRV-001 — Provider set
Priority: Must | Status: Draft | Source: D12, D32, D69, D75

| Provider | Role | Priority |
|---|---|---|
| Discogs | Primary source of truth for names, tags and covers | Must |
| Library | Data of the release copy that is already in the library (NG-PRV-010) | Must |

The candidate list, selection, re-sync, reset and the review page work the same way for every provider. A new provider (for example MusicBrainz) adds one more group of candidates and needs no change in them.

### NG-PRV-002 — No-provider mode
Priority: Must | Status: Draft | Source: D44, D71 | Depends on: NG-VIS-004

The app works fully without any provider. That includes no token, no network, a provider that is down (answers with errors), a provider turned off by the user, or nothing found. Propose then builds the Proposed layer from recognized data (folder and file names, structure, existing tags) and the naming templates.

- **Turn off:** each provider has a global on/off setting (default on). A session can change it for itself, e.g. "no Discogs for this session".
- **No network or provider down:** the release goes on in no-provider mode and gets a warning, e.g. "Discogs not reachable". The user can re-sync later (NG-PRV-006).
- **Turned off on purpose:** the candidate panel shows an info message, not a warning, e.g. "Providers are off for this session", with a "Turn on and search" action (D75).

Example: source folder `Kyuss - 1994 - Welcome To Sky Valley [FLAC]` with `01 - Gardenia.flac` (tag Title = "Gardenia"), Discogs off. Proposed: `Kyuss\1994 Welcome to Sky Valley\01 Gardenia.flac`, Artist = Kyuss, Year = 1994.

### NG-PRV-003 — Show everything that was found
Priority: Must | Status: Draft | Source: RAW, D12

Propose keeps the **top 5 candidates per provider**. For each candidate the app stores and shows:
- the provider;
- a link to the provider page;
- title, year, format;
- the score;
- why it was chosen or not chosen.

Nothing is matched silently. The user sees every candidate on the review page, always, not only when the match is unclear (D75). The candidates are grouped by provider, with the same columns in every group.

Example:
```
Discogs                                     [Search on Discogs] [Custom URL]
● Welcome to Sky Valley (1994, CD)      0.92  ↗ link  "title+year+12 tracks"  [Re-sync]
○ Welcome to Sky Valley (2004, CD, RE)  0.81  ↗ link  "year differs"
Library
○ Kyuss\1994 Welcome to Sky Valley (MP3 320)  ↗ open  "same release key"
```

### NG-PRV-004 — Reversible selection
Priority: Must | Status: Draft | Source: D12, D75

The user can select any candidate at any time, and change the selection again later. There is one selection across all provider groups. Selecting a candidate never deletes the other candidates or their snapshots.

Selecting takes two steps, so a wrong click changes nothing: a click marks the candidate as picked (◉) and shows "Use this one"; only that button makes it the selection (●) and rebuilds the Proposed layer from it.

Example:
```
● Welcome to Sky Valley (1994, CD)      0.92  ↗ link  [Re-sync]
◉ Welcome to Sky Valley (2004, CD, RE)  0.81  ↗ link  [Use this one]
```

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

### NG-PRV-009 — Withdrawn
Status: Withdrawn | Source: D69

Kept only so the ID is never reused (doc rule 5).

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
| 0.5 | 2026-11-04 | Bandcamp cleanup: the word is removed from the live text. NG-PRV-009 is now a one-line Withdrawn stub. D69 in the decision log is the only live mention. NG-PRV-002 (no-provider mode): D71 adds "provider down" and "turned off by the user" (global setting + per session), with an example. D75 (suspected defect CF-GEN-001, provider page links): NG-PRV-001 provider-neutral panel, NG-PRV-002 info message when turned off on purpose, NG-PRV-003 candidates always visible with an example, NG-PRV-004 two-step selection ("Use this one"). |
