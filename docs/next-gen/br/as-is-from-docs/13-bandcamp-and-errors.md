# 13 — Bandcamp fallback and error handling (as-is, from docs and tests)

Status: Draft | Version: 0.1 | Last updated: 2026-10-05

## Scope

Two areas in one file:

- **BND** — the Bandcamp fallback. Owned input: `legacy/plan/13-bandcamp-fallback.md`. No test and no README section mentions Bandcamp, so the feature is not built.
- **ERR** — error handling and edge cases that are not specific to one stage, and the tooling rules. Owned inputs: `legacy/plan/10-error-handling-and-edge-cases.md`, `legacy/plan/08-implementation-module.md` › Edge cases, `legacy/README.md` › "Troubleshooting / known limitations", `MANIFESTO.md` §8 (Tooling Philosophy) and §9 (Open Questions).

Apply-specific failure rules (failed release, staging left for inspection, retry, path truncation) are in [10-apply.md](10-apply.md). This file links to them by ID.

## Bandcamp fallback (BND)

### AS-DOC-BND-001 — Discogs is the only external metadata source; there is no Bandcamp lookup
Status: Draft | Source: legacy/plan/13-bandcamp-fallback.md › Status: research needed, not started; legacy/plan/13-bandcamp-fallback.md › Purpose / scope; legacy/tests/Reshelf.Pipeline.Tests.ps1 › Full pipeline: Recognition -> EditProposal -> Implementation › flags every release for human review since Discogs never matches, and apply skips all of them by default

The app looks up releases only on Discogs. When Discogs has no match, the release stays `not-found`. The app tries no other source. It needs human review, and apply skips it by default (AS-DOC-APL-003).

Example (plan 13): `Straplocked & Ray Gun Hero - Stalemate` is not on Discogs but is on `https://burningowlrecords.bandcamp.com/album/stalemate` → the app gives `not-found`.

Example (test): Discogs returns zero results for the whole fixture tree → every release needs review; with no other source, apply gives `Applied 0`.

### AS-DOC-BND-002 — A Bandcamp hit is not always useful data (plan only)
Status: Draft | Source: legacy/plan/13-bandcamp-fallback.md › Purpose / scope; legacy/plan/13-bandcamp-fallback.md › Research questions (7. Data quality)

The plan records that a release found on Bandcamp does not always have data good enough for names and tags. Some pages only confirm that the release exists (plan only — a finding from a manual review, not app behavior).

Example: `Wuneny - whatever singularity` on `https://moonleedistribution.bandcamp.com/album/vuneny-whatever-singularity` → the page metadata is too sparse and inconsistent to help.

## Recovery after a failed apply (ERR)

### AS-DOC-ERR-001 — A failed release is fixed by the user and retried with a new apply
Status: Draft | Source: legacy/README.md › Troubleshooting / known limitations; legacy/plan/08-implementation-module.md › Edge cases; legacy/plan/10-error-handling-and-edge-cases.md › Session persistence and resume

