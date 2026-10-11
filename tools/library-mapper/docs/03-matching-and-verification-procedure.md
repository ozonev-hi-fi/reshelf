# Matching and verification procedure

This is a **process document for a Claude session to follow by hand**, not a
script to run and trust blindly. The matching and verification judgment calls
below are deliberately not automated — legacy's own matching logic already has
bugs, so a second script making the same kind of calls isn't assumed to be any
more reliable. Read both generated maps directly and reason about them.

This step never modifies either library and never writes anything outside
`local/`. A pair is never treated as trusted without the Discogs
re-verification (§4) having actually run for it.

## 1. Load and pre-scan

Load `local/maps/before.library-map.json` and `local/maps/after.library-map.json`
(regenerate first via [`02-generating-a-map.md`](02-generating-a-map.md) if
missing or stale). Report each map's `stats` to the user before doing anything
expensive. If either map's `errors[]` is non-empty, summarize what was
inaccessible or failed before proceeding — some releases may simply be missing
from a map because of that, not because they don't exist.

## 2. Fingerprint matching

For every release in the "before" map, look for a matching release in the
"after" map:

- **Gate**: the two releases' total track counts (summed across all disc
  folders) must match exactly. No count match → not a candidate.
- **Duration tolerance**: two tracks are considered the same track when
  `abs(durationA - durationB) <= 3` seconds.
- **Strong match**: track counts match, at least 2 tracks were compared,
  the compared tracks cover at least 2/3 of all tracks, and 100% of those
  compared are within tolerance.
- **Multi-disc releases**: compare at the whole-release level first (disc
  folder names like "CD1" vs "Disc 1" can differ before/after). When both
  sides have the same `discFolderCount`, also compare per-disc as a
  tie-breaker, and treat "same total count, different disc split" as a signal
  to flag, not a silent auto-match.
- **Uncertain track order**: if either side has any `inferredTrackOrder: true`
  track, don't assume position-by-position alignment — match tracks by
  nearest-duration instead.
- **Ties**: if more than one "after" release fits a "before" release equally
  well, break the tie using normalized artist/title text similarity. Still
  tied → record as an `ambiguousGroup`, don't guess.
- **Near-misses** (track count off by 1–2, e.g. a bonus track, or one corrupt
  file skipped): record as a `nearMissCandidate`, never auto-match. These are
  left for a later decision, not acted on now.
- **Compilations / Various Artists releases**: always flag for extra scrutiny
  in step 3 — this is where a wrong Discogs match is most likely to have
  been approved without anyone noticing.

Releases with no candidate on the other side at all go into `unmatchedBefore`
or `unmatchedAfter` and are set aside for now (per the original idea: these
may get picked up in a future legacy/next-gen run, not here).

## 3. Suspicious "after"-side signals

Before trusting any fingerprint match, check the "after" release for:

- `needsReview: true` or any `reviewReasons`
- `recognitionFlags` suggesting an uncertain automatic decision (e.g. a
  stripped artist-name prefix, a tag-based recovery for a tagless folder)
- any `cueSheets` entries (virtual-track releases are more failure-prone)
- a format/lossless mismatch between before and after that isn't explained by
  an intentional transcode
- inherited review reasons from a grouping/band-member ancestor folder

Record whichever of these apply as `suspiciousSignals` on the match.

## 4. Discogs re-verification

This is the step that actually makes a pair trustworthy, not just locally
self-consistent — a release can look perfectly clean on disk and still be the
wrong Discogs release.

**Start with a pilot batch, not a blanket policy.** Pick a handful (roughly
5–10) of the fingerprint-matched pairs from step 2 and run verification on all
of them regardless of whether they showed a suspicious signal in step 3.
Review the results with the user together, then decide — informed by what
that pilot actually finds — whether the rest of the library gets verified
pair-by-pair for every match, or only for pairs with a suspicious signal. Do
not assume either policy upfront.

For each pair being verified:

1. Check whether a legacy session artifact for that exact "after" release
   already exists under the real legacy `DataHome` (resolved from the
   contributor's own real `legacy/config/settings.json` — read-only reference,
   never modified) — e.g. `proposal.json` or `apply-log.json` naming the
   `discogsReleaseId`/`masterId` that was actually applied. If found, this is
   strictly better evidence than re-searching from scratch; record
   `source: legacy-session-artifact`.
2. Otherwise, derive a fresh search query from the "after" release's current
   on-disk `recognizedTitle`/artist/year, and issue it via legacy's own
   `legacy/scripts/common/Reshelf.Discogs.psm1` (`Invoke-DiscogsRequest`,
   `Get-DiscogsToken`) — reusing its token resolution (`discogsTokenEnvVar`),
   caching (`cacheTtlDays`), and rate limiting (`rateLimitPerMinute`), never
   reimplementing an HTTP client. Record `source: fresh-discogs-search`.
3. Compare the fetched Discogs release's title/artist/year/tracklist against
   the "after" release's actual on-disk tags and folder name. Classify any
   discrepancy as `wrong-release`, `typo-found`, or `wrong-year`; if
   everything lines up, `match-confirmed`.
4. If verification wasn't run for this pair (outside the pilot, under the
   "only suspicious" policy), record `source: skipped`, `verdict: not-checked`
   — never implicitly treat an unverified pair as trusted.

## 5. Write the output

Write `local/matches/<run-id>/match-report.json` against
[`../schemas/match-report.schema.json`](../schemas/match-report.schema.json):
`matches[]` (each with `before`/`after` release references, `fingerprint`
detail, `suspiciousSignals`, `discogsVerification`, and an `overallVerdict` of
`trusted-clean-pair` / `needs-human-attention` / `rejected`), plus
`ambiguousGroups[]`, `nearMissCandidates[]`, `unmatchedBefore[]`,
`unmatchedAfter[]`. Optionally mirror the key findings as a short
human-readable `match-report.md` alongside it.

`local/matches/<run-id>/` folders accumulate with no automatic pruning —
that's left for the user to clean up manually.
