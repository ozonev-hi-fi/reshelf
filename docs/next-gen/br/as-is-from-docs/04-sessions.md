# 04 — Sessions (as-is, from docs and tests)

Status: Draft | Version: 0.1 | Last updated: 2026-10-05

## Scope

Area **SES**. How the legacy app creates a session, how it names it, how a session moves through stages, and how the user lists, shows and resumes sessions.

Owned inputs: `legacy/tests/Reshelf.Settings.Tests.ps1` (Describes `New-ReshelfSessionId (private)`, `New-ReshelfSession`, `Resume-ReshelfSession`, `Get-ReshelfSession`), the session parts of `legacy/plan/04-settings-module.md`, and the `legacy/README.md` section "Sessions and resuming". The shape of `session.json` is in [01-data-home-and-storage.md](01-data-home-and-storage.md) (AS-DOC-DAT-029 to AS-DOC-DAT-032).

Suspected defects and contradictions are listed in [90-suspected-defects.md](90-suspected-defects.md): AS-DOC-DEF-017 for this area.

## Creating a session

### AS-DOC-SES-001 — Each recognize run creates a session
Status: Draft | Source: legacy/README.md › Sessions and resuming; legacy/plan/04-settings-module.md › Session persistence

Every `recognize` run creates a new session for its source root.

Example: `recognize -SourceRoot D:\downloads\incoming` → a new session `2026-09-19-0001` with `sourceRoot = D:\downloads\incoming`.

### AS-DOC-SES-002 — A session id is the date and a 4-digit counter
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › New-ReshelfSessionId (private); legacy/plan/04-settings-module.md › Session persistence

A session id has the form `yyyy-MM-dd-NNNN`: the date, then a 4-digit counter with leading zeros. The tests pass the date in; they do not show whether the app uses the local date or the UTC date.

Example: date 2026-09-19, first session → `2026-09-19-0001`.

### AS-DOC-SES-003 — The counter counts up from the sessions of the same date
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › New-ReshelfSessionId (private) › starts at 0001 for a new date and increments per existing session

The counter starts at `0001`. The app looks at the existing session folders of that date and gives the next number.

Example: folder `sessions\2026-09-19-0001` exists → next id `2026-09-19-0002`.

### AS-DOC-SES-004 — The counter restarts at 0001 on a new date
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › New-ReshelfSessionId (private) › resets to 0001 for a different date

Sessions of other dates do not count. A new date starts at `0001` again.

Example: `sessions\2026-09-19-0001` exists, date 2026-09-20 → `2026-09-20-0001`.

### AS-DOC-SES-005 — Two sessions on the same day get different ids
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › New-ReshelfSession › gives two sessions created the same day sequential ids

Two sessions created one after the other on the same day get different, sequential ids.

Example: session for `D:\source1`, then for `D:\source2` → `…-0001` and `…-0002`.

### AS-DOC-SES-006 — A new session never overwrites an existing one
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › New-ReshelfSession › retries instead of clobbering when the computed session id already exists (simulated race)

When the computed id already exists on disk (for example, two runs at the same moment), the app tries the next id. It does not touch the existing session.

Example: `sessions\2026-01-01-0001\session.json` exists with content `"sentinel"`, the first computed id is `2026-01-01-0001` → the new session gets `2026-01-01-0002`; the old file still says `"sentinel"`.

### AS-DOC-SES-007 — A new session starts at stage "recognized" with no proposal
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › New-ReshelfSession › creates the session folder and a session.json with stage recognized; legacy/plan/04-settings-module.md › Session persistence

