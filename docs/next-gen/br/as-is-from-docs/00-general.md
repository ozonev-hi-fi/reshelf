# 00 — General (as-is, from docs and tests)

Status: Draft | Version: 0.1 | Last updated: 2026-10-05

## Scope

Cross-cutting behavior of the legacy app as its documents describe it. Owned inputs: `MANIFESTO.md` §1–3, `legacy/plan/00-overview.md`, and the title section of `legacy/README.md` (everything above "Pipeline"). The details of each rule live in the area files. This file names the rule and links to them.

## Problem the app solves

The source collection has no reliable structure (MANIFESTO §1). The docs name these patterns:

| Pattern | Example from the docs | Handled in |
|---|---|---|
| Track files without a number or without the `-` separator | `Alpha Song.flac` | [05-recognition.md](05-recognition.md) |
| Grouping folder instead of an artist folder | `Godspeeds and their projects/` | [05-recognition.md](05-recognition.md) |
| Category folders under an artist | `EPs/`, `Singles/`, `Lives/` | [05-recognition.md](05-recognition.md) |
| Band-member folders inside a band folder | `Talking Heads/David Byrne/` | [05-recognition.md](05-recognition.md) |
| Missing or wrong tags | — | [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md) |

## Core rules

### AS-DOC-GEN-001 — The release is the unit of work
Status: Draft | Source: MANIFESTO.md › 2. Core Idea; legacy/README.md › (title section)

The app organizes music around two concepts: the **Main Artist** (band or performer) and the **Release** (album, EP, single, maxi-single). It works one release at a time.

Example: `ZZ Top/1999 XXX/` is one release of the main artist `ZZ Top`.

### AS-DOC-GEN-002 — The app runs again and again on different sources
Status: Draft | Source: MANIFESTO.md › 3. Goal

Organizing is an ongoing process, not a one-time job. The user runs the app many times. Each run points at a different source folder: the existing collection first, then phone storage, `Downloads` folders, USB flash drives.

Example (pseudo CLI from the manifesto): `/run` organizes the default source; `/run c:\downloads\folder` organizes the given folder.

### AS-DOC-GEN-003 — Four stages, each with its own document
Status: Draft | Source: legacy/plan/00-overview.md › Pipeline; legacy/README.md › (title section)

The pipeline has four stages. Each stage writes a JSON document that the next stage reads.

| Stage | CLI command | Output |
|---|---|---|
| Recognize | `recognize` | `recognition.json` (artists → releases → tracks, companion files, `unrecognized[]`) |
| Propose | `propose` | `proposal.json` (before/after names and tags, cover candidates, lossy flags) |
| Review | `ui start` | the same `proposal.json`, edited and approved by the user |
| Apply | `apply` | target folders, `apply-log.json`, `lossy-tracking.json` |

All commands run from the repo root as `pwsh scripts/Reshelf.ps1 <command> ...` (the path before the Phase 0 move). Stage details: [05-recognition.md](05-recognition.md), [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md), [09-review-ui.md](09-review-ui.md), [10-apply.md](10-apply.md). The command surface: [12-cli.md](12-cli.md).

### AS-DOC-GEN-004 — Discogs is the source of truth for metadata
Status: Draft | Source: legacy/README.md › (title section); legacy/plan/00-overview.md › Tech stack

The app takes names, tags and cover art from Discogs. Matching rules: [07-proposal-matching.md](07-proposal-matching.md). Bandcamp as a fallback: [13-bandcamp-and-errors.md](13-bandcamp-and-errors.md).

### AS-DOC-GEN-005 — Target layout is Artist / yyyy Album / NN Track
Status: Draft | Source: legacy/README.md › (title section)

The target root holds one folder per main artist. Each artist folder holds one folder per release, named `yyyy Album`. Each release folder holds the tracks, named `NN Track Name.ext`.

Example:
```
<targetRoot>\
  <Artist>\
    <yyyy Album>\
      01 Track Name.flac
      02 Track Name.flac
```

