# Step 12 — Build Order and Milestones

## Purpose / scope

A concrete, incremental order to actually build and test this, so value and
confidence accumulate step by step instead of writing all 5 modules before
anything is verified against real data. This is a narrative sequence, not a
new design — every item below points back to the step file that defines it.

## Sequence

**0. Scaffolding spike** — [01](01-repo-and-tooling-scaffolding.md).
Verify ffmpeg is callable from `pwsh`, and that TagLibSharp.dll loads via
`Add-Type` and can both read and write tags/cover art in-process, before
writing any Tagger code. (cuetools/shntool/mp3splt were the original plan for
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
[04](04-settings-module.md). Write the schema files, `Tagger.Settings.psm1`,
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

**4. Edit Proposal against that same sample** — [06](06-edit-proposal-module.md).
Run against the real `recognition.json` from step 3, inspect
`proposal.json` by hand for correct Discogs matches and correct
naming/tagging per manifesto §5.

**5. Editing UI round-trip** — [07](07-editing-ui-module.md). Open that
sample's `proposal.json` in the browser, make a manual correction, save, and
confirm it round-trips correctly before trusting it on a larger batch.

**6. Implementation, dry-run then real** — [08](08-implementation-module.md).
`-WhatIf` first against the sample, inspect the intended-action log, then run
for real into a throwaway target directory. Spot-check tags, cover art,
`lossy-tracking.json`, and `apply-log.json`.

**7. Idempotency and upgrade validation** — [10](10-error-handling-and-edge-cases.md),
[09](09-lossy-lossless-tracking.md). Re-run the whole pipeline unchanged
against the same sample and confirm everything resolves to
`skip-existing-identical` with no duplicate work. Then simulate a
lossless-arrives-later case (re-import the same release from a lossless
source) and confirm the upgrade path replaces the target and updates the
ledger correctly.

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
