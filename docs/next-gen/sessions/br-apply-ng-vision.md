# Brief — Phase 4: apply the NG vision to the merged as-is BR

Status: Draft | Version: 0.5 | Last updated: 2026-11-04

Roadmap phase: 4 | Output: `docs/next-gen/br/to-be/`, status Agreed

## Goal

Apply the NG vision (delta docs 01-11, decisions D1-D67+) onto the reconciled as-is BR
(`br/as-is-merged/`, phase 3's output) to produce the to-be BR, then validate it item by item
before marking it Agreed.

This phase has two parts, each run across many sessions:
- **Part 1 — Draft**: decide every suspected defect's disposition, apply the NG delta, write `br/to-be/`.
- **Part 2 — Validation**: walk through every to-be requirement one at a time with the user, confirm
  it is correct and nothing is missing, then mark `br/to-be/` Agreed and archive the as-is docs.

Phase 3 ([br-as-is-merge.md](br-as-is-merge.md)) only established facts about the legacy app's
current behavior; it did not decide anything about the new app. This phase is where forward design
decisions get made.

## Rules for every session in this phase

- Claude never runs `git add`/`commit`/`push`. Print the exact commands for the user to run.
- Every new decision (keep/fix/drop a defect, resolve an open point, or any process change) gets
  the next free `D` number in [../inbox/raw-notes.md](../inbox/raw-notes.md). Point to it from the
  requirement's `Source:` line.
- Follow the doc rules in [../README.md](../README.md#doc-rules): header, changelog, index row, cross-links.
- Go one item at a time with the user.
- Never use a bare ID. Always say what it is, e.g. "AS-PRP-007 (target index is built once per
  run)", "area REC (recognition)", "D67 (phase 4 ends with a validation step)".

## Read first

- [../README.md](../README.md): the doc rules.
- `docs/next-gen/br/as-is-merged/` (phase 3 output): the reconciled `AS-<AREA>-NNN` requirements
  (841 of them, 14 areas) and the suspected-defect carry-forward list,
  `91-suspected-defects-carryforward.md` (88 items, all undecided).
- The delta docs [01](../01-vision-scope.md)–[11](../11-paths-and-devices.md) (124 `NG-*`
  requirements total).
- The decision log in [../inbox/raw-notes.md](../inbox/raw-notes.md).
- [../00-roadmap.md](../00-roadmap.md#phase-4-input-real-world-library-maps):
  `local/maps/before.library-map.json` / `local/maps/after.library-map.json` and any
  `local/matches/<run-id>/match-report.json` (+ its `.md` summary), generated via
  [tools/library-mapper](../../../tools/library-mapper/docs/00-overview.md), if present.
  Real-world before/after test cases and already-flagged suspected mistakes — not committed,
  regenerate per [`02-generating-a-map.md`](../../../tools/library-mapper/docs/02-generating-a-map.md)
  if missing or stale. **Read the match report's own caveats first** (e.g. in
  `local/matches/2026-10-14T10-56-19-691Z/match-report.md`): most `wrong-release`/`wrong-year`
  verdicts there turned out to be the matching tool's own search-algorithm noise, not real library
  defects — don't treat a verdict there as proven evidence without checking those caveats.

## Part 1 — Draft `br/to-be/`

**Start rule for every Part 1 session:** open this brief, then `br/to-be/README.md`. Continue with
the first area whose status is not Done.

### Session 0 — Setup (one commit)

Create `br/to-be/README.md` with:
- **Glossary of prefixes and area codes** (every code with its full name in words, e.g. AS =
  as-is requirement, NG = next-gen delta requirement, CF = suspected defect carried forward, TB =
  to-be requirement, D = decision; REC = recognition, MAT = Discogs proposal matching, PRP =
  proposal naming and tags, etc. for all 14+ area codes).
- **Requirement format**:
  ```markdown
  ### TB-<AREA>-NNN — <title in words>
  Priority: <Must|Should|Could|Won't> | Status: Draft | Source: AS-<AREA>-NNN (<short title>), NG-<PREFIX>-NNN (<short title>), D<n> (<short title>)

  <behavior text>

  Example: <concrete example>
  ```
  - IDs are new per area, starting at 001. The old `AS-<AREA>-NNN` ID always stays in `Source:`.
  - `Priority` uses MoSCoW, per [../README.md#requirement-format](../README.md#requirement-format).
    D64 deferred setting real priorities to this phase.
  - At least one concrete acceptance example per requirement.
- **Area status table**: one row per area file below, columns Status (Not started / In progress /
  Done) and "last done ID" (for areas split across sessions).
- **Changelog.**

Print the commit commands. Set the roadmap's phase 4 row to "In progress".

### Area sessions — one area per commit, in this order

GEN (general) → DAT (data and storage) → TXT (text and naming) → SET (settings and secrets) →
SES (sessions) → REC (recognition) → DSC (Discogs client) → MAT (proposal matching) →
PRP (proposal naming and tags) → REV (review UI) → APL (apply) → LSY (lossy tracking) →
CLI (command line) → ERR (errors; this session also drops the legacy-plan items of area BND under D69).

For each area:
1. Decide each of the area's suspected defects from `91-suspected-defects-carryforward.md`: keep,
   fix, or drop. Go one at a time with the user, using the `grilling` skill. Where
   `local/matches/<run-id>/match-report.json` exists, check its `discogsVerification` result for
   real evidence — but weigh it against the report's own caveats (see "Read first" above) before
   trusting a `wrong-release`/`wrong-year`/`typo-found` verdict at face value. Each decision gets
   the next `D` number.
2. Map each of the area's `AS-<AREA>-NNN` requirements to the NG delta requirements (01-11) that
   touch it, and apply the delta.
3. Write `br/to-be/NN-<area>.md`. Every to-be requirement links to its sources (`AS-<AREA>`,
   `NG-*`, `D<n>`). For matching-logic requirements (area MAT, and REC where relevant), use
   `local/maps/before.library-map.json` / `after.library-map.json` real release pairs to check the
   logic. An example written into a doc keeps only the public artist, album and year; the real
   folder name becomes a neutral pattern, e.g. `<artist>_<album> (<year>) [flac]` (doc rule 10, D81).
4. Update `br/to-be/README.md`'s status table. Print the commit commands.

Large areas may need more than one session: REC (recognition, 100 as-is requirements / 18
suspected defects), REV (review UI, 125 / 15), PRP (proposal naming and tags, 106 / 10). If so,
commit with status "In progress" and note the last done requirement ID.

### Open points — decide inside the owning area

| Open point | Owning area | Why (checked against the as-is docs) |
|---|---|---|
| NG-LIB-003 (incremental rescan, doc 07) | **PRP** (proposal naming and tags) | AS-PRP-007: "the target index is built once per run and shared across every artist and release" |
| NG-APP open point (long-operation progress/cancel, doc 02) | **CLI** (command line), with a back-reference from REV | CF-CLI-004: "apply is the only long-running command with no wrapping try/catch"; legacy has no progress UI at all |
| NG-PLT open point (cue-split bit-exactness, doc 10) | **APL** (apply) | AS-APL-025 ("one ffmpeg split per cue track..."), carries CF-APL-006 |

REV comes before CLI in the area order, so the REV to-be file marks the progress/cancel point as
"pending CLI" until the CLI session resolves it.

### NG-only areas — after ERR

Some NG requirements have no legacy counterpart at all. Each such group gets its own new
`br/to-be/` file, one session each. Session 0 fixed the list (D68, NG coverage scan by topic,
because the as-is docs cite no `NG-*` IDs), in this order:

`14-app-shell` (APP) → `15-data-layers` (LAY) → `16-storage-and-instances` (STO) →
`17-reference-data` (REF) → `18-platform` (PLT) → `19-paths-and-devices` (PTH).

The owner file of every NG requirement, including those applied inside the as-is areas, is in
[`br/to-be/README.md`](../br/to-be/README.md#ng--to-be-file-map). Use it in step 2 of each area
session. If an area session moves an NG ID to another file, update that table.

### Coverage — last Part 1 session

Write `br/to-be/92-coverage.md`, checked in both directions:
- every `AS-<AREA>-NNN` requirement maps to a `TB-*` requirement, or to an explicit drop with its
  `D` number;
- every `NG-*` requirement (01-11) appears as a source in at least one `TB-*` requirement.

Fix every gap found here before starting Part 2.

## Part 2 — Final validation

**Start rule for every Part 2 session:** open this brief (Part 2), then
`br/to-be/93-validation-log.md`. Continue at the first row with no verdict.

**One item = one `TB-*` requirement. Never grouped or bulk-confirmed.** With roughly 950 items
total (841 as-is-derived + up to ~124 NG-only, net of merges), this spans many sessions. Each
session commits the updated log.

**Tracker** `br/to-be/93-validation-log.md`: one row per item — ID + title | verdict (`confirmed` /
`changed` / `added` / `dropped`) | `D` number | date.

**Order:**
1. **Gap pass**, one at a time:
   - every `AS-*` requirement with no `TB-*` mapping (should be empty if Part 1's coverage check
     was done right — treat any hit as a Part 1 miss to fix first);
   - every `NG-*` requirement that appears nowhere;
   - every as-is requirement that was dropped, so the user re-confirms the drop.
2. **The three open-point decisions**, each restated in full (not by name only).
3. **Areas in file order** (same order as Part 1). Inside each area, by requirement ID.
4. **One closing question per area**: "Is anything missing for <area name, in words>?" — this is
   the exhaustiveness check.

**Per item, Claude shows the full requirement text** (with every referenced ID explained in words,
not left bare), then checks:
- **Trace**: do the `Source:` IDs actually exist, and does the to-be text match what they say?
- **Delta**: does it correctly reflect the recorded `D` decision (keep/fix/drop, or the NG delta applied)?
- **Loss**: is any as-is behavior or acceptance example missing that the source had?
- **Priority**: is `Priority` set, and does it look right?
- **Testability**: does it have at least one concrete example — a real library-map pair, for
  MAT/REC where that helps?

If every check passes, ask one yes/no question and move to the next item. If the user hesitates,
or a check fails, use the `grilling` skill approach to dig in before moving on.

**Exit — last Part 2 session:**
- every row in `93-validation-log.md` has a verdict, and the gap list from step 1 is empty;
- the user has explicitly said "Agreed";
- `br/to-be/` is set to Agreed (major version bump, per doc rule 4);
- `br/as-is-from-docs/`, `br/as-is-from-code/`, `br/as-is-merged/` move to `br/archive/`, or each
  gets a "Superseded by br/to-be/. Kept for reference only." notice;
- the roadmap's phase 4 row is set to Done, phase 5 next;
- Claude prints the commit commands.

## Done when

- Part 1: no undecided suspected defect is left, every NG requirement (01-11) appears in
  `br/to-be/`, every named open point is resolved, and `92-coverage.md` shows no gaps.
- Part 2: every `br/to-be/` requirement has a validation verdict in `93-validation-log.md`, the
  user has marked `br/to-be/` Agreed, and the legacy as-is docs are archived or marked superseded.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-10 | New brief for phase 4, split out of the former phase 3 brief (`br-merge.md`, now `br-as-is-merge.md`, scoped to reconciliation only). Covers the forward design decisions: defect disposition, NG delta application, open-point resolution, to-be BR, archiving the legacy as-is docs. |
| 0.2 | 2026-10-11 | Added `tools/library-mapper/` output (`local/maps/`, `local/matches/`) to "Read first" and to steps 2–3: real-world test cases for area 07/MAT, real evidence for suspected-defect disposition. |
| 0.3 | 2026-11-03 | Phase 4 prep (D67): split into Part 1 (draft) and Part 2 (item-by-item validation, now the only step that sets Agreed and archives). Added session-0 setup, fixed area order, open-point ownership table, NG-only area files, coverage file, to-be ID scheme (`TB-<AREA>-NNN`), resume rules, and the "no bare IDs" rule. |
| 0.4 | 2026-11-03 | Session 0 done: suspected-defect count corrected to 88 (was "~99"). NG-only section now names the six NG-only files (D68) and points to the NG → to-be file map in `br/to-be/README.md`, instead of the literal "never a `Source:`" scan rule, which matched all 115 NG IDs. |
| 0.5 | 2026-11-04 | Bandcamp cleanup: the last as-is area is now "ERR (errors)"; it also drops the legacy-plan Bandcamp items under D69. NG count 115 → 124 (D72, D73, D77, D78, D79, D80). Step 3: library-map pairs check the logic; doc examples use public names and neutral folder patterns (D81). |
