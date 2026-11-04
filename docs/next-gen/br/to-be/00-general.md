# 00 — General (to-be)

Status: Draft | Version: 0.2 | Last updated: 2026-11-04

## Scope

Goals and principles of the new app that apply to every area. Built from the merged as-is file
[../as-is-merged/00-general.md](../as-is-merged/00-general.md) (AS-GEN-001–010) and the NG
requirements this area owns (NG-VIS-001–004, NG-APP-001, NG-APP-006; see the
[NG → to-be file map](README.md#ng--to-be-file-map)). Format: [README.md](README.md#requirement-format).

The details each rule points to live in their own area files. v1 non-goals: see
[01-vision-scope.md](../../01-vision-scope.md#non-goals-v1). Terms: see the shared
[glossary](../../01-vision-scope.md#glossary).

## Requirements

### TB-GEN-001 — The release is the unit of work
Priority: Must | Status: Draft | Source: AS-GEN-001 (the release is the unit of work)

The app shall organize music one release at a time. It uses two concepts: the **main artist**
(band or performer) and the **release** (album, EP, single, maxi-single).

Example: `Kyuss\1994 Welcome to Sky Valley` is one release of the main artist `Kyuss`.

### TB-GEN-002 — Organizing runs again and again on different sources
Priority: Must | Status: Draft | Source: AS-GEN-002 (the app runs again and again on different sources), D78 (phones over USB: copy to a disk first)

The app shall let the user organize again and again, each time on another source folder: the
existing collection first, then `Downloads` folders, USB flash drives, memory cards. Organizing is
an ongoing process, not a one-time job. A phone connected by USB is not a direct source in v1
(NG-PTH-014).

Example: session 1 on `E:\Music\Unsorted`, session 2 on `C:\Users\me\Downloads`, session 3 on a USB
stick `F:\`.

### TB-GEN-003 — Four stages, results stored in the app's database
Priority: Must | Status: Draft | Source: AS-GEN-003 (four stages, each with its own JSON document), NG-VIS-001 (.NET application replaces the PowerShell scripts), D72 (Propose runs automatically after Recognize, or is skipped)

The app shall run the pipeline in four stages, **Recognize → Propose → Review → Apply**, and store
the results of each stage in its database, not in JSON files. The next stage reads them from there.

- Propose runs automatically after Recognize, or by hand when that setting is off (NG-SES-015).
- Propose can be skipped: the user may approve and apply straight from the recognized values
  (NG-SES-016).

Stage details: recognition, proposal, review and apply area files. The CLI command set: the
command-line area file.

Example: the user starts a session on `D:\Downloads\Kyuss`. Recognize finishes, Propose starts by
itself, the user reviews and approves `1994 Welcome to Sky Valley`, and Apply writes it to temp.

### TB-GEN-004 — Providers suggest, the user decides, the app works without providers
Priority: Must | Status: Draft | Source: AS-GEN-004 (Discogs is the source of truth for metadata), NG-VIS-004 (core principles: works without providers), D71 (providers can be turned off), D75 (provider-neutral candidate panel)

The app shall treat provider data as **suggestions**: every candidate is visible, and the user can
select another one or edit any value. Names, tags and cover art can come from **providers**:
Discogs (primary) and the Library (the copy already in the library) — see NG-PRV-001.

If no provider can be used (no token, no network, a provider that is down, or providers turned off
by the user), then the app shall work on the recognized data alone (NG-PRV-002).

Example: Discogs is turned off for the session. Source folder
`Kyuss - 1994 - Welcome To Sky Valley [FLAC]` → proposed `Kyuss\1994 Welcome to Sky Valley`, from
the folder name and the existing tags.

### TB-GEN-005 — Default target layout, changeable by levels
Priority: Must | Status: Draft | Source: AS-GEN-005 (target layout is Artist / yyyy Album / NN Track), D76 (path template as a list of levels)

The app shall build the output path below the target root from a path template made of levels
(NG-CFG-003). Only the target root folder is fixed. The default is the legacy layout: one folder per main artist, one folder per
release named `yyyy Album`, tracks named `NN Track Name.ext`. The user can change the names and
add, remove or reorder levels.

Example:
```
Default:     <target>\Kyuss\1994 Welcome to Sky Valley\01 Gardenia.flac
User layout: <target>\Kyuss\1994 - Welcome to Sky Valley\CD1\Track_01.flac
```

### TB-GEN-006 — Tag rules are on by default
Priority: Must | Status: Draft | Source: AS-GEN-006 (metadata rules that the app enforces), D80 (tag rules fixed in v1, configurable later)

The app shall apply these tag rules to every release. In v1 they are built in and always on
(NG-CFG-006). A later
version may let the user change them (NG-CFG-015). The rules themselves live in the naming area.

| Rule (shortened) | Example |
|---|---|
| Artist = Album Artist (except compilations) | both `Kyuss` |
| Disc is always set; Track restarts on each disc | single CD → `Disc = 1`; CD2 starts at `Track = 1` |
| Featured artists only in the title | Title `Song (feat. Artist B)`, Artist stays `Artist A` |
| Year and Album are required | an empty Year blocks apply |

The legacy rule "Year and Album tags match the release folder name" depends on the user's path
template now; the naming area decides it. The embedded-cover size is a setting, not a tag rule
(NG-CFG-002, default 600 px).

### TB-GEN-007 — Nothing unclear is decided silently
Priority: Must | Status: Draft | Source: AS-GEN-007 (nothing ambiguous is guessed automatically), NG-VIS-004 (core principles: no silent matching), D75 (candidates always visible)

If a folder or a match is unclear (a grouping folder, a band-member folder, a low-confidence
provider match), then the app shall send it to the user's review and never resolve it silently.
Every candidate a provider found stays visible (NG-PRV-003).

Example: a folder `Band A and its members' projects` with subfolders `Band A` and `Band B` is not
turned into an artist called "Band A and its members' projects"; it is shown for review.

### TB-GEN-008 — A re-run never creates a duplicate; the user chooses the action
Priority: Must | Status: Draft | Source: AS-GEN-008 (re-runs are safe because of the stable key), D74 (a re-run marks later layers outdated, never deletes them)

When the user runs the app again on a source, the app shall not create a second copy of a release
by itself. Two steps are separate:
1. **Identity**: is this the same release as one already in the library? (release key, NG-LIB-002)
2. **Action**: skip, overwrite or keep both. The app suggests a default from the quality
   comparison (NG-LIB-009); the user always makes the choice.

Example: the library has `Kyuss\1994 Welcome to Sky Valley` as MP3 320; the source has the same
album as FLAC 16/44.1. The match status is "higher quality", default action Overwrite. The user can
pick Skip or Keep both instead.

How editions of one album are identified (a same-year reissue, a later remaster) is an open point
of the data-and-storage area (see [README open points](README.md#open-points)).

### TB-GEN-009 — A session can be stopped and continued
Priority: Must | Status: Draft | Source: AS-GEN-009 (sessions can be resumed), D74 (a re-run marks later layers outdated, never deletes them)

The app shall store the stage, the data and the user's edits of each session in its database, so
the user can stop at any point and continue later. A session is one pipeline run on one source
folder. Nothing is lost when a stage is re-run (NG-SES-005, NG-SES-008). Details: the sessions area file.

Example: the user runs Propose, closes the app, opens it the next day, and continues with Review
of the same session.

### TB-GEN-010 — CLI and a full UI over one shared core
Priority: Must | Status: Draft | Source: NG-VIS-002 (CLI and full UI), NG-APP-001 (one core, two front-ends)

The app shall offer a CLI for power users and batch work, and a full UI that does everything
without the CLI. Both front-ends call the same application core: the same operation with the same
input gives the same result from either front-end.

Example: running Propose for one session from the CLI or by pressing Next in the UI wizard gives
the same proposed names.

### TB-GEN-011 — Core principles
Priority: Must | Status: Draft | Source: NG-VIS-004 (core principles)

The app shall follow these principles in every area:

| Principle | Meaning |
|---|---|
| Source is read-only | The app never changes or deletes a source file. |
| Library is read-only | In the target role, the app never writes, moves or deletes anything. Apply writes only to temp; the user moves the results (NG-PTH-004). |
| The user's version wins | User edits come before proposed and recognized values (NG-LAY-002). |
| No retroactive changes | A settings change never touches releases already applied (NG-CFG-007). |

The other two principles of NG-VIS-004 are TB-GEN-004 (works without providers) and TB-GEN-007
(no silent matching).

Example: the user changes the path template after applying 20 releases. The 20 applied releases
keep their old names; only releases not yet applied use the new template.

### TB-GEN-012 — Local, single user
Priority: Must | Status: Draft | Source: NG-APP-006 (local, single user)

The app shall serve one user on one machine. The UI shall listen on localhost only and shall not
ask for a login.

Example: the UI is reachable at `http://localhost:<port>` on the user's PC, not from another PC
in the same network.

## Suspected defects decided

| Suspected defect | Disposition | Decision |
|---|---|---|
| CF-GEN-001 — links from the review UI to provider pages (a legacy plan idea, never built) | **Fix**: next-gen shows every candidate with its link, in a provider-neutral panel that is always visible, with two-step selection and re-sync (NG-PRV-001–004) | D75 |

## Dropped

- AS-GEN-010 (legacy tool set: PowerShell, TagLibSharp, ffmpeg, plain HTML/JS, `Test-Json`,
  `.data/`) — tools are chosen in phase 5 ADRs, starting from what worked in legacy (D83).

## Process only

- NG-VIS-003 (legacy code is the reference, not the truth) — a rule for building the app, applied
  by phase 4 itself (D84).

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-11-04 | Phase 4, Part 1, area GEN: TB-GEN-001–012 from AS-GEN-001–009 and NG-VIS-001, 002, 004, NG-APP-001, 006. CF-GEN-001 decided (D75). AS-GEN-010 dropped (D83). NG-VIS-003 process only (D84). |
| 0.2 | 2026-11-04 | D85: the first sentence of TB-GEN-001–012 rewritten in an EARS pattern. Meaning, sources and examples unchanged. |
