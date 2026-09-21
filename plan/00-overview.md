# Tagger — Implementation Plan Overview

This is the master index for the implementation plan. `MANIFESTO.md` (repo root) is
the source of truth for *what* the tool must do and *why*. This plan folder defines
*how* to build it.

Read this file first, then open each step's file in order. Each step file follows the
same shape: Purpose, Inputs/Outputs, Detailed Design, Decisions & Rationale, Edge
Cases, Manual Setup (if any), Definition of Done.

## Steps

| # | File | What it covers | Depends on | Status |
|---|------|-----------------|------------|--------|
| 1 | [01-repo-and-tooling-scaffolding.md](01-repo-and-tooling-scaffolding.md) | Repo layout, external tools, data directory, dev tooling | — | done |
| 2 | [02-discogs-account-and-api-access.md](02-discogs-account-and-api-access.md) | Discogs account, token, rate limits, caching | — | done |
| 3 | [03-domain-model-and-json-schemas.md](03-domain-model-and-json-schemas.md) | Shared JSON document shapes used by every module | 1 | done |
| 4 | [04-settings-module.md](04-settings-module.md) | Settings, first-run wizard, sessions | 1, 3 | done |
| 5 | [05-recognition-module.md](05-recognition-module.md) | Scan source, recognize releases, output `recognition.json` | 3, 4 | done |
| 6 | [06-edit-proposal-module.md](06-edit-proposal-module.md) | Discogs lookup, propose renames/tags, output `proposal.json` | 2, 3, 5 | done |
| 7 | [07-editing-ui-module.md](07-editing-ui-module.md) | Static-site review/approval UI for `proposal.json` | 3, 6 | in progress |
| 8 | [08-implementation-module.md](08-implementation-module.md) | Apply approved changes to real files | 3, 7, 9 | in progress |
| 9 | [09-lossy-lossless-tracking.md](09-lossy-lossless-tracking.md) | Lossy-release ledger, used by steps 6 and 8 | 3 | done |
| 10 | [10-error-handling-and-edge-cases.md](10-error-handling-and-edge-cases.md) | Re-runs, duplicates, path limits, invalid characters, ambiguous folders | 3, 5, 8 | in progress |
| 11 | [11-testing-and-verification-strategy.md](11-testing-and-verification-strategy.md) | Test fixtures, unit tests, verification approach per module | 1–10 | not started |
| 12 | [12-build-order-and-milestones.md](12-build-order-and-milestones.md) | Suggested order to actually build and test this incrementally | 1–11 | not started |

## Pipeline

```
source folder(s)
      |
      v
[04 settings] -- resolves source/target roots, templates, session id
      |
      v
[05 recognition] --------------------> recognition.json
      |                                (artists -> releases -> tracks,
      |                                 companion files, unrecognized[])
      v
[06 edit proposal] (queries Discogs) -> proposal.json
      |                                (before/after names+tags,
      |                                 cover candidates, lossy flags)
      v
[07 editing UI] (human review, File System Access API)
      |                                approved proposal.json
      v
[08 implementation] -------------------> target folders
      |                                  + lossy-tracking.json
      +--------------------------------> apply-log.json
```

## Tech stack

- **Scripting**: PowerShell 7 (`pwsh`), one module per concern under `scripts/`.
- **Tagging/cover art reading and writing**: TagLibSharp (.NET library, loaded in-process via `Add-Type`) — see [05](05-recognition-module.md) for why it was originally chosen for reading over mp3tag, and [08](08-implementation-module.md) for why writing moved to it too (zero manual setup, already a dependency, no external process).
- **Cover resize + single-file/cue splitting** (both lossless and lossy): ffmpeg (`-c copy`, no re-encoding). cuetools/shntool/mp3splt were considered but dropped — no reliable winget/Windows install path, and ffmpeg alone covers both cases.
- **Metadata source of truth**: Discogs API.
- **Editing UI**: plain HTML/JS static site, File System Access API, no framework, no build step, served by a tiny local static file server (needed only because the API requires a secure context — not an application backend).
- **Data documents**: JSON, validated with PowerShell's `Test-Json` against schemas in `schemas/`.
- **Data location**: all generated/user data lives outside the repo, under `%LOCALAPPDATA%\Tagger` (override via `TAGGER_HOME`).

## Glossary

- **Main Artist** — a band or performer; Level 1 folder in the target structure.
- **Release** — an album, EP, single, or maxi-single; Level 2 folder, format `yyyy The Album Name`.
- **Companion material** — non-track files in a release (cover scans, lyrics, photos).
- **stableKey** — a deterministic id for a release, derived from normalized `artist|album|year`. Same release always produces the same key, across runs and sessions — this is what makes re-runs and duplicate detection possible (see [10](10-error-handling-and-edge-cases.md)).
- **Session** — one run of the pipeline against one source root, tracked in `session.json` through stages: `recognized -> proposed -> reviewed -> applied`.
- **recognition.json / proposal.json** — the JSON documents produced by steps 5 and 6 (see [03](03-domain-model-and-json-schemas.md)).
- **Lossy / lossless** — compressed-with-loss (mp3, etc.) vs. exact (flac, alac, etc.) audio formats; tracked in [09](09-lossy-lossless-tracking.md).

## Cross-cutting decisions (see linked files for detail)

- **Re-runs are safe by design**: every release gets a `stableKey`; re-running Recognition/Proposal/Implementation against an unchanged source skips work instead of duplicating it. Detail in [10](10-error-handling-and-edge-cases.md).
- **Nothing ambiguous is auto-guessed**: grouping folders, band-member-as-artist folders, and low-confidence Discogs matches are always routed to human review, never silently resolved. Detail in [05](05-recognition-module.md) and [10](10-error-handling-and-edge-cases.md).
- **Sessions are resumable**: `session.json` always says which stage a source root is at, so work can stop and continue later. Detail in [04](04-settings-module.md) and [10](10-error-handling-and-edge-cases.md).
