# As-is BR from code (Phase 2)

Status: Draft | Version: 0.1 | Last updated: 2026-10-10

This folder describes the **current** behavior of the legacy PowerShell app as business requirements
(BR), read **only** from `legacy/scripts/**`, `legacy/ui/*` and `legacy/config/settings.default.json`.
Roadmap phase 2, brief: [../../sessions/br-from-code.md](../../sessions/br-from-code.md).

Phase 1 wrote a first, independent view from the legacy docs and tests (`AS-DOC-*`,
[../as-is-from-docs/](../as-is-from-docs/README.md)). This folder is the second, independent view, read
from code alone, with no access to phase 1's output or to `legacy/README.md`/`legacy/plan/`. Phase 3
compares the two and decides every suspected defect.

## Requirement format

Decision D64 in [../../inbox/raw-notes.md](../../inbox/raw-notes.md) sets this format. It applies to
`AS-DOC-*` (Phase 1) and `AS-CODE-*` (Phase 2).

```markdown
### AS-CODE-REC-001 — <short rule title>
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:52 › Test-IsReleaseFolder

<One behavior rule, in plain words.>

Example: <concrete input> → <concrete output>.
```

- **ID**: `AS-CODE-<AREA>-NNN`. Numbers start at 001 per area. They never change and are never reused
  (doc rule 5).
- **No `Priority`.** As-is behavior is a fact, not a decision. Phase 3 sets the priorities in the to-be
  BR.
- **`Source:`** = `legacy/scripts/<file>:<line> › <function>` (or `legacy/ui/<file>:<line>` for the
  client-side review UI, or a CLI param-block/switch-case location for `12-cli.md`). Several sources are
  separated by `; `.
- **One behavior rule per ID**, with 1–3 examples. An invented example is marked
  `Example (illustration):`.
- Behavior words in the text. Function names appear only in `Source:`. UI labels, HTTP routes, CLI
  parameters and file names are user-visible behavior, so the text names them.
- Scope is **every function** in each owned module, not only the ones in its `Export-ModuleMember` list
  — most modules export only a handful of functions while the real rules live in private helpers (see
  [91-coverage.md](91-coverage.md) for the public/private breakdown).
- **Suspected defects** are listed separately, as `AS-CODE-DEF-NNN` (rule D2: describe, never fix).

## Index

| File | Area | Topic | IDs |
|---|---|---|---|
| [01-data-and-storage.md](01-data-and-storage.md) | DAT | Data home, hashing, stable key, long paths, audio-format detection, secrets, TagLibSharp loading, JSON schema validation | 38 |
| [02-text-and-naming.md](02-text-and-naming.md) | TXT | Text normalization, homoglyphs, Japanese/romanization detection, bilingual naming, title case, safe file names, truncation | 26 |
| [03-settings-and-secrets.md](03-settings-and-secrets.md) | SET | Settings get/init/set, defaults, Discogs token storage | 24 |
| [04-sessions.md](04-sessions.md) | SES | Session ID generation, create/resume/read, stage transitions | 12 |
| [05-recognition.md](05-recognition.md) | REC | Folder-type detection, cue sheets, companion files, tags, the folder-walk/recognition pipeline | 110 |
| [06-discogs-client.md](06-discogs-client.md) | DSC | Token lookup, HTTP request/retry/backoff, rate limiting, response caching | 32 |
| [07-proposal-matching.md](07-proposal-matching.md) | MAT | Search/scoring, fingerprint matching, version/master selection, match resolution | 67 |
| [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md) | PRP | Naming templates, proposed names/tracks, cover art, target comparison, the edit-proposal orchestration | 104 |
| [09-review-ui.md](09-review-ui.md) | REV | UI server HTTP API, static/local file serving, client-side review page behavior | 148 |
| [10-apply.md](10-apply.md) | APL | Apply log, ffmpeg split/resize, tag writing, path truncation, staging, the apply orchestration | 55 |
| [11-lossy-tracking.md](11-lossy-tracking.md) | LSY | Lossy ledger, status transitions | 14 |
| [12-cli.md](12-cli.md) | CLI | Every command/subcommand, parameter, exit-code behavior | 39 |
| [13-bandcamp-and-errors.md](13-bandcamp-and-errors.md) | BND, ERR | Bandcamp (plan-only, confirmed from code), cross-cutting error-handling patterns | 2 + 5 |
| [90-suspected-defects.md](90-suspected-defects.md) | DEF | Suspected defects, consolidated and renumbered flat | 34 |
| [91-coverage.md](91-coverage.md) | — | Every function in every owned module → requirement ID(s) | — |

Total: 676 requirement IDs.

## Same fact in more than one area

| Fact | Areas |
|---|---|
| Discogs rate limit defaults to 55 requests/minute, cache TTL defaults to 30 days | SET (AS-CODE-SET-014, as configured defaults from `settings.default.json`) and DSC (AS-CODE-DSC-009, AS-CODE-DSC-015, as the actual enforced behavior) |

Unlike phase 1 (where the same *rule* appeared under more than one area because each area read a
different input), phase 2 has only one source per rule, so true duplication is rare. The pair above is
the only case found: the same two numbers are stated once as "what the default is" (SET) and once as
"what the code does with it" (DSC).

The literal `1900` appears in three unrelated places (a year-range bound used in `05-recognition.md` and
`10-apply.md`, and a distinct "unresolved year" sentinel value in `08-proposal-naming-and-tags.md`,
AS-CODE-PRP-011) — these are not the same rule, just a coincidentally shared number, and are **not**
cross-linked.

## How this phase was done

- Seven subagents drafted the 13 area files in parallel, each owning a disjoint set of source files (or,
  for the 2,928-line `Reshelf.EditProposal.psm1`, a disjoint line range) so no two agents touched the
  same output file or the same source twice.
- Each subagent was explicitly barred from reading `legacy/README.md`, `legacy/plan/*`, `legacy/tests/*`,
  and anything under `../as-is-from-docs/` except that folder's own "Requirement format" section —
  independence from Phase 1 and from the legacy docs is the entire point of this phase.
- The lead session (this merge pass) read all 13 files, consolidated the suspected defects into
  [90-suspected-defects.md](90-suspected-defects.md) with flat renumbering, built
  [91-coverage.md](91-coverage.md) from every file's `Source:` line, and wrote this index.
- One minor coverage gap was found and documented rather than silently left open:
  `Get-ReshelfUiProposalContent` (in `Reshelf.UiServer.psm1`) is never cited by name in `09-review-ui.md`
  — its behavior is documented under the route-level `GetProposal`/`CurrentSession` entries instead. See
  the note in [91-coverage.md](91-coverage.md).

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-10 | Phase 2 draft: 676 `AS-CODE-*` requirements across 13 area files, 34 suspected defects, full function coverage. |
