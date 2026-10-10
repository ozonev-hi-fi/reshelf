# Sessions — as-is from code

Status: Draft | Version: 0.1 | Last updated: 2026-10-10

### AS-CODE-SES-001 — Session IDs are `<date>-<sequence>`, sequence counted from existing folders
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:14 › New-ReshelfSessionId

A session ID is built as `yyyy-MM-dd-NNNN`: the date part comes from the `Date` parameter (defaults to `Get-Date`, i.e. "now", local time, if not supplied), and the 4-digit, zero-padded sequence part is one more than the number of existing folders in `<DataHome>/sessions` whose name starts with `<date>-`. If the `sessions` folder doesn't exist yet, the existing count is treated as `0`.

Example: with no sessions yet today, the first ID generated for `2026-10-10` is `2026-10-10-0001`. If three folders named `2026-10-10-*` already exist, the next generated ID is `2026-10-10-0004`.

### AS-CODE-SES-002 — ID generation itself does not reserve the ID (no lock)
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:14 › New-ReshelfSessionId

`New-ReshelfSessionId` only counts and computes — it does not create any folder or file, so calling it twice in a row (or from two concurrent processes) can return the same ID. Collision handling is left entirely to the caller (`New-ReshelfSession`, AS-CODE-SES-003).

### AS-CODE-SES-003 — A new session is created by racing directory creation, retried up to 5 times
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:253 › New-ReshelfSession

To create a session, the app generates a candidate ID (AS-CODE-SES-001), then tries `New-Item -ItemType Directory` for `<DataHome>/sessions/<candidateId>` without `-Force`. Directory creation fails if the folder already exists, which the code relies on as its only concurrency guard. On failure it silently retries (new candidate ID, since the failed-but-pre-existing folder is now counted). After 5 failed attempts it throws: `Could not allocate a new session id after 5 attempts (concurrent session creation?).` There is no delay/backoff between attempts.

### AS-CODE-SES-004 — `SourceRoot` is mandatory; `RecognitionPath` defaults inside the new session folder
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:253 › New-ReshelfSession

