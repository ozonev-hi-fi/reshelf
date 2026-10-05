# Step 12 — Build Order and Milestones

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
| 3–7 | Real-sample milestones | **Confirmed** — real source `D:\MusicToOrganize\Electro` (296 files, 6.17 GB, 15 top-level folders), real target `D:\Tagger\Target`. Recognize/propose iterated three times against real data until `overrides.json` and the heuristics handled it cleanly (matched 23/27, needsReview 8, 0 unrecognized on the final session `2026-09-26-0003`). UI round-trip reviewed; the one finding (a missing-first-track release numbering file names from a plain counter instead of the real track position) was fixed in both `propose` and the UI. Real apply: 27/27 releases applied across two runs, byte-identical source before/after. Idempotency: an unchanged re-run resolved every applied release to `skip-existing-identical`, `-WhatIf` made zero writes. Upgrade path: a lossy→lossless re-import (Pulsar Olymp – 94 Shine, mp3 then FLAC) first exposed a second real bug — the existing target folder was found by `stableKey`, computed from the *source* folder's names, while Discogs-corrected target folder names use a different key, so the old lossy folder was invisible and apply would have deleted it under `create-new` with no ledger update. Fixed (see [06](06-edit-proposal-module.md) target lookup and [08](08-implementation-module.md) commit guard); after the fix the ledger correctly flipped to `upgraded` and the target held only the FLAC files. |
| 8 | Scale up | **Ongoing by design** (manifesto §3) — not a one-time gate. Next batches grow `overrides.json` as new patterns surface. |

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