When a release fails, the user reads its `errorMessage` in `apply-log.json` and looks at `<targetRoot>\.reshelf-staging\<stableKey>\` to see what was staged. The user fixes the problem and runs `apply` again. Apply retries failed releases by itself and only touches releases that are missing from the log or `failed`. Details: AS-DOC-APL-013, AS-DOC-APL-020, AS-DOC-APL-045.

Example: tag write failed for `bbbbbbbbbbbbbbbb` → `apply-log.json` has `errorMessage` `tag write boom`; `<targetRoot>\.reshelf-staging\bbbbbbbbbbbbbbbb\` holds the staged files; the next `apply -SessionId <id>` processes it again.

### AS-DOC-ERR-002 — A failure before the final move never touches the final path
Status: Draft | Source: legacy/plan/08-implementation-module.md › Edge cases; legacy/plan/08-implementation-module.md › Why staging-then-commit

When a release fails during copy, split, cover or tag steps, nothing is at the final target path yet. This includes a full disk in the middle of a copy: the partial staged folder stays for cleanup or retry (plan only for the full-disk case — no test shows it). The tested cases are in AS-DOC-APL-017 and AS-DOC-APL-045.

Example (illustration): disk full while copying release `a1b2c3d4e5f60708` → `<targetRoot>\.reshelf-staging\a1b2c3d4e5f60708\` is partial; `<targetRoot>\Some Band\2010 Some Album\` is not created.

## Windows path length (ERR)

### AS-DOC-ERR-003 — File operations use the long-path prefix (plan only)
Status: Draft | Source: legacy/plan/10-error-handling-and-edge-cases.md › Windows path length

The app uses the `\\?\` long-path prefix when it calls .NET or PowerShell file functions. This lifts the normal limit of about 260 characters (plan only — no test shows it). The names stay short anyway, because apply shortens any path over 250 characters (AS-DOC-APL-056 to AS-DOC-APL-060).

Example (illustration): `\\?\D:\Music\<artist>\<release>\01 <title>.flac`.

## Re-runs and duplicates (ERR)

The re-run table of plan 10 (`create-new`, `skip-existing-identical`, `update-existing`, `conflict`): see [07-proposal-matching.md](07-proposal-matching.md). The skip on apply: AS-DOC-APL-011.

### AS-DOC-ERR-004 — Safety wins over a silent overwrite
Status: Draft | Source: legacy/plan/10-error-handling-and-edge-cases.md › Re-runs and duplicate detection; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › skips a targetAction conflict release with humanReview.resolved = false, leaving the existing target untouched, unless -IncludeUnresolved

The app never replaces an existing target release silently. Only a clean new release or a clean lossy-to-lossless upgrade goes through without review. Everything else needs a human decision first.

Example: an existing target `Some Band\2010 Some Album\01 Track.flac` with different content → `conflict`, review required; apply skips it and the file keeps `pre-existing-different-content`.

### AS-DOC-ERR-005 — The same release twice in one session is compared with the first one (plan only)
Status: Draft | Source: legacy/plan/10-error-handling-and-edge-cases.md › Re-runs and duplicate detection

When the same release comes twice from two different sources in one session, the second one is compared with the proposed result of the first one, like any other existing target (plan only — not in README or in the owned tests). It then becomes `skip-existing-identical`, `update-existing` or `conflict` by the normal rules.

Example (illustration): the same mp3 album in `Downloads\` and on a flash drive in one session → the second copy is checked against the first copy's proposed target.

### AS-DOC-ERR-006 — An identical existing release causes no Discogs query (plan only)
Status: Draft | Source: legacy/plan/10-error-handling-and-edge-cases.md › Re-runs and duplicate detection

When the release is in the target and the source file-set hash matches (`skip-existing-identical`), the app does no work for it and does not query Discogs again (plan only).

Example (illustration): an unchanged re-run of `recognize` → `propose` on the same source → no new Discogs requests for already-applied releases.

## Ambiguous folders (ERR)

### AS-DOC-ERR-007 — Unclear folders are never guessed; the user fixes them on disk
Status: Draft | Source: legacy/README.md › Reference: automatic folder recognition; legacy/plan/10-error-handling-and-edge-cases.md › Ambiguous/unrecognizable folders; MANIFESTO.md › 8. Tooling Philosophy

A folder that the recognition rules cannot classify goes to `unrecognized[]`. The app does not guess. There is no override file: the user moves or renames the folder on disk so it matches a known pattern, and runs `recognize` again. Plan 10 still describes an editable `overrides.json` for this step, which the README contradicts (AS-DOC-DEF-019 in [90-suspected-defects.md](90-suspected-defects.md)). The recognition rules: see [05-recognition.md](05-recognition.md).

Example (illustration): a folder listed in `unrecognized[]` with reason `release-without-artist-suspected` → the user moves it under an artist folder and runs `recognize` again.

## Invalid file name characters (ERR)

The safe-name rules (`< > : " / \ | ? *`, trailing dots and spaces, reserved names such as `CON.flac`): see [02-text-and-naming-rules.md](02-text-and-naming-rules.md). How the review UI shows the changes: see [09-review-ui.md](09-review-ui.md). The tag text keeps the raw characters: AS-DOC-APL-023.

## Known limitations from the README (ERR)

### AS-DOC-ERR-008 — UI port in use: the user picks another port
Status: Draft | Source: legacy/README.md › Troubleshooting / known limitations

When the review UI cannot start because its port is in use, the user starts it with another port. The UI itself: see [09-review-ui.md](09-review-ui.md).

Example (illustration): `pwsh scripts/Reshelf.ps1 ui start -Port 8081`.

### AS-DOC-ERR-009 — Discogs 401 means a missing or invalid token
Status: Draft | Source: legacy/README.md › Troubleshooting / known limitations

When Discogs answers `401 Unauthorized`, the token is missing or invalid. The user sets the token again. Token storage: see [03-settings-and-secrets.md](03-settings-and-secrets.md).

Example (illustration): `propose` gets `401 Unauthorized` → the user runs `pwsh scripts/Reshelf.ps1 settings set-token`.

### AS-DOC-ERR-010 — The UI cannot force a match from a Discogs URL or ID
Status: Draft | Source: legacy/README.md › Troubleshooting / known limitations

The review UI has no field to paste a Discogs release URL or release ID to force a match. The user can only choose among the candidates that propose found.

Example (illustration): the right release is `https://www.discogs.com/release/<id>` but propose did not list it → the UI gives no way to enter it.

### AS-DOC-ERR-011 — The last Save wins between browser tabs
Status: Draft | Source: legacy/README.md › Troubleshooting / known limitations

The review UI does not detect conflicts between two browser tabs or two sessions on the same proposal. The last Save overwrites the earlier one.

Example (illustration): tab A saves a new title, then tab B (opened before) saves → the title from tab A is lost.

## Tooling (ERR)

