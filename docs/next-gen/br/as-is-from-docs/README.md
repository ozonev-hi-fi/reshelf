# As-is BR from docs and tests (Phase 1)

Status: Draft | Version: 0.2 | Last updated: 2026-10-10

This folder describes the **current** behavior of the legacy PowerShell app as business requirements (BR). It uses only the legacy documents and tests. Roadmap phase 1, brief: [../../sessions/br-from-docs.md](../../sessions/br-from-docs.md).

Phase 2 writes a second, independent view from the code (`AS-CODE-*`). Phase 3 compares the two, resolves contradictions, and consolidates suspected defects for phase 4 to decide.

> **Phase 2 session:** you may read the [Requirement format](#requirement-format) section of this file. Do not read anything else in this folder.

## Requirement format

Decision D64 in [../../inbox/raw-notes.md](../../inbox/raw-notes.md) sets this format. It applies to `AS-DOC-*` (Phase 1) and `AS-CODE-*` (Phase 2).

```markdown
### AS-DOC-REC-001 — <short rule title>
Status: Draft | Source: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsReleaseFolder (private); legacy/README.md › Reference: automatic folder recognition

<One behavior rule, in plain words.>

Example: <real input from a test or fixture> → <real result>.
```

- **ID**: `AS-DOC-<AREA>-NNN` (`AS-CODE-<AREA>-NNN` in Phase 2). Numbers start at 001 per area. They never change and are never reused (doc rule 5).
- **No `Priority`.** As-is behavior is a fact, not a decision. Phase 4 sets the priorities in the to-be BR.
- **`Source:`** = path from the repo root, ` › `, then the Describe / Context / test name or the doc section. Several sources are separated by `; `. Phase 2 writes `legacy/scripts/<file>:<line> › <function>`.
- **One behavior rule per ID**, with 1–3 examples. Examples come from tests and fixtures where possible. An invented example is marked `Example (illustration):`.
- Behavior words in the text. Function names appear only in `Source:`. UI labels, HTTP routes, CLI parameters and file names are user-visible behavior, so the text names them.
- `(plan only)` marks a rule that only a `legacy/plan/` file states, with no support in the tests or the README.
- **Suspected defects** and **contradictions** are listed separately, as `AS-DOC-DEF-NNN` (rule D2: describe, never fix).

## Source precedence

When sources disagree, the area file describes the higher source, and [90-suspected-defects.md](90-suspected-defects.md) records the contradiction.

1. Tests (`legacy/tests/**`, including helpers and fixtures)
2. `legacy/README.md`
3. `legacy/plan/*.md` (some plan files describe superseded designs)
4. `MANIFESTO.md`

## Index

| File | Area | Topic | IDs |
|---|---|---|---|
| [00-general.md](00-general.md) | GEN | Release as the unit, stages, tool set, cross-cutting rules, glossary | 10 |
| [01-data-home-and-storage.md](01-data-home-and-storage.md) | DAT | Data home, JSON files and schemas, stable key, hashes, audio files | 87 |
| [02-text-and-naming-rules.md](02-text-and-naming-rules.md) | TXT | Normalization, look-alike letters, Japanese, safe names, truncation, MANIFESTO naming rules | 72 |
| [03-settings-and-secrets.md](03-settings-and-secrets.md) | SET | Settings init / get / set, defaults, Discogs token protection | 47 |
| [04-sessions.md](04-sessions.md) | SES | Session ID, create, resume, stages | 23 |
| [05-recognition.md](05-recognition.md) | REC | Folder types, track names, discs, cue sheets, companion files, flags | 93 |
| [06-discogs-client.md](06-discogs-client.md) | DSC | Token lookup, HTTP requests, retries, rate limit, cache | 26 |
| [07-proposal-matching.md](07-proposal-matching.md) | MAT | Search, scoring, track alignment, versions, compilation detection | 59 |
| [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md) | PRP | Proposed names and tags, compilations, Japanese naming, covers, companions, target comparison | 78 |
| [09-review-ui.md](09-review-ui.md) | REV | UI server, HTTP API, review page, mark reviewed | 84 |
| [10-apply.md](10-apply.md) | APL | Staging, copy, tags, cue split, covers, apply log, skip rules | 71 |
| [11-lossy-tracking.md](11-lossy-tracking.md) | LSY | Lossy ledger, upgrade detection | 32 |
| [12-cli.md](12-cli.md) | CLI | Commands, parameters, exit codes, test runner | 46 |
| [13-bandcamp-and-errors.md](13-bandcamp-and-errors.md) | BND, ERR | Bandcamp fallback (plan only), error handling, open questions in the sources | 2 + 14 |
| [90-suspected-defects.md](90-suspected-defects.md) | DEF | Suspected defects and contradictions | see file |
| [91-coverage.md](91-coverage.md) | — | Every Describe block, README section, plan file, schema and MANIFESTO section → IDs | — |

Total: 744 requirement IDs.

## Same rule in more than one area

Some rules appear in two or three areas, because each area read a different input. All IDs stay, so that each input keeps its trace. The secondary IDs say "Same rule as …" and point to the primary.

| Rule | Primary | Secondary |
|---|---|---|
| An unknown year becomes the placeholder 1900 | AS-DOC-PRP-011 | AS-DOC-DAT-058, AS-DOC-REV-038 (related) |
| File number width = max(pad setting, needed digits) | AS-DOC-PRP-018 | AS-DOC-MAT-059, AS-DOC-TXT-050 |
| A "Various" release is a compilation | AS-DOC-MAT-053 | AS-DOC-PRP-041 (adds the effect), AS-DOC-TXT-064 |
| Apply marks the ledger entry `upgraded` | AS-DOC-APL-065 | AS-DOC-LSY-030 |
| Apply writes the real target path into the ledger | AS-DOC-APL-066 | AS-DOC-LSY-031 |
| `-SourceRoot` / `-SaveAsDefault` | AS-DOC-CLI-009, AS-DOC-CLI-010 | AS-DOC-SET-004 |
| A stage command runs `settings init` when settings are missing | AS-DOC-SET-033 | AS-DOC-CLI-003 |

## How this phase was done

- Six subagents drafted the area files in parallel. Each one owned a fixed set of inputs, so that each input has exactly one owner (decision D64). The lead session wrote `00-general.md`, merged the defect and coverage lists, fixed the cross-links and marked the overlaps above.
- No agent used `legacy/scripts/` or `legacy/ui/` as a source. One exception was recorded: a text search for "bandcamp" over `legacy/` returned two comment lines from two module files. The agent did not use or cite them.
- The legacy README and plan files still show paths from before the Phase 0 move (for example `scripts/Reshelf.ps1`, now `legacy/scripts/Reshelf.ps1`). The area files quote them as written. See the cross-cutting section of [90-suspected-defects.md](90-suspected-defects.md) (AS-DOC-DEF-111).

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-05 | Phase 1 draft. |
| 0.2 | 2026-10-10 | Reworded phase 3/phase 4 references to match the phase split (phase 3 reconciles facts; phase 4 decides defect disposition and priorities). |