The full naming rules: [02-text-and-naming-rules.md](02-text-and-naming-rules.md) and [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

### AS-DOC-GEN-006 — Metadata rules that the app enforces
Status: Draft | Source: legacy/README.md › (title section)

The README lists six tag rules. Each rule is a requirement in an area file. This list only names them.

| Rule (README wording, shortened) | Area |
|---|---|
| `Artist` = `Album Artist` = the artist folder name by default; on a compilation each track can have its own `Artist` | [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md) |
| `Disc` is always set, even for one disc. `Track` restarts at 1 on each disc | [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md) |
| Featured artists go only into the track title, never into `Artist` / `Album Artist` | [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md) |
| The embedded cover is at most 600 px on the longest side | [10-apply.md](10-apply.md) |
| `Year` and `Album` tags always match the release folder name `yyyy Album` | [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md) |

### AS-DOC-GEN-007 — Nothing ambiguous is guessed automatically
Status: Draft | Source: legacy/plan/00-overview.md › Cross-cutting decisions

Grouping folders, band-member folders and low-confidence Discogs matches always go to human review. The app never resolves them silently.

Example: `Godspeeds and their projects/` is not turned into an artist without review. Details: [05-recognition.md](05-recognition.md), [07-proposal-matching.md](07-proposal-matching.md).

### AS-DOC-GEN-008 — Re-runs are safe because of the stable key
Status: Draft | Source: legacy/plan/00-overview.md › Cross-cutting decisions; legacy/plan/00-overview.md › Glossary

Every release gets a `stableKey`. It is built from the normalized `artist|album|year`, so the same release gets the same key in every run and every session. A re-run on an unchanged source skips the work instead of making a duplicate. Key rules: [01-data-home-and-storage.md](01-data-home-and-storage.md). Duplicate and upgrade states: [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md). Skip on apply: [10-apply.md](10-apply.md).

### AS-DOC-GEN-009 — Sessions can be resumed
Status: Draft | Source: legacy/plan/00-overview.md › Cross-cutting decisions; legacy/plan/00-overview.md › Glossary

A session is one run of the pipeline on one source root. `session.json` stores its stage (`recognized → proposed → reviewed → applied`). The user can stop and continue later. Details: [04-sessions.md](04-sessions.md).

### AS-DOC-GEN-010 — Tool set
Status: Draft | Source: legacy/plan/00-overview.md › Tech stack

| Job | Tool |
|---|---|
| Scripts | PowerShell 7 (`pwsh`), one module per concern |
| Read and write tags and embedded covers | TagLibSharp, loaded in-process (mp3tag was planned and dropped) |
| Resize covers, split one-file + cue releases | ffmpeg. Plan 00 says `-c copy` (no re-encoding), but the tests show that FLAC and APE sources are re-encoded to FLAC (AS-DOC-APL-029 in [10-apply.md](10-apply.md), contradiction AS-DOC-DEF-083 in [90-suspected-defects.md](90-suspected-defects.md)). cuetools, shntool and mp3splt were dropped |
| Review UI | plain HTML/JS, no framework, no build step, served by a localhost server (`ui start`). The File System Access API design was dropped |
| JSON validation | `Test-Json` against `schemas/` |
| Data location | git-ignored `.data/` in the repo, `RESHELF_HOME` overrides it (see [01-data-home-and-storage.md](01-data-home-and-storage.md)) |

## Glossary (from `legacy/plan/00-overview.md`)

| Term | Meaning |
|---|---|
| Main Artist | A band or performer. Level 1 folder in the target. |
| Release | An album, EP, single or maxi-single. Level 2 folder, `yyyy The Album Name`. |
| Companion material | Non-track files of a release: cover scans, lyrics, photos. |
| stableKey | Deterministic release ID from normalized `artist\|album\|year`. |
| Session | One pipeline run on one source root, tracked in `session.json`. |
| Lossy / lossless | Compressed with loss (mp3, …) / exact (flac, alac, …). |

## Not behavior: ideas and status notes in the sources

- `legacy/plan/00-overview.md` › Rough ideas: the review UI could link to the Discogs release page (exact pressing) or the master release, and similar for Bandcamp. The docs do not say that this exists. See AS-DOC-DEF-001 in [90-suspected-defects.md](90-suspected-defects.md).
- `legacy/plan/00-overview.md` › Steps: step 12 (build order) is "in progress" and step 13 (Bandcamp fallback) is "research needed".

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-05 | Phase 1 draft. |