The app creates the folder `<dataHome>\sessions\<id>\` and writes `session.json` in it. The new session has `stage = recognized` and `proposalPath = null`. It stores the source root.

Example: new session for `D:\source` → `sessions\<id>\session.json` exists, `stage = recognized`, `proposalPath = null`, `sourceRoot = D:\source`.

### AS-DOC-SES-008 — A new session.json matches the schema
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › New-ReshelfSession › produces a session.json that validates against the session schema

The `session.json` of a new session is valid against `session.schema.json`.

Example: new session for `D:\source` → `Test-Json … session.schema.json` = true.

## Stages

### AS-DOC-SES-009 — A session moves through five stages
Status: Draft | Source: legacy/README.md › Sessions and resuming; legacy/plan/04-settings-module.md › Session persistence; legacy/schemas/session.schema.json › stage

A session moves through the stages `recognized` → `proposed` → `reviewed` → `applied`. When apply does not finish every release, the stage is `partially-applied`. The stage values are in AS-DOC-DAT-031.

Example: `recognize` → `recognized`; `propose` → `proposed`; `session mark-reviewed` → `reviewed`; `apply` → `applied` or `partially-applied`.

### AS-DOC-SES-010 — Each step sets the session stage when it finishes
Status: Draft | Source: legacy/plan/04-settings-module.md › Session persistence

Every module that finishes a step sets the session stage itself. The stage setter accepts any of the five stages.

Example: `propose` finishes → it sets `stage = proposed`.

## Resuming a session

### AS-DOC-SES-011 — "session resume" shows the stage and the next command
Status: Draft | Source: legacy/README.md › Sessions and resuming; legacy/plan/04-settings-module.md › Session persistence

`session resume <id>` loads `session.json`. It prints the current stage and the suggested next command.

Example: `pwsh scripts/Reshelf.ps1 session resume 2026-09-19-0001`.

### AS-DOC-SES-012 — After "recognized" the next command is propose
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Resume-ReshelfSession › reports the next command for stage recognized

For stage `recognized`, the next command is `propose` for this session.

Example: session `2026-09-19-0001` at `recognized` → next command contains `propose` and `2026-09-19-0001`.

### AS-DOC-SES-013 — After "proposed" the next steps are the UI and mark-reviewed
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Resume-ReshelfSession › reports the next step for stage proposed

For stage `proposed`, the next step is to open the review UI (`ui start`) and then `mark-reviewed` for this session.

Example: session at `proposed` → next command contains `ui start` and `mark-reviewed … 2026-09-19-0001`.

### AS-DOC-SES-014 — After "reviewed" the next command is apply
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Resume-ReshelfSession › reports the next command for stage reviewed

For stage `reviewed`, the next command is `apply` for this session.

Example: session at `reviewed` → next command contains `apply` and the session id.

### AS-DOC-SES-015 — After "applied" the session is complete
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Resume-ReshelfSession › reports completion for stage applied

For stage `applied`, resume reports that the session is complete. There is no next command.

Example: session at `applied` → the message contains `complete`.

### AS-DOC-SES-016 — After "partially-applied" the next command is apply again
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Resume-ReshelfSession › reports the next command for stage partially-applied

For stage `partially-applied`, the next command is `apply` for this session again. What a re-run of apply does: see [10-apply.md](10-apply.md).

Example: session at `partially-applied` → next command contains `apply` and the session id.

### AS-DOC-SES-017 — Resuming an unknown session is an error
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Resume-ReshelfSession › throws for an unknown session id

When no session has the given id, resume stops with an error that says "not found".

Example: `session resume 2000-01-01-0001` on an empty data home → error "…not found…".

## Listing and showing sessions

### AS-DOC-SES-018 — "session list" shows all sessions, newest change first
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Get-ReshelfSession › returns all sessions sorted by updatedAtUtc descending; legacy/README.md › Sessions and resuming

`session list` shows all sessions as a table with id, stage, source root and updated time. The list is sorted by `updatedAtUtc`, the most recently updated first.

Example: session for `D:\source1`, then 20 ms later for `D:\source2` → the list shows the `D:\source2` session first.

### AS-DOC-SES-019 — With no sessions the list is empty
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Get-ReshelfSession › returns an empty collection when no sessions exist

When there are no sessions, the list is empty. It is not an error.

Example: new data home → 0 sessions.

### AS-DOC-SES-020 — "session show" returns one session by id
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Get-ReshelfSession › returns a single session by id; legacy/README.md › Sessions and resuming

`session show <id>` returns the full details of one session as JSON.

Example: session created for `D:\source` → `session show <id>` gives `sourceRoot = D:\source`.

### AS-DOC-SES-021 — Showing an unknown session is an error
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Get-ReshelfSession › throws for a missing session id

When no session has the given id, the app stops with an error that says "not found".

Example: `session show 2000-01-01-0001` → error "…not found…".

### AS-DOC-SES-022 — A broken session.json is an error
Status: Draft | Source: legacy/tests/Reshelf.Settings.Tests.ps1 › Get-ReshelfSession › throws a clear error when session.json fails schema validation

When `session.json` does not match its schema, reading the session is an error that says "does not match" (AS-DOC-DAT-020).

Example: `session.json` = `{"stage":"recognized"}` → error "…does not match…".

## Related rules in other areas

### AS-DOC-SES-023 — "session mark-reviewed" moves a session to "reviewed"
Status: Draft | Source: legacy/README.md › Sessions and resuming; legacy/plan/04-settings-module.md › Session persistence (CLI)

The CLI has `session mark-reviewed <id>`. The README links it to step 4 "Mark reviewed (optional)". The details: see [12-cli.md](12-cli.md) and [09-review-ui.md](09-review-ui.md).

Example: `pwsh scripts/Reshelf.ps1 session mark-reviewed 2026-09-19-0001`.

Re-running `apply` on the same session (skip applied, retry failed) and the caveat about edits made after apply: see [10-apply.md](10-apply.md).

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-05 | Phase 1 draft. |
