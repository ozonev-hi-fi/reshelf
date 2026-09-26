# Step 12 — Build Order and Milestones

> ## ⚠️ TEMPORARY HANDOFF NOTE (2026-09-26) — delete this whole block once all
> ## milestones below pass and the collection has actually been reviewed/applied
>
> This block exists only to resume a conversation that ran out of context.
> Delete it (and nothing else in this file) once milestones 6–8 are done for
> real. If you are Claude picking this up fresh with no other context: read
> this block, then say to the user something like *"Picking up where we left
> off — please review session `2026-09-26-0003` in the UI
> (`pwsh scripts/Reshelf.ps1 ui start`) — check the Lossy tracker tab and the
> Unrecognized section too, and try editing Artist/Album/Year to see the
> folder name update live. Tell me what you find and I'll continue with M6
> (apply) and M7 (idempotency/upgrade) once you're happy with this session."*
> Do not re-derive any of the below from scratch — it's all already done and
> committed on `develop` (working tree was clean as of this note).
>
> **Where things stand:**
>
> - Real source root for milestones 3–8: `D:\MusicToOrganize\Electro`
>   (portable drive — pass `-SourceRoot` explicitly each time, it is *not*
>   saved as `defaultSourceRoot`). 296 files, 6.17 GB, 15 top-level folders —
>   verify unchanged (file count + size) before/after any apply run.
> - Target root stays `D:\Tagger\Target` (already has 9 real applied releases
>   from earlier testing: Die Krupps ×6, John 5, Santa Hates You, ZZ-Top-style
>   fixtures are separate/unrelated — those are from the Pester fixture tree,
>   not this real data).
> - **Milestones 0–2**: confirmed, see Status table below (unchanged, done
>   long before this session).
> - **Milestone 3 (recognize) + Milestone 4 (propose)**: done against the real
>   sample, iterated twice on real bugs found, then a third time after a large
>   UI-feedback round. Current, up-to-date session: **`2026-09-26-0003`**
>   (matched 23/27, needsReview 8, 0 unrecognized). Two earlier sessions
>   (`2026-09-26-0001`, `-0002`) are stale/superseded — ignore them, don't
>   re-review them, they predate bug fixes.
> - **Milestone 5 (UI round-trip)**: NOT YET DONE by the user. This is the
>   very next step — the user was asked to open `2026-09-26-0003` in the UI,
>   resolve real ambiguous/not-found releases, try the new folder-name live
>   preview, check the Unrecognized panel (should show 0 entries — `edbl` is
>   now recognized, not unrecognized) and the new Lossy tracker tab, Save,
>   reload, confirm it round-trips. **Waiting on the user's findings from
>   this before doing anything else.**
> - **Milestones 6 (apply) and 7 (idempotency/upgrade)**: not started yet.
>   Do these only after the user confirms milestone 5 is good. See the
>   "Sequence" section below for the exact runbook (M6/M7 haven't changed).
>   Reminder for M7's upgrade-test: transcode one small FLAC release (e.g.
>   `Axion\The Conquest of Space`) to mp3 in the scratchpad, apply the mp3
>   copy first, then the real FLAC folder, confirm the ledger flips to
>   `upgraded` — **then delete the scratchpad mp3 copy** (per earlier user
>   instruction, don't forget this cleanup).
> - **Milestone 8**: ongoing by design, not a one-time gate.
>
> **What was fixed this round** (all committed on `develop`, all tests green —
> 497 Pester + 42 Playwright — at commit `f20274e`; commits in order:
> `c18bd35`, `ddcc3f2`, `26a67d0`, `38e176a`, `5b1250c`, `f23b744`, `f20274e`):
>
> 1. Lossy-tracking `targetPath` went stale after first sighting — fixed,
>    now refreshed on every sighting and corrected to the real committed path
>    after apply.
> 2. Recognition: a release folder repeating its own artist folder's name
>    (e.g. "DANCE WITH THE DEAD - Blackout" inside artist folder "Dance with
>    the dead") failed Discogs search outright — now stripped
>    (`artist-name-prefix-stripped`).
> 3. Recognition: a `release-without-artist-suspected` folder (e.g. `edbl`)
>    whose tracks agree on tags is now promoted to a real release instead of
>    staying invisible in `unrecognized[]`.
> 4. Discogs search: title noise (parenthetical catalog/edition text, trailing
>    edition words) made real releases return zero search results — now tried
>    both raw and cleaned.
> 5. Discogs match: multiple same-scoring candidates (single vs. album vs.
>    promo) picked the first one by search order, sometimes wrong — now picks
>    by real tracklist-count match, falling back to Album-format preference.
> 6. A Discogs tracklist-count mismatch always fell back to source titles
>    entirely — now tries title-similarity alignment first (handles "source
>    is missing one bonus track" correctly).
> 7. Casing: Discogs's own casing always wins; only the no-match fallback
>    path gets automatic Title Case now (previously nothing did this, or it
>    was inconsistent).
> 8. Zero-width/invisible Unicode characters from Discogs text (a real one:
>    hidden characters around a dash in an album title) are now stripped
>    before use in names/tags.
> 9. A lossless re-import of an already-lossy-tracked release, under a
>    *different* folder name than the original lossy import, was completely
>    missed by the ledger (different `stableKey`) — now detected by
>    normalized artist+year+fuzzy-album match, surfaced as
>    `previously-lossy-different-location` / `previously-lossy-target-missing`,
>    never auto-touches the old folder ("keep both, only warn").
> 10. New `Reshelf.ps1 lossy remove`/`lossy export` CLI commands.
> 11. UI: session id now shown (small label, not the main status text);
>     editing Artist/Album/Year now live-updates the Artist Folder/Release
>     Folder fields and the before/after table; table-cell inputs are full
>     width; a new **Unrecognized** sidebar section with a generated
>     `overrides.json` entry ready to copy; a new **Lossy tracker** tab
>     (view/edit/delete/export, CSV+JSON). Two incidental bugs found and
>     fixed along the way: a PowerShell array-serialization bug that could
>     silently break `/api/sessions`/`/api/lossy` on a single-row result, and
>     a CSS specificity bug where `hidden` silently did nothing on an element
>     that also had its own `display` rule.
> 12. New `plan/13-bandcamp-fallback.md` — a Bandcamp-as-fallback-source
>     feature request, **not implemented**, written up as research questions
>     only (no public API, ToS unclear, data quality inconsistent per the
>     real examples that prompted it).
>
> All of the above have Pester and/or Playwright tests. Docs updated:
> `plan/05`, `plan/06`, `plan/07`, `plan/09`, `plan/00-overview.md`,
> `plan/13` (new).
>
> > ⚠️ End of temporary handoff note.

## Purpose / scope

A concrete, incremental order to actually build and test this, so value and
confidence accumulate step by step instead of writing all 5 modules before
anything is verified against real data. This is a narrative sequence, not a
new design — every item below points back to the step file that defines it.

## Status

| # | Milestone | State |
|---|-----------|-------|
| 0 | Scaffolding spike | **Confirmed** — the real `Integration`-tagged tests (`tests/Reshelf.TagLibSharp.Integration.Tests.ps1`) load the real `TagLibSharp.dll` via `Add-Type` and call a real `ffmpeg`, both reading and writing tags/cover art, and pass (see [11](11-testing-and-verification-strategy.md)). |
| 1 | Discogs access + caching/throttling spike | **Confirmed** — see below. |
| 2 | Schemas + settings | **Confirmed** — `tests/Reshelf.Schemas.Tests.ps1` and `tests/Reshelf.Settings.Tests.ps1` pass against real schema files and a real `Reshelf.Settings.psm1`. |
| 3–8 | Real-sample milestones | **In progress** — real source is `D:\MusicToOrganize\Electro` (portable drive, pass `-SourceRoot` explicitly). Milestones 3 (recognize) and 4 (propose) done, see the ⚠️ TEMPORARY HANDOFF NOTE above for the current session id and exact status; milestone 5 (UI round-trip) is waiting on the user; 6–8 not started. Delete this row's detail once the handoff note above is deleted and replace with a normal confirmed/done summary. |

### Milestone 1 — confirmed

Run directly against `scripts/common/Reshelf.Discogs.psm1`'s real
`Invoke-DiscogsRequest` (not mocked), using the token already configured via
`.env`:

- One real `GET /database/search` (`q=Radiohead OK Computer`) and one real
  `GET /releases/{id}` on the first hit — both succeeded, returning real
  search results and a real 16-track tracklist.
- `X-Discogs-Ratelimit`, `-Remaining`, and `-Used` headers are present on a
  real response and read correctly (PowerShell's response-header dictionary
  is case-insensitive, so the exact header-name casing Discogs sends doesn't
  matter). The account's real per-minute ceiling is **60**, not 55 — the
  tool's own `rateLimitPerMinute` default (55) stays a deliberately
  conservative self-imposed cap under the real one, not a copy of it.
- `.data/cache/discogs/` filled with one file per unique request.
- An identical repeat request was served from the cache file, not a second
  live HTTP call (confirmed via an unchanged cache-file count across the
  repeat call).

The cache/throttle wrapper this milestone was meant to validate already
exists and is covered by 31 tests in `tests/Reshelf.Discogs.Tests.ps1`,
including the re-run cache pruning added in [02](02-discogs-account-and-api-access.md).

## Sequence

**0. Scaffolding spike** — [01](01-repo-and-tooling-scaffolding.md).
Verify ffmpeg is callable from `pwsh`, and that TagLibSharp.dll loads via
`Add-Type` and can both read and write tags/cover art in-process, before
writing any Reshelf code. (cuetools/shntool/mp3splt were the original plan for
cue-sheet splitting but had no reliable Windows install path — ffmpeg alone
handles this instead, see [01](01-repo-and-tooling-scaffolding.md) and
[08](08-implementation-module.md). mp3tag was the original plan for tag
*writing* specifically, but its Action-Group-from-a-file mechanism the plan
assumed couldn't be confirmed as a real, scriptable feature — TagLibSharp,
already a dependency for reading, writes tags too and needed no such spike.)

**1. Discogs access + caching/throttling spike** — [02](02-discogs-account-and-api-access.md).
Get a token, make one real search and one real release-detail call by hand
(e.g. via `Invoke-RestMethod`), confirm the User-Agent/rate-limit headers
behave as documented, then build the cache/throttle wrapper.

**2. Schemas + settings** — [03](03-domain-model-and-json-schemas.md),
[04](04-settings-module.md). Write the schema files, `Reshelf.Settings.psm1`,
and the first-run wizard. Nothing to verify against real data yet, but
everything downstream depends on this being right.

**3. Recognition against a small real sample** — [05](05-recognition-module.md).
Point it at a small, deliberately messy slice of the user's actual
collection — including at least one grouping-folder case and one
multi-disc case, not just the synthetic fixture. Hand-inspect the resulting
`recognition.json`, iterate the heuristics and `overrides.json` until
`unrecognized[]`/`needsReview` is small. This matches the manifesto's own
implied expectation that recognition needs iteration against real chaos, not
just fixture data.

Runbook (once `E:\Electro` — or whatever real source root — is mounted):

```powershell
pwsh scripts/Reshelf.ps1 recognize -SourceRoot 'E:\Electro'
```

Then open the printed `recognition.json` path and check: the count of
`unrecognized[]` entries (should be small — each one is a folder pattern the
heuristics didn't handle); every release's `recognitionFlags`/`needsReview`
(a real "grouping folder" or "band-member-as-artist" case should show up
here, not be silently absorbed); disc/track numbering on any real multi-disc
album matches what's actually in the folder. Iterate by adding entries to
`overrides.json` (see README's "Reference: overrides file") and re-running
`recognize` — safe to repeat, per [10](10-error-handling-and-edge-cases.md).

**4. Edit Proposal against that same sample** — [06](06-edit-proposal-module.md).
Run against the real `recognition.json` from step 3, inspect
`proposal.json` by hand for correct Discogs matches and correct
naming/tagging per manifesto §5.

Runbook:

```powershell
pwsh scripts/Reshelf.ps1 propose -SessionId <id-from-step-3>
```

Check: `discogsMatch.status` distribution (how many `matched` vs.
`ambiguous` vs. `not-found` — a real collection will have some of each);
spot-check a handful of `matched` releases' `tags`/`proposed` fields against
the actual Discogs page for that release; confirm `coverArt.candidates`
includes both Discogs images and any local companion cover.

**5. Editing UI round-trip** — [07](07-editing-ui-module.md). Open that
sample's `proposal.json` in the browser, make a manual correction, save, and
confirm it round-trips correctly before trusting it on a larger batch.

Runbook: `pwsh scripts/Reshelf.ps1 ui start`, resolve a few real `ambiguous`
matches, correct a real messy title, Save, reload, confirm the edits are
still there and `proposal.backup.json` has the pre-save version. The
Playwright suite ([11](11-testing-and-verification-strategy.md)) already
covers the UI mechanics generically — this milestone is specifically about
real Discogs data surfacing something the synthetic fixture didn't.

**6. Implementation, dry-run then real** — [08](08-implementation-module.md).
`-WhatIf` first against the sample, inspect the intended-action log, then run
for real into a throwaway target directory. Spot-check tags, cover art,
`lossy-tracking.json`, and `apply-log.json`.

Runbook:

```powershell
pwsh scripts/Reshelf.ps1 apply -SessionId <id> -WhatIf
# inspect the WhatIf output, then:
pwsh scripts/Reshelf.ps1 apply -SessionId <id>
```

Point `settings.json`'s `targetRoot` at a throwaway folder for this first
real run. Spot-check: open a resulting file in a real player/tag editor and
confirm the embedded cover and tags look right; check `apply-log.json` for
any `failed` entries and read their `errorMessage`.

**7. Idempotency and upgrade validation** — [10](10-error-handling-and-edge-cases.md),
[09](09-lossy-lossless-tracking.md). Re-run the whole pipeline unchanged
against the same sample and confirm everything resolves to
`skip-existing-identical` with no duplicate work. Then simulate a
lossless-arrives-later case (re-import the same release from a lossless
source) and confirm the upgrade path replaces the target and updates the
ledger correctly.

Runbook: re-run `recognize` → `propose` → `apply` against the *same* source
root unchanged; confirm `apply`'s summary shows `Skipped` for everything and
`.reshelf-staging` is empty afterward. Then point a fresh `recognize` at a
lossless copy of one already-applied (lossy) release and confirm
`lossyLossless.action == "replace-existing"` in its `proposal.json`, and
that `apply` replaces the target folder and updates `lossy-tracking.json`'s
entry to `status: "upgraded"`.

**Automated regression coverage added 2026-09-26**: a real bug was found
while re-verifying this milestone against fixture data — `propose`'s target
comparison (`Resolve-ReshelfTargetComparison`, `Reshelf.EditProposal.psm1`)
compared the *target folder's* file-set hash against the source, but
Implementation renames every file and rewrites its tags on apply, so that
hash could never match again; re-running `propose` after a real `apply`
produced `targetAction: "conflict"` for everything instead of
`skip-existing-identical`, breaking this exact milestone. Fixed by checking
`apply-log.json`'s own recorded source hash first (the same check
[08](08-implementation-module.md)'s own skip logic already used) — see
[06](06-edit-proposal-module.md)'s target-comparison section for the
corrected design. `tests/Reshelf.Pipeline.Tests.ps1` now runs recognize →
propose → apply → recognize → propose against the full fixture tree and
asserts every applied release resolves to `skip-existing-identical` on the
second `propose`, so this milestone's core claim has automated coverage even
before it's re-run against real data.

**8. Scale up** — process the real legacy collection in batches (not one
giant run), growing `overrides.json` as new ambiguous patterns surface.
Per the manifesto §3, this stays an ongoing, repeatable process — v1 done
doesn't mean "collection organized," it means "tool is trustworthy enough to
run repeatedly."

## Decisions & rationale

- **Real sample before scaling up, at every module**: the manifesto's own
  problem statement (§1) is that the real collection has messiness patterns
  the user isn't even fully aware of yet — synthetic fixtures alone can't
  surface those, only a real (small) sample can, at low risk.
- **Never process the whole collection in one run, even at v1's finish
  line**: matches the manifesto's explicit framing (§3) of this as an
  ongoing process, not a one-shot migration — batching also limits the blast
  radius of any remaining heuristic gap.

## Definition of done (for the plan as a whole)

- All 8 milestones above have been executed at least once against real data
  from the user's actual collection, not just fixtures.
- The user has reviewed and adjusted `overrides.json` at least once based on
  a real ambiguous case it surfaced.
