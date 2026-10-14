# 13 — Bandcamp fallback and cross-cutting error handling (as-is, merged)

Status: Draft | Version: 0.1 | Last updated: 2026-10-14

## Scope

Two areas in one file, the last of this phase:

- **BND** — the Bandcamp fallback. Not built: Discogs is the only external
  metadata source.
- **ERR** — error handling and edge cases that are not specific to one
  stage, plus the tooling philosophy.

Sources: `br/as-is-from-docs/13-bandcamp-and-errors.md` (`AS-DOC-BND-001`–
`002`, `AS-DOC-ERR-001`–`014`, from `legacy/plan/13-bandcamp-fallback.md`,
`legacy/plan/10-error-handling-and-edge-cases.md`, `legacy/plan/08-
implementation-module.md` › Edge cases, `legacy/README.md` › Troubleshooting,
`MANIFESTO.md` §8–9) and `br/as-is-from-code/13-bandcamp-and-errors.md`
(`AS-CODE-BND-001`–`002`, `AS-CODE-ERR-001`–`005`, a cross-cutting grep sweep
of `legacy/scripts/**` and `legacy/ui/**`, independent of phase 1).

Apply-specific failure rules (failed release, staging left for inspection,
retry, path truncation) stay owned by [10-apply.md](10-apply.md); this file
links to them by ID rather than restating them.

**ID numbering for this area:** 2 `AS-BND-*` (`001`–`002`) and 11 `AS-ERR-*`
(`001`–`011`), 13 merged items total from 23 source ids (16 `AS-DOC-*` + 7
`AS-CODE-*`). Eight `AS-DOC-ERR-*` items turned out to be pure restatements of
facts another, already-merged area owns outright — once a mechanism has a
real owner (APL, PRP, DSC, REC, DAT), this file links to it instead of
duplicating it, the same "redirect with no new id" treatment CLI and LSY used
repeatedly:

| Doc item | What it restates | Redirected to |
|---|---|---|
| `AS-DOC-ERR-001` | Recovery workflow after a failed release | `AS-APL-013`, `AS-APL-045`, `AS-APL-057` |
| `AS-DOC-ERR-002` | Nothing lands at the final path until every step succeeds | `AS-APL-017` |
| `AS-DOC-ERR-003` | The `\\?\` long-path prefix | `AS-DAT-072`–`075` (see the new contradiction below — this item's own "plan only, no test" framing was wrong) |
| `AS-DOC-ERR-004` | No silent overwrite of an existing target | `AS-APL-018`; cross-referenced with `AS-PRP-083`, `AS-PRP-086` |
| `AS-DOC-ERR-005` | A same-session duplicate is compared with the first occurrence | `AS-PRP-085` |
| `AS-DOC-ERR-006` | An identical existing release causes no fresh Discogs HTTP call | already resolved as `AS-DOC-DEF-058` during the PRP merge, via `AS-DSC-019`/`020`'s cache |
| `AS-DOC-ERR-007` | Unclear folders are never guessed | `AS-REC-010` (`AS-DOC-DEF-019`, closed during the REC merge) |
| `AS-DOC-ERR-013` | A missing `TagLibSharp.dll` gives an install hint | `AS-DAT-087` |

The remaining six `AS-DOC-ERR-*` items (`008`–`012`, `014`) are genuine
README/MANIFESTO-only facts with no other owner, merged as `AS-ERR-001`–
`004` (known limitations) and `AS-ERR-005`–`006` (tooling). All five
`AS-CODE-ERR-*` items are additive, code-only, cross-cutting facts with no
doc-side counterpart at all (by design — the phase 2 sweep explicitly looked
for patterns *not* already owned by `10-apply.md`, `11-lossy-tracking.md` or
`12-cli.md`); merged as `AS-ERR-007`–`011`.

**Contradictions resolved while merging this area:** one new contradiction
found (`AS-DOC-ERR-003`'s "plan only, no test" framing was itself wrong — the
long-path prefix is fully tested, just filed under `AS-DOC-DAT-072`–`075` by
a different phase-1 author) and four pre-existing `AS-DOC-DEF-*`
contradictions (`106`, `107`, `108`, `110`), all re-verified against the
code. See `90-contradictions-resolution.md`.

**Suspected defects carried forward:** one — the still-accurate half of
`AS-DOC-DEF-109` (the full-disk-during-copy case has no test; its long-path
half is now corrected, not carried, per the new contradiction above). See
`91-suspected-defects-carryforward.md` (`CF-ERR-001`).

## Bandcamp fallback (BND)

### AS-BND-001 — Discogs is the only external metadata source; Bandcamp is not built
Status: Draft | Source: AS-DOC-BND-001; AS-CODE-BND-001; AS-CODE-BND-002

The app looks up releases only on Discogs. When Discogs has no match, the
release stays `not-found`, needs human review, and apply skips it by default
(`AS-APL-003`). There is no other source. A case-insensitive search for
`bandcamp` across every file under `legacy/scripts/**` and `legacy/ui/**`
turns up exactly two matches, both inside `#` comments (not a string
literal, config key, schema field, function name, UI element or executable
logic): `Reshelf.EditProposal.psm1:1453` and `Reshelf.Common.psm1:256`. This
independently confirms, from code alone, that Bandcamp is a documented
future intent, not a stub or partial implementation.

Example (plan 13): `Straplocked & Ray Gun Hero - Stalemate` is not on
Discogs but is on `https://burningowlrecords.bandcamp.com/album/stalemate` →
the app gives `not-found`.

Example (test): Discogs returns zero results for the whole fixture tree →
every release needs review; with no other source, apply gives `Applied 0`.

### AS-BND-002 — A Bandcamp hit would not always have usable data (plan only)
Status: Draft | Source: AS-DOC-BND-002

The plan records that a release found on Bandcamp does not always have data
good enough for names and tags — some pages only confirm that the release
exists. This is a finding from a manual review, not app behavior; nothing in
code or tests touches it (`AS-BND-001`).

Example: `Wuneny - whatever singularity` on
`https://moonleedistribution.bandcamp.com/album/vuneny-whatever-singularity`
→ the page metadata is too sparse and inconsistent to help.

## Known limitations from the README (ERR)

### AS-ERR-001 — UI port in use: the user picks another port
Status: Draft | Source: AS-DOC-ERR-008; cross-referenced with AS-REV-032, AS-CLI-015

When the review UI cannot start because its port is in use, the user starts
it with another port. `ui start`'s default port (4173) and its `-Port`
forwarding are owned by `AS-REV-032` and `AS-CLI-015`; this item only
records the user-facing recovery step.

Example (illustration): `pwsh scripts/Reshelf.ps1 ui start -Port 8081`.

### AS-ERR-002 — Discogs 401 means a missing or invalid token
Status: Draft | Source: AS-DOC-ERR-009; cross-referenced with AS-DSC-006, AS-DSC-012, AS-SET-042

When Discogs answers `401 Unauthorized`, the app stops at once with no retry
(`AS-DSC-012`) — distinct from the "no token found anywhere" error
(`AS-DSC-006`), since a 401 means a token was sent but Discogs rejected it,
not that none was found. Either way the user's fix is the same: run
`settings set-token` again (`AS-SET-042`).

Example (illustration): `propose` gets `401 Unauthorized` → the user runs
`pwsh scripts/Reshelf.ps1 settings set-token`.

### AS-ERR-003 — The UI cannot force a match from a Discogs URL or ID
Status: Draft | Source: AS-DOC-ERR-010; cross-referenced with AS-REV-100, AS-REV-101

The review UI has no field to paste a Discogs release URL or release ID to
force a match. The user can only pick among the candidates the edition
picker already lists (`AS-REV-100`/`101`).

Example (illustration): the right release is
`https://www.discogs.com/release/<id>` but propose did not list it among the
candidates → the UI gives no way to enter it directly.

### AS-ERR-004 — The last Save wins between browser tabs
Status: Draft | Source: AS-DOC-ERR-011; cross-referenced with AS-REV-013

The review UI does not detect conflicts between two browser tabs or two
sessions open on the same proposal. Save always writes the full body it was
sent (`AS-REV-013`) with no version check against what is already on disk,
so the last Save overwrites whatever an earlier, still-open tab saved
before it, silently.

Example (illustration): tab A saves a new title, then tab B (opened before
tab A's save) saves → the title from tab A is lost, with no warning to
either tab.

## Tooling (ERR)

### AS-ERR-005 — Apply uses ffmpeg as an external program and TagLibSharp as an in-process library; no custom GUI tool
Status: Draft | Source: AS-DOC-ERR-012; cross-referenced with AS-APL-066, AS-DAT-086, AS-DAT-087

The app uses existing, well-known tools instead of building its own. Apply
starts ffmpeg as a separate process to split cue releases and resize covers,
and loads TagLibSharp into its own process to read and write tags and
embedded covers (`AS-DAT-086`/`087` for how TagLibSharp is resolved and
loaded). No GUI tool and no hand-made tagger setup is needed — the plan
dropped mp3tag, cuetools, shntool and mp3splt once this design was settled.

Example: a real run with `ffmpeg` from PATH and `<dataHome>\lib\
TagLibSharp.dll` applies `Radiohead\1997 OK Computer` with correct tags and
cover (`AS-APL-066`).

### AS-ERR-006 — Scripts first; AI/human help only where automation is not realistic
Status: Draft | Source: AS-DOC-ERR-014; cross-referenced with AS-ERR-003 (merged numbering; the folder-recognition case)

The product is scripts, JSON documents and HTML/JS files. For steps that are
hard to automate — recognizing an ambiguous folder being the one real
example in this app — the user, or AI help acting on the user's behalf,
steps in instead. AI help comes as general-purpose "skills" that work with
several AI assistants, not as custom automation built into the product.
Scripts are always the first choice.

Example (illustration): recognition is a script; for an unrecognized folder
(`AS-REC-010`), the user — or an AI skill helping the user — decides how to
move or rename it on disk.

## Cross-cutting error-handling mechanics (code-only)

These five facts come only from a code-wide sweep (`legacy/scripts/common/
*.psm1`, `legacy/scripts/*.ps1`), independent of any plan or test wording,
and were not already stated as a general rule by any other area.

### AS-ERR-007 — Every JSON-backed store validates against its schema before being trusted; "missing file" and "invalid file" are handled differently
Status: Draft | Source: AS-CODE-ERR-001; cross-referenced with AS-LSY-002, AS-SES-008, AS-APL-007, AS-SET's settings-schema checks

Every module that owns or reads a JSON-backed document follows the same
two-step guard — confirmed across settings and session schemas
(`Reshelf.Settings.psm1`), the recognition schema (`Reshelf.EditProposal
.psm1`), the apply-log and proposal schemas (`Reshelf.Implementation.psm1`)
and the lossy-tracking schema (`Reshelf.LossyTracking.psm1`, `AS-LSY-002`):
a schema-validation check runs before the content is parsed and used, and on
mismatch the code throws `"<Noun> at '<path>' does not match the <schema-
name> schema."` A file that simply doesn't exist yet is treated differently
from one that exists but fails validation: list/ledger/log readers return an
empty array for "file not found" (`AS-LSY-002`, `AS-APL-007`), and only
throw once a present file fails schema validation.

### AS-ERR-008 — "Write-Error" is never used anywhere in the app; "throw" and "Write-Warning" divide the work
Status: Draft | Source: AS-CODE-ERR-002

A sweep of every module and script file finds zero uses of `Write-Error`
anywhere in the app. Every hard failure is surfaced by `throw` (a
terminating exception), caught locally and turned into a result object or
log entry, or left to propagate to the caller. `Write-Warning` is the sole
mechanism for "something is off, but not fatal": the lossy-tracking
mutators warning-and-no-op on an unmatched `stableKey`, the ffmpeg
split warning on a successful FLAC-retry recovery, the Discogs client's
cache-cleanup warning when it can't delete a stale cache file, and the UI
server warning per failed HTTP request rather than crashing its listener
loop.

### AS-ERR-009 — No global "$ErrorActionPreference"; terminating behavior is opted into per cmdlet call with "-ErrorAction Stop"
Status: Draft | Source: AS-CODE-ERR-003; cross-referenced with AS-APL-017 (the one documented exception)

`$ErrorActionPreference` is never set anywhere in the app, so PowerShell's
own per-cmdlet default (mostly non-terminating "Continue") applies
everywhere except where a call site explicitly adds `-ErrorAction Stop`.
That opt-in is deliberate, applied only where a cmdlet's silent-continue
default would otherwise hide a real failure behind a later, more confusing
symptom: `Get-Item`, `Remove-Item` (Discogs cache cleanup), `New-Item`
(settings' data-folder creation), and `Copy-Item` (apply's track/companion
staging copies). Apply's own directory-creation `New-Item` calls do **not**
follow this opt-in — a documented inconsistency within that one module, not
a sign the app-wide pattern is absent elsewhere (`AS-APL-017`'s own carried-
forward note).

### AS-ERR-010 — No shared retry/backoff helper; two independent, unrelated retry implementations
Status: Draft | Source: AS-CODE-ERR-004; cross-referenced with AS-DSC-013, AS-DSC-014, AS-APL-030

There is no shared, reusable retry-with-backoff utility anywhere in the app.
The only two places that retry at all reimplement it independently, for
unrelated reasons, with no code shared between them: the Discogs client's
generic up-to-3-attempt loop with a fixed 1s/2s/4s backoff, or a longer
20s/40s/60s backoff on HTTP 429 preferring the server's own `Retry-After`
header (`AS-DSC-013`/`014`); and apply's ffmpeg split, which retries exactly
once, only for one specific ffmpeg stderr message ("invalid block size"), by
nudging a timestamp forward 0.05 seconds (`AS-APL-030`). Neither module is
aware of or reuses the other's retry logic.

### AS-ERR-011 — No general-purpose error/diagnostic log; only apply-log.json persists a failure message, and only for apply
Status: Draft | Source: AS-CODE-ERR-005; cross-referenced with AS-APL-057

There is no centralized error or diagnostic log file anywhere in the app.
`Write-Warning`/`Write-Verbose` output goes only to the PowerShell host's
own streams and is never persisted to disk. The sole place any failure text
reaches a file is `apply-log.json`'s own `errorMessage` field on a `failed`
entry (`AS-APL-057`) — an apply-specific, per-release record. A failure
during `recognize`, `propose`, `settings`, or any `lossy` subcommand leaves
no durable trace beyond whatever the calling terminal happened to display.

## Not behavior: research and open questions in the sources

- `legacy/plan/13-bandcamp-fallback.md`'s seven research questions (public
  search API, `robots.txt`/ToS, `data-tralbum`/JSON-LD stability, how the app
  would find a Bandcamp page, cost, rate limits, and per-case data quality)
  are unanswered and describe a feature that is not built (`AS-BND-001`).
  The plan also sketches a design for if it is ever built: same trust/casing
  order as Discogs, the same per-track-artist/compilation shape, and a
  `discogsMatch`-shaped `bandcampMatch` field in `proposal.json`. Not current
  behavior; useful only as phase 4 input if Bandcamp is ever prioritized.
- MANIFESTO §9's open-questions list (static-site editing, which CLI tagger,
  re-run/duplicate handling, path length/invalid characters/unclear folders,
  session storage/resume) is answered by the plans and the README — see
  `AS-DOC-DEF-107`/`108`/`110` below for where some of those answers
  contradict the question's own premise. The manifesto itself was never
  updated to reflect the answers; see `90-contradictions-resolution.md`.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-14 | Area BND/ERR merged: 2 `AS-BND-*` + 11 `AS-ERR-*` (13 total) reconciling 2+14 `AS-DOC-*` + 2+5 `AS-CODE-*`. One new contradiction found (`AS-DOC-ERR-003`'s "plan only, no test" framing for the `\\?\` long-path prefix was wrong — it's fully tested, already merged as `AS-DAT-072`–`075`) plus four pre-existing `AS-DOC-DEF-*` contradictions resolved (`106`: staging always used final names, not short-names-then-rename; `107`/`110`: the README/code localhost UI server is right, MANIFESTO §8/§9 are stale pre-implementation vision; `108`: the single-entry-script, in-process-TagLibSharp design is right, MANIFESTO §8's CLI-tagger/one-script-per-module vision predates it). One suspected defect carried forward (`CF-ERR-001`: the full-disk-during-copy case has no test — the other half of `AS-DOC-DEF-109`, its long-path half, is corrected rather than carried, per the new contradiction). Eight `AS-DOC-ERR-*` items redirected with no new id to already-merged APL/PRP/DSC/REC/DAT requirements that already owned the fact outright — see the table above. This is the last of the 13 numbered areas; only `90`/`91`/`92` and the user's own review of `br/as-is-merged/README.md` remain before phase 3 closes. |
