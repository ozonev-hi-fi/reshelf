# 04 — Sessions (as-is, merged)

Status: Draft | Version: 0.1 | Last updated: 2026-10-11

## Scope

Area **SES**. How the legacy app creates a session, builds its id, moves it
through stages, and how the user lists, shows and resumes sessions. Sources:
`br/as-is-from-docs/04-sessions.md` (`AS-DOC-SES-001`–`023`, from
`legacy/README.md`, `legacy/plan/04-settings-module.md`, and
`legacy/tests/Reshelf.Settings.Tests.ps1`) and
`br/as-is-from-code/04-sessions.md` (`AS-CODE-SES-001`–`012`, read only from
`legacy/scripts/common/Reshelf.Settings.psm1`).

**ID numbering for this area:** `AS-SES-001`–`023` mirror `AS-DOC-SES-001`–
`023` one for one, elaborated with the matching `AS-CODE-SES-*`
implementation detail where one exists. `AS-SES-024`–`025` are fresh numbers
for two `AS-CODE-SES-*` facts with no doc-side counterpart: the "unknown
stage" fallback in `Resume-ReshelfSession`, and listing's silent skip of
folders with no `session.json`.

**A contradiction resolved while merging this area:** `AS-DOC-DEF-017` (plan
04 vs the tests, on when a session becomes "recognized") — confirmed by the
code. See `90-contradictions-resolution.md`.

**A new suspected defect found while merging this area:** listing sessions
does not skip a folder whose `session.json` exists but fails schema
validation — it throws instead, crashing the whole `session
list`/`Get-ReshelfSession` call over one bad session. See `CF-SES-002` in
`91-suspected-defects-carryforward.md`.

## Creating a session

### AS-SES-001 — Each recognize run creates a session
Status: Draft | Source: AS-DOC-SES-001

Every `recognize` run creates a new session for its source root. How
`recognize` calls into this: area REC (not yet merged).

Example: `recognize -SourceRoot D:\downloads\incoming` → a new session
`2026-09-19-0001` with `sourceRoot = D:\downloads\incoming`.

### AS-SES-002 — A session id is the date and a 4-digit counter
Status: Draft | Source: AS-DOC-SES-002; AS-CODE-SES-001

A session id has the form `yyyy-MM-dd-NNNN`: the date part, then a 4-digit,
zero-padded counter. The date comes from the `Date` parameter, which
defaults to `Get-Date` — i.e. "now", **local time** — resolving the open
question phase 1 left about local vs UTC date.

Example: date `2026-09-19` (local), first session of the day →
`2026-09-19-0001`.

### AS-SES-003 — The counter counts up from the sessions of the same date
Status: Draft | Source: AS-DOC-SES-003; AS-CODE-SES-001

The counter is one more than the number of existing folders in
`<DataHome>/sessions` whose name starts with `<date>-`. If `sessions`
doesn't exist yet, the existing count is `0`.

Example: `sessions\2026-09-19-0001` exists → next id `2026-09-19-0002`;
three folders named `2026-10-10-*` exist → next id `2026-10-10-0004`.

### AS-SES-004 — The counter restarts at 0001 on a new date
Status: Draft | Source: AS-DOC-SES-004; AS-CODE-SES-001

Only folders matching the current date prefix are counted. A new date
starts at `0001` again.

Example: `sessions\2026-09-19-0001` exists, date `2026-09-20` →
`2026-09-20-0001`.

### AS-SES-005 — Two sessions on the same day get different ids
Status: Draft | Source: AS-DOC-SES-005; AS-CODE-SES-001

Two sessions created one after the other on the same day get different,
sequential ids — a direct consequence of AS-SES-003.

Example: session for `D:\source1`, then for `D:\source2` → `…-0001` and
`…-0002`.

### AS-SES-006 — A new session never overwrites an existing one — it retries up to 5 times, with no lock and no backoff
Status: Draft | Source: AS-DOC-SES-006; AS-CODE-SES-002, AS-CODE-SES-003

Computing a session id (AS-SES-002) does not reserve it — no lock, no file
created — so calling it twice, or from two concurrent processes, can
produce the same id. The only concurrency guard is at creation time: the
app tries `New-Item -ItemType Directory` (no `-Force`) for
`<DataHome>/sessions/<candidateId>`; that call fails if the folder already
exists, so on failure the app silently computes a fresh candidate id and
retries — up to 5 attempts, with no delay between them. After 5 failures it
throws: `Could not allocate a new session id after 5 attempts (concurrent
session creation?).` The existing session is never touched.

Example: `sessions\2026-01-01-0001\session.json` exists with content
`"sentinel"`, the first computed id is `2026-01-01-0001` → the new session
gets `2026-01-01-0002`; the old file still says `"sentinel"`.

### AS-SES-007 — A new session starts at stage "recognized" with no proposal
Status: Draft | Source: AS-DOC-SES-007; AS-CODE-SES-004, AS-CODE-SES-005

