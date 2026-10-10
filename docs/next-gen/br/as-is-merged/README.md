# As-is BR, merged (Phase 3)

Status: Draft | Version: 0.2 | Last updated: 2026-10-10

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
| 02-text-and-naming.md | TXT | 72 → 26 | — | Not started |
| 03-settings-and-secrets.md | SET | 47 → 24 | — | Not started |
| 04-sessions.md | SES | 23 → 12 | — | Not started |
| 05-recognition.md | REC | 93 → 110 | — | Not started |
| 06-discogs-client.md | DSC | 26 → 32 | — | Not started |
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