### AS-DOC-ERR-012 — Apply uses ffmpeg as an external program and TagLibSharp as an in-process library
Status: Draft | Source: MANIFESTO.md › 8. Tooling Philosophy; legacy/plan/08-implementation-module.md › Decisions & rationale; legacy/plan/12-build-order-and-milestones.md › Status (milestone 0); legacy/plan/12-build-order-and-milestones.md › Sequence (0. Scaffolding spike); legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › Full pipeline with real TagLibSharp and ffmpeg › applies the release, writes correct real tags and cover, and sanitizes invalid characters

The app uses existing, well-known tools and does not build its own. Apply starts ffmpeg as a separate program to split cue releases and to resize covers. It loads TagLibSharp into its own process to read and write tags and embedded covers. No GUI tool and no hand-made tagger setup is needed. (The plan dropped mp3tag, cuetools, shntool and mp3splt.)

Example: a real run with `ffmpeg` from PATH and `<dataHome>\lib\TagLibSharp.dll` applies `Radiohead\1997 OK Computer` with correct tags and cover (AS-DOC-APL-070).

### AS-DOC-ERR-013 — A missing TagLibSharp.dll gives an install hint
Status: Draft | Source: legacy/tests/Reshelf.TagLibSharp.Integration.Tests.ps1 › (file header comment and BeforeAll)

When `TagLibSharp.dll` is not found, the app stops with an install hint: get the `TagLibSharp` NuGet package, copy `TagLibSharp.dll` from its `lib/netstandard2.0` folder to `<dataHome>\lib\TagLibSharp.dll`, or set `settings.taglibSharpPath`. (The test comment says that the app's own loader gives the same hint as the test.)

Example: no file at `<dataHome>\lib\TagLibSharp.dll` → message `TagLibSharp.dll not found at '<dataHome>\lib\TagLibSharp.dll'. Download the TagLibSharp NuGet package …`.

### AS-DOC-ERR-014 — Scripts first, AI help only where automation is not realistic
Status: Draft | Source: MANIFESTO.md › 8. Tooling Philosophy

The product is scripts, JSON documents and HTML/JS files. For steps that are hard to automate (for example recognizing releases), the user or AI help steps in. AI help comes as general "skills" that work with several AI assistants, not as custom automation. Scripts are always the first choice.

Example (illustration): recognition is a script; for an unusual folder, the user (or an AI skill that helps the user) decides how to move or rename it (AS-DOC-ERR-007).

## Open questions in the sources

These items are open in the sources. They are not requirements.

### MANIFESTO.md §9 — Open questions for the next planning session

| Open question (manifesto) | What later sources say |
|---|---|
| How does a static-site UI edit and save changes without a server? | Not static any more: the README describes a localhost UI server (`ui start`, `-Port`). See AS-DOC-DEF-107 and AS-DOC-DEF-110 in [90-suspected-defects.md](90-suspected-defects.md). |
| Which Discogs integration (API, auth, rate limits, match confidence)? | Answered in other plan files: see [06-discogs-client.md](06-discogs-client.md), [07-proposal-matching.md](07-proposal-matching.md). |
| How are re-runs handled (skip present releases, duplicates, update)? | Answered by plan 10: stableKey + source file-set hash (AS-DOC-APL-010, AS-DOC-APL-011, AS-DOC-ERR-004 to AS-DOC-ERR-006). |
| Same release twice, path length, invalid characters, unclear folders? | Answered by plan 10: AS-DOC-ERR-005, AS-DOC-ERR-003, AS-DOC-APL-056 to AS-DOC-APL-060, AS-DOC-ERR-007; safe names in [02-text-and-naming-rules.md](02-text-and-naming-rules.md). |
| What is stored in a session and how does resume work? | Answered by plan 10 and README: see [04-sessions.md](04-sessions.md). |
| Which CLI tagger (mp3tag, metaflac, …)? | Answered by plan 08: none — TagLibSharp in-process (AS-DOC-ERR-012). |

### legacy/plan/13-bandcamp-fallback.md — research questions (not answered)

1. Does Bandcamp have a public search API, even an undocumented one?
2. If not, do Bandcamp's Terms of Service and `robots.txt` (also on artist subdomains such as `retrowavetouchrecords.bandcamp.com`) allow scraping?
3. Is the structured data on a page (`data-tralbum` JSON, JSON-LD) present and stable on all page types, and which fields does it have?
4. How would the app find the Bandcamp page for an artist and album (which web search, at what cost)?
5. Is the chosen mechanism free at personal-collection volume?
6. Which rate limits apply, and does the Discogs cache/throttle design fit?
7. Is the data usable for names and tags, case by case (Axion, Straplocked & Ray Gun Hero, Wuneny)?

The plan also notes a design for the case that the feature is built: same trust and casing order as Discogs, the same per-track artist and compilation shape, and a `discogsMatch` or new `bandcampMatch` field in `proposal.json`. This is not built and not current behavior.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-05 | Phase 1 draft. |
