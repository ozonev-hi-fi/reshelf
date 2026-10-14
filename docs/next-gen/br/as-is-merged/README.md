# As-is BR, merged (Phase 3)

Status: Draft | Version: 0.14 | Last updated: 2026-10-14

This folder reconciles the two independent as-is views of the legacy app —
[br/as-is-from-docs/](../as-is-from-docs/README.md) (744 `AS-DOC-*`
requirements, from docs and tests) and
[br/as-is-from-code/](../as-is-from-code/README.md) (676 `AS-CODE-*`
requirements, from code only) — into one behavior record. Roadmap phase 3,
brief: [../../sessions/br-as-is-merge.md](../../sessions/br-as-is-merge.md).

This phase only establishes **facts about current behavior**. It does not
decide what the new app should do, and it does not touch the NG delta docs
(`01`–`11`). Those forward design decisions — applying the delta, deciding
every suspected defect's disposition, resolving NG open points, producing the
actual to-be BR — are phase 4:
[br-apply-ng-vision.md](../../sessions/br-apply-ng-vision.md).

## Requirement format

```markdown
### AS-<AREA>-NNN — <short rule title>
Status: Draft | Source: AS-DOC-REC-001; AS-CODE-REC-004

<One behavior rule, in plain words — unchanged from the sources unless a
conflict was resolved, in which case the resolution is noted here and in
90-contradictions-resolution.md.>

Example: <example from a source> → <result>.
```

- **ID**: `AS-<AREA>-NNN`. Where an `AS-DOC-<AREA>-NNN` item carries straight
  across with no conflict and no `AS-CODE` counterpart (or vice versa), it
  keeps the same `NNN` under the new prefix, so the two stay easy to compare
  by eye. Where two items merge into one, or a new split is needed, a fresh
  number is used and both original IDs are cited in `Source:`.