`SourceRoot` is mandatory (no default). `RecognitionPath`, if not supplied,
defaults to `<sessionDir>/recognition.json`. The app creates the folder
`<DataHome>\sessions\<id>\` and writes `session.json` in it, with `stage =
"recognized"` (hardcoded), `proposalPath = null`, `createdAtUtc` and
`updatedAtUtc` set to the exact same UTC timestamp
(`yyyy-MM-ddTHH:mm:ss.fffZ`).

Example: new session for `D:\source` at `2026-10-10T14:32:07.512Z` → `{
sessionId: "2026-10-10-0001", sourceRoot: "D:\Incoming", createdAtUtc:
"2026-10-10T14:32:07.512Z", updatedAtUtc: "2026-10-10T14:32:07.512Z",
stage: "recognized", recognitionPath: "<sessionDir>\recognition.json",
proposalPath: null }`.

### AS-SES-008 — A new session.json matches the schema
Status: Draft | Source: AS-DOC-SES-008

The `session.json` of a new session is written through the same
schema-validated save path as every other JSON document (schema mechanics
are DAT-owned). It validates against `session.schema.json`.

Example: new session for `D:\source` → `Test-Json … session.schema.json` =
true.

## Stages

### AS-SES-009 — A session moves through five stages; "recognized" is set at creation, not when recognition finishes
Status: Draft | Source: AS-DOC-SES-009; AS-CODE-SES-005, AS-CODE-SES-010

A session moves through the stages `recognized` → `proposed` → `reviewed` →
`applied`. When apply does not finish every release, the stage is
`partially-applied`. `Set-ReshelfSessionStage` only validates that the
requested value is one of these five (`[ValidateSet(...)]`) — it does not
check the session's current stage at all, so any of the five can be set
from any current stage.

A session reaches `recognized` the instant it is created (AS-SES-007), not
"once recognition finishes" — resolving `AS-DOC-DEF-017` (plan 04 said the
latter; the tests and the code agree on the former). There is no stage for
"recognition running" or "recognition failed": a session whose recognition
step crashed or was interrupted is indistinguishable, by stage alone, from
one that finished recognizing cleanly. See `AS-DOC-DEF-104` (area CLI, not
yet merged) for the resulting orphan-session scenario.

Example: `recognize` → `recognized` (as soon as the session folder is
created, before recognition itself runs); `propose` → `proposed`; `session
mark-reviewed` → `reviewed`; `apply` → `applied` or `partially-applied`.

### AS-SES-010 — Every stage change refreshes updatedAtUtc and is schema-validated; proposalPath is touched only if explicitly passed
Status: Draft | Source: AS-DOC-SES-010; AS-CODE-SES-011, AS-CODE-SES-012

Every module that finishes a step sets the session stage itself, through
`Set-ReshelfSessionStage`. Every call refreshes `updatedAtUtc` to the
current UTC time, regardless of which stage is set, and writes the session
back through the same schema-validated save path used at creation
(AS-SES-008). `proposalPath` is updated only if the caller explicitly
passes the `ProposalPath` parameter (checked via bound-parameters, so an
explicit empty string does overwrite it) — omitting it entirely leaves the
existing value untouched.

Example: `propose` finishes → it sets `stage = proposed`, `updatedAtUtc`
refreshed, `proposalPath` set to the new proposal file.

## Resuming a session

### AS-SES-011 — "session resume" shows the stage and the next command, without changing the session
Status: Draft | Source: AS-DOC-SES-011; AS-CODE-SES-009

`session resume <id>` loads `session.json` (AS-SES-017/022 for the "not
found"/schema-validation failure modes) and maps the stored stage to
exactly one fixed "next command" string, with no other computation and no
write — resuming never modifies the stored session.

Example: `pwsh scripts/Reshelf.ps1 session resume 2026-09-19-0001`.

### AS-SES-012 — After "recognized" the next command is propose
Status: Draft | Source: AS-DOC-SES-012; AS-CODE-SES-009

For stage `recognized`, the next command is exactly `Reshelf.ps1 propose
-SessionId <id>`.

Example: session `2026-09-19-0001` at `recognized` → next command
`Reshelf.ps1 propose -SessionId 2026-09-19-0001`.

### AS-SES-013 — After "proposed" the next steps are the UI and mark-reviewed
Status: Draft | Source: AS-DOC-SES-013; AS-CODE-SES-009

For stage `proposed`, the next command is exactly `Reshelf.ps1 ui start,
review the proposal in the browser, then Reshelf.ps1 session
mark-reviewed -SessionId <id>`.

Example: session at `proposed` → next command contains `ui start` and
`mark-reviewed -SessionId 2026-09-19-0001`.

### AS-SES-014 — After "reviewed" the next command is apply
Status: Draft | Source: AS-DOC-SES-014; AS-CODE-SES-009

For stage `reviewed`, the next command is exactly `Reshelf.ps1 apply
-SessionId <id>`.

Example: session at `reviewed` → next command `Reshelf.ps1 apply
-SessionId 2026-09-19-0001`.

### AS-SES-015 — After "applied" the session is complete
Status: Draft | Source: AS-DOC-SES-015; AS-CODE-SES-009

For stage `applied`, the next command is the fixed string `Nothing -
session complete.` — there is no next command.

Example: session at `applied` → next command `Nothing - session
complete.`.

### AS-SES-016 — After "partially-applied" the next command is apply again
Status: Draft | Source: AS-DOC-SES-016; AS-CODE-SES-009

For stage `partially-applied`, the next command is exactly `Reshelf.ps1
apply -SessionId <id>` — identical to `reviewed`. What a re-run of apply
does: see [10-apply.md](10-apply.md) (not yet merged).

Example: session at `partially-applied` → next command `Reshelf.ps1 apply
-SessionId 2026-09-19-0001`.

### AS-SES-017 — Resuming an unknown session is an error
Status: Draft | Source: AS-DOC-SES-017; AS-CODE-SES-007

When `<DataHome>/sessions/<id>/session.json` does not exist, resume (via
the shared session lookup) throws `Session '<id>' not found.`

Example: `session resume 2000-01-01-0001` on an empty data home → error
"…not found…".

## Listing and showing sessions

### AS-SES-018 — "session list" shows all sessions, newest change first
Status: Draft | Source: AS-DOC-SES-018; AS-CODE-SES-008

`session list` shows all sessions as a table with id, stage, source root
and updated time, sorted by `updatedAtUtc` descending (most recently
updated first), regardless of folder name or creation order.

Example: session for `D:\source1`, then 20 ms later for `D:\source2` → the
list shows the `D:\source2` session first.

### AS-SES-019 — With no sessions the list is empty
Status: Draft | Source: AS-DOC-SES-019; AS-CODE-SES-007

When the `sessions` folder doesn't exist at all, the list is an empty
array — not an error.

Example: new data home → 0 sessions.

### AS-SES-020 — "session show" returns one session by id
Status: Draft | Source: AS-DOC-SES-020; AS-CODE-SES-007

`session show <id>` requires an exact folder match:
`<DataHome>/sessions/<id>/session.json` must exist. If it does, the parsed,
schema-validated session is returned in full.

Example: session created for `D:\source` → `session show <id>` gives
`sourceRoot = D:\source`.

### AS-SES-021 — Showing an unknown session is an error
Status: Draft | Source: AS-DOC-SES-021; AS-CODE-SES-007

Same lookup as AS-SES-017/020: when no session has the given id, the app
throws `Session '<id>' not found.`

Example: `session show 2000-01-01-0001` → error "…not found…".

### AS-SES-022 — A broken session.json is an error — when looked up by id
Status: Draft | Source: AS-DOC-SES-022; AS-CODE-SES-006

Any time a `session.json` is read, it is first validated against the
`session` schema; a failure throws `Session file at '<path>' does not
match the session schema.`, with no attempt to parse or auto-repair it.
The test behind `AS-DOC-SES-022` exercises lookup by id (`session
show`/`resume`), not listing — see AS-SES-025 for how listing actually
behaves when a `session.json` is malformed instead of simply missing.

Example: `session.json` = `{"stage":"recognized"}` (fails schema) →
`session show <id>` throws "…does not match…".

## Related rules in other areas

### AS-SES-023 — "session mark-reviewed" moves a session to "reviewed"
Status: Draft | Source: AS-DOC-SES-023

The CLI has `session mark-reviewed <id>`, which calls the same
stage-setting mechanism as any other step (AS-SES-010). The README links
it to step 4, "Mark reviewed (optional)". The CLI/UI details: see areas
CLI and REV (not yet merged).

Example: `pwsh scripts/Reshelf.ps1 session mark-reviewed
2026-09-19-0001`.

## Code-only facts

### AS-SES-024 — Resuming a session with an unrecognized stage value throws
Status: Draft | Source: AS-CODE-SES-009

`Resume-ReshelfSession`'s stage-to-command mapping (AS-SES-012–016) is
exhaustive only over the five valid stages. Any other stored `stage` value
throws `Unknown session stage '<stage>' for session '<id>'.` This cannot
happen through the app's own writers (AS-SES-009 restricts
`Set-ReshelfSessionStage` to the same five values), but the schema and the
`ValidateSet` are maintained independently, so nothing structurally ties
them together.

### AS-SES-025 — Listing silently skips a session folder with no session.json — but not one with a malformed one
Status: Draft | Source: AS-CODE-SES-007

When listing all sessions (no id given), every subfolder of `sessions` is
scanned; a subfolder with no `session.json` file at all is silently
skipped — no error, no listing entry. This is not the same path as
AS-SES-022: a subfolder that *does* have a `session.json`, but one that
fails schema validation, is not skipped — reading it throws, and that
exception propagates out of the whole listing call. See `CF-SES-002` in
`91-suspected-defects-carryforward.md`: one malformed session can make
`session list` fail entirely, with no indication of which session is the
problem.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-11 | Phase 3: merged 23 `AS-DOC-SES-*` requirements and 12 `AS-CODE-SES-*` facts into `AS-SES-001`–`025`. One phase-1 contradiction (`AS-DOC-DEF-017`) re-verified against the code and confirmed. One suspected defect carried forward from code (`AS-CODE-DEF-007` → `CF-SES-001`). One new suspected defect found while merging (`CF-SES-002`: listing fails entirely on one malformed `session.json`, rather than skipping it like a missing one). |