`SourceRoot` must be supplied by the caller (no default). If `RecognitionPath` is not supplied, it defaults to `<sessionDir>/recognition.json` (i.e. a file alongside the session's own `session.json`, inside the newly allocated session folder).

### AS-CODE-SES-005 — New sessions always start in stage `recognized`, with matching created/updated timestamps
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:253 › New-ReshelfSession

A freshly created session record has: `stage = "recognized"` (hardcoded, not configurable), `createdAtUtc` and `updatedAtUtc` set to the exact same UTC timestamp at creation time, formatted as `yyyy-MM-ddTHH:mm:ss.fffZ`, and `proposalPath = null`. The record is written to `<sessionDir>/session.json` under the `session` JSON schema, then returned to the caller.

Example (illustration): creating a session at `2026-10-10T14:32:07.512Z` with `SourceRoot = "D:\Incoming"` produces `{ sessionId: "2026-10-10-0001", sourceRoot: "D:\Incoming", createdAtUtc: "2026-10-10T14:32:07.512Z", updatedAtUtc: "2026-10-10T14:32:07.512Z", stage: "recognized", recognitionPath: "<sessionDir>\recognition.json", proposalPath: null }`.

### AS-CODE-SES-006 — Session files are schema-validated on every read, with no auto-repair
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:310 › Read-ReshelfSessionFile

Any time a `session.json` is read, it is first validated against the `session` JSON schema. If it fails, the app throws `Session file at '<path>' does not match the session schema.` and does not attempt to parse or fix it. This check runs on every call that reads a session file — both looking up one session by ID and listing all sessions (AS-CODE-SES-007).

### AS-CODE-SES-007 — Looking up a session by ID requires an exact folder match; listing silently skips malformed/incomplete folders
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:325 › Get-ReshelfSession

With a `SessionId` given: if `<DataHome>/sessions/<SessionId>/session.json` does not exist, it throws `Session '<id>' not found.`; otherwise it returns the parsed, schema-validated session. Without a `SessionId`: if the `sessions` folder itself doesn't exist, an empty array is returned (not an error); otherwise every subfolder of `sessions` is scanned, and any subfolder that has no `session.json` file is silently skipped (no error, no listing entry) rather than being reported as broken.

### AS-CODE-SES-008 — Listing all sessions sorts by last-updated, most recent first
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:325 › Get-ReshelfSession

When no `SessionId` is given, the returned sessions are sorted by `updatedAtUtc` in descending order (most recently updated session first), regardless of folder name / creation order.

### AS-CODE-SES-009 — Resuming a session maps the stored stage to one fixed "next command" string
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:362 › Resume-ReshelfSession

`Resume-ReshelfSession` loads the session (AS-CODE-SES-007/006, including its "not found" and schema-validation failure modes) and maps `stage` to exactly one suggested next command, with no other computation:

| Stage | Suggested next command |
|---|---|
| `recognized` | `Reshelf.ps1 propose -SessionId <id>` |
| `proposed` | `Reshelf.ps1 ui start, review the proposal in the browser, then Reshelf.ps1 session mark-reviewed -SessionId <id>` |
| `reviewed` | `Reshelf.ps1 apply -SessionId <id>` |
| `applied` | `Nothing - session complete.` |
| `partially-applied` | `Reshelf.ps1 apply -SessionId <id>` (identical suggestion to `reviewed`) |
| anything else | throws `Unknown session stage '<stage>' for session '<id>'.` |

The function returns `{ SessionId, Stage, NextCommand }` — it never modifies the stored session.

### AS-CODE-SES-010 — Stage changes are restricted to five known literal values, but not to any particular order
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:390 › Set-ReshelfSessionStage

`Set-ReshelfSessionStage` only accepts `Stage` values from the fixed set `recognized`, `proposed`, `reviewed`, `applied`, `partially-applied` (enforced by `[ValidateSet(...)]`). Beyond that membership check, the function does not look at the session's current stage at all before overwriting it — any of the five values can be set from any current stage (e.g. nothing stops moving an `applied` session back to `recognized`).

### AS-CODE-SES-011 — `ProposalPath` is only touched when the caller explicitly passes it
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:390 › Set-ReshelfSessionStage

The session's `proposalPath` field is updated only if the `ProposalPath` parameter was explicitly bound by the caller (checked via `$PSBoundParameters.ContainsKey('ProposalPath')`), including the case of passing an explicit empty string (which does overwrite it). Omitting the parameter entirely leaves the existing `proposalPath` value untouched.

### AS-CODE-SES-012 — Every stage change refreshes `updatedAtUtc` and is schema-validated on write
Status: Draft | Source: legacy/scripts/common/Reshelf.Settings.psm1:390 › Set-ReshelfSessionStage

Regardless of which stage is set, `updatedAtUtc` is always refreshed to the current UTC time (same `yyyy-MM-ddTHH:mm:ss.fffZ` format used at creation, AS-CODE-SES-005). The updated session object is written back to `<DataHome>/sessions/<SessionId>/session.json` through `Set-ReshelfJsonFile -SchemaName session`, then returned.

## Suspected defects

- AS-CODE-DEF-SES-001 — legacy/scripts/common/Reshelf.Settings.psm1:390-421 (`Set-ReshelfSessionStage`): no validation that the requested `Stage` is a legal transition from the session's current stage. The workflow implied elsewhere in the same file (`Resume-ReshelfSession`'s stage-to-command mapping at :374-381) is clearly sequential (`recognized` → `proposed` → `reviewed` → `applied`/`partially-applied`), but nothing enforces that sequence here — a caller can set any of the 5 values on top of any current stage, including moving "backwards".

## Changelog

| Version | Date | Notes |
|---|---|---|
| 0.1 | 2026-10-10 | Phase 2 draft from code. |
