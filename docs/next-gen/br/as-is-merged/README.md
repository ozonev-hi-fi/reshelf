# As-is BR, merged (Phase 3)

Status: Draft | Version: 0.7 | Last updated: 2026-10-11

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
| 07-proposal-matching.md | MAT | 59 → 67 | — | Not started |
| 08-proposal-naming-and-tags.md | PRP | 78 → 104 | — | Not started |
| 09-review-ui.md | REV | 84 → 148 | — | Not started |
| 10-apply.md | APL | 71 → 55 | — | Not started |
| 11-lossy-tracking.md | LSY | 32 → 14 | — | Not started |
| 12-cli.md | CLI | 46 → 39 | — | Not started |
| 13-bandcamp-and-errors.md | BND, ERR | 2+14 → 2+5 | — | Not started |
| [90-contradictions-resolution.md](90-contradictions-resolution.md) | — | — | — | In progress |
| [91-suspected-defects-carryforward.md](91-suspected-defects-carryforward.md) | — | — | — | In progress |
| [92-coverage.md](92-coverage.md) | — | — | — | In progress |

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