- **No `Priority`.** This is still a fact about current behavior, not a
  decision about the new app (that's phase 4, like `AS-DOC-*`/`AS-CODE-*`).
- **`Source:`** cites every `AS-DOC-*` and/or `AS-CODE-*` ID the rule
  reconciles, separated by `; `. An area with no code counterpart (e.g.
  `GEN`, which is narrative/framing content with nothing in the code to
  derive it from) cites `AS-DOC-*` only.
- **Auto-carried items** (both sources agree, or only one source has the
  rule and nothing contradicts it) are merged without a grilling round.
  **Conflicts** (the two sources disagree about current behavior) are
  resolved by re-reading the cited code/tests/docs; the user is asked only
  if still unclear after that check — see
  `90-contradictions-resolution.md`.
- **Suspected defects** (`AS-DOC-DEF-*` / `AS-CODE-DEF-*`, type "Suspected
  defect") are not decided here — they're consolidated, de-duplicated and
  cross-referenced in `91-suspected-defects-carryforward.md` for phase 4.
  **Contradictions** (type "Contradiction", i.e. the sources disagree about
  a fact) *are* resolved here, in `90-contradictions-resolution.md`.

## Index

| Area file | Area code(s) | AS-DOC → AS-CODE | Merged count | Status |
|---|---|---|---|---|
| [00-general.md](00-general.md) | GEN | 10 → — (no code counterpart) | 10 | Done |
| [01-data-and-storage.md](01-data-and-storage.md) | DAT | 87 → 38 | 97 | Done |
| [02-text-and-naming.md](02-text-and-naming.md) | TXT | 72 → 26 | 74 | Done |
| [03-settings-and-secrets.md](03-settings-and-secrets.md) | SET | 47 → 24 | 45 | Done |
| [04-sessions.md](04-sessions.md) | SES | 23 → 12 | 25 | Done |
| [05-recognition.md](05-recognition.md) | REC | 93 → 110 | 100 | Done |
| [06-discogs-client.md](06-discogs-client.md) | DSC | 26 → 32 | 26 | Done |
| [07-proposal-matching.md](07-proposal-matching.md) | MAT | 59 → 67 | 77 | Done |
| [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md) | PRP | 78 → 104 | 106 | Done |
| [09-review-ui.md](09-review-ui.md) | REV | 84 → 148 | 125 | Done |
| [10-apply.md](10-apply.md) | APL | 71 → 55 | 69 | Done |
| [11-lossy-tracking.md](11-lossy-tracking.md) | LSY | 32 → 14 | 22 | Done |
| [12-cli.md](12-cli.md) | CLI | 46 → 39 | 52 | Done |
| [13-bandcamp-and-errors.md](13-bandcamp-and-errors.md) | BND, ERR | 2+14 → 2+5 | 13 | Done |
| [90-contradictions-resolution.md](90-contradictions-resolution.md) | — | — | — | Done |
| [91-suspected-defects-carryforward.md](91-suspected-defects-carryforward.md) | — | — | — | Done |
| [92-coverage.md](92-coverage.md) | — | — | — | Done |

AS-DOC/AS-CODE counts per area are taken from each source's own README index
and may not line up 1:1 — the comparison works rule-by-rule, not by assuming
matching counts.

## How this phase is done

Area by area, in the order above: build an agree/only-in-docs/only-in-code/
conflict table, resolve conflicts (and existing `AS-DOC-DEF-*` contradictions
for that area) by re-reading sources, consolidate suspected defects into the
carry-forward list without deciding them, write the merged area file and
update the coverage file. See
[../../sessions/br-as-is-merge.md](../../sessions/br-as-is-merge.md) for the
full steps.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-10 | Phase 3 started. Area 00 (general) merged. |
| 0.2 | 2026-10-10 | Area 01 (data-and-storage) merged: 97 `AS-DAT-*` requirements, 1 new conflict resolved, 4 phase-1 contradictions re-verified, 5 suspected defects carried forward. |
| 0.3 | 2026-10-11 | Area 02 (text-and-naming) merged: 74 `AS-TXT-*` requirements, 1 new conflict resolved, 3 phase-1 contradictions re-verified, 3 suspected defects carried forward. `AS-CODE-TXT-014`/`015` (track-filename parsing) deferred to the REC merge pass. |
| 0.4 | 2026-10-11 | Area 03 (settings-and-secrets) merged: 45 `AS-SET-*` requirements, 3 phase-1 contradictions re-verified, 2 suspected defects carried forward. One new contradiction found and corrected in already-merged DAT content (`AS-DAT-092` wrongly said an empty secret is accepted — `AS-DOC-SET-047`/tests say it throws). `AS-DOC-SET-001`/`045`–`047` redirected to `AS-DAT-092`/`093` (not SET items); `AS-DOC-SET-044` deferred to the not-yet-merged DSC area. |
| 0.5 | 2026-10-11 | Area 04 (sessions) merged: 25 `AS-SES-*` requirements, 1 phase-1 contradiction re-verified, 2 suspected defects carried forward. One new suspected defect found while merging: listing crashes entirely on one malformed `session.json` instead of skipping it like a missing one (`CF-SES-002`). |
| 0.6 | 2026-10-11 | Area 05 (recognition) merged: 100 `AS-REC-*` requirements from 93 `AS-DOC-REC-*` + 110 `AS-CODE-REC-*` (plus the 2 `AS-CODE-TXT-*` items the TXT merge deferred here), 9 contradictions resolved, 18 suspected defects carried forward. REC's much finer code-level granularity meant most items needed a fresh, topic-organized number rather than a carried-over one — see the numbering note in `05-recognition.md`. |
| 0.7 | 2026-10-11 | Area 06 (discogs-client) merged: 26 `AS-DSC-*` requirements from 26 `AS-DOC-DSC-*` + 32 `AS-CODE-DSC-*` (plus `AS-DOC-SET-044` deferred here from SET), 2 contradictions resolved, 1 new wording contradiction found and corrected (`.env` inline-comment rule), 4 suspected defects carried forward. |
| 0.8 | 2026-10-13 | Area 07 (proposal-matching) merged: 77 `AS-MAT-*` requirements from 59 `AS-DOC-MAT-*` + 67 `AS-CODE-MAT-*`, plus 13 `AS-CODE-PRP-*` items absorbed from PRP's not-yet-merged as-is-from-code (pad width, track/number alignment, position parsing — explicitly MAT-owned per phase 1's own scope note), 6 contradictions resolved, 1 new contradiction found and corrected (string similarity is normalized Levenshtein distance, not a "token-sort ratio"), 7 suspected defects carried forward. Like REC, MAT's own granularity mismatch meant fresh topic-organized numbering rather than straight carry-over — see the numbering note in `07-proposal-matching.md`. |
| 0.9 | 2026-10-13 | Area 08 (proposal-naming-and-tags) merged: 105 `AS-PRP-*` requirements from 78 `AS-DOC-PRP-*` + 91 remaining `AS-CODE-PRP-*` (104 minus the 13 already absorbed into `AS-MAT-*`), 9 contradictions resolved (one, `AS-DOC-DEF-068`, only resolvable by reading one level above either phase-1 or phase-2's own excerpts), 1 new contradiction found and resolved as a coincidence rather than an actual disagreement (the romanized-bilingual-name-origin question, `AS-DOC-DEF-066`), 10 suspected defects carried forward. Like MAT, PRP's granularity mismatch meant fresh topic-organized numbering; several items reuse an already-merged `AS-MAT-*` rule instead of restating it — see the numbering note in `08-proposal-naming-and-tags.md`. |
| 0.10 | 2026-10-13 | Area 09 (review-ui) merged: 125 `AS-REV-*` requirements from 84 `AS-DOC-REV-*` + 148 `AS-CODE-REV-*`, 5 contradictions resolved (all in favor of the tests/README/code over stale plan-07 prose: the Discogs re-pick's live recompute, Save never re-applying folder-name safety rules, the real badge names, two independent local-file access checks, and the sessions dropdown listing every session), 15 suspected defects carried forward. Like MAT/PRP, fresh topic-organized numbering — the code view (server routing/actions/bootstrap, client bootstrap/list/detail/track/companion/cover/lossy-view) is nearly twice the size of the docs/tests view — see the numbering note in `09-review-ui.md`. |
| 0.11 | 2026-10-13 | Area 10 (apply) merged: 69 `AS-APL-*` requirements from 71 `AS-DOC-APL-*` (3 redirected to the already-merged `AS-REC-085`–`089`) + 55 `AS-CODE-APL-*`, 6 contradictions resolved (all in favor of tests/code over the README/plan-08 prose, including settling the exact default-skip gate as `humanReview.resolved` alone, and finding the plan's split-step ordering question doesn't really apply since the code has no separate split phase), 11 suspected defects carried forward (one of them new — an `apply-log` status value the code accepts but never writes). Unlike REC/MAT/PRP/REV, numbering mostly carries over from the doc side like DSC, with two multi-item folds causing it to drift from strict 1:1 partway through — see the numbering note in `10-apply.md`. |
| 0.12 | 2026-10-13 | Area 11 (lossy-tracking) merged: 22 `AS-LSY-*` requirements from 32 `AS-DOC-LSY-*` + 14 `AS-CODE-LSY-*`. No contradictions — neither source carried one for this area. 1 new suspected defect carried forward (`CF-LSY-001`: the dedicated ignore mutator leaves a stale `upgradedUtc` on an entry ignored after being upgraded, unlike the generic status setter). Four doc items redirected with no new number to already-merged items (`023`→`AS-PRP-097`, `029`→`AS-PRP-078`, `030`→`AS-APL-061`, `031`→`AS-APL-062`), the last two folded back into those items' own `Source:` lines. The propose-time half of this area's doc items largely restate ground `AS-PRP-078`–`081`/`092`/`097` already cover (that logic lives in `Reshelf.EditProposal.psm1`, PRP's code view, not LSY's) — this area's own items own only the ledger-field and `previousLossy`-schema detail PRP's items don't state. Fixed six dangling "(not yet merged)" cross-references to this file in the already-merged PRP, REV and APL files. |
| 0.13 | 2026-10-13 | Area 12 (CLI) merged: 52 `AS-CLI-*` requirements from 46 `AS-DOC-CLI-*` + 39 `AS-CODE-CLI-*`, 2 contradictions resolved (plan 11's stale 6-file UI spec list vs the real 10; plan 01's missing `ui` command vs the README/code), 7 suspected defects carried forward (`CF-CLI-001`–`007`). Two doc items redirected with no new item to already-merged `AS-SET-033`/`AS-DAT-003`–`004`; two more (`ui start`'s default port and `-NoBrowser`) dual-cited — a thin CLI dispatch item plus extending already-merged `AS-REV-032`/`033`'s own `Source:` lines. The code-only view surfaced `lossy remove`/`lossy export`, two real subcommands the doc-side command table had omitted entirely. This merge also closes out `AS-DOC-DEF-111` (Cross-cutting, "repo root" paths after the Phase 0 move), left unresolved since the DAT merge — CLI is the last of its named areas (DAT, SET, DSC, CLI), and every merged path across every area already reflects the current `legacy/`-relative layout. |
| 0.14 | 2026-10-14 | Area 13 (BND/ERR) merged — the last of the 13 numbered areas: 2 `AS-BND-*` + 11 `AS-ERR-*` requirements from 2+14 `AS-DOC-*` + 2+5 `AS-CODE-*`, one new contradiction found (the `\\?\` long-path prefix was wrongly filed as "plan only, no test" — already fully tested, merged as `AS-DAT-072`–`075`) plus 4 phase-1 contradictions resolved (staging always used final names; the localhost UI server and the in-process-TagLibSharp/single-script design are both real, MANIFESTO §8/§9 predate them), 1 suspected defect carried forward (`CF-ERR-001`, the untested full-disk-during-copy case). Eight doc items redirected to already-merged APL/PRP/DSC/REC/DAT requirements. This merge also ran a full source-id sweep across all 13 areas, which found and fixed five gaps an earlier area merge had missed: Area LSY had two uncarried phase-1 contradictions and one uncarried suspected defect (`AS-DOC-DEF-097`–`099`, now resolved/carried — see `11-lossy-tracking.md` 0.3 and `90`/`91`); `AS-CODE-APL-042` and `AS-CODE-PRP-094` were each already stated in an existing item but never cited (fixed in `10-apply.md` 0.3 and `08-proposal-naming-and-tags.md` 0.4); `AS-CODE-PRP-072` was missing entirely, added as new item `AS-PRP-106`. Every `AS-DOC-*`/`AS-CODE-*` id across all 13 areas is now traceable in `92-coverage.md`. Phase 3 content is functionally complete — what remains is the user's own review and sign-off (this file's `Agreed` status, and the roadmap's phase 3 status), not addressed here. |
