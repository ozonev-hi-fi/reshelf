# 03 — Sessions, stages and statuses

Status: Draft | Version: 0.2 | Last updated: 2026-10-04

## Today vs next-gen

| Topic | Today (legacy) | Next-gen |
|---|---|---|
| Session | Created by `recognize`. Id `yyyy-MM-dd-NNNN`. Stage `recognized → proposed → reviewed → applied / partially-applied`. | Same creation rule, plus re-run inside a session (whole source or a subfolder) |
| Re-run | Re-running `propose` **overwrites** `proposal.json` and loses UI edits | Re-run invalidates later stages but keeps user edits (NG-SES-008) |
| Approve | Releases without flags are auto-approved. Flagged ones need Approve. | Every release needs an explicit Approve |
| Apply | Per session. `-IncludeUnresolved` applies unreviewed releases too. | Per release or per session, approved releases only |
| Statuses | UI badges `rejected / ambiguous / needsReview / ready` | Full status set (NG-SES-011) and two milestones |

## Session lifecycle

### NG-SES-001 — Every recognize creates a new session
Priority: Must | Status: Draft | Source: D24, D35, D49, D51

Every `recognize` creates a new session. That covers the CLI command and "New session" in the UI. The session belongs to one source folder. The user chooses it as described in NG-PTH-003, and the session stores it as a location (NG-PTH-001).

### NG-SES-002 — Overlap message
Priority: Should | Status: Draft | Source: D35, D51

When an **open** session already covers the same folder, or a parent or child folder, the app shows an info message: "Folder already in session X. Open it instead?" The message does not block. The user can continue and create the new session.

The app compares the stored locations (NG-PTH-001), not the drive letters. So the overlap is found even when the drive now has another letter.

### NG-SES-003 — Session management
Priority: Must | Status: Draft | Source: D10

The user can list, create, open, rename, archive and delete sessions. Delete removes only app data (DB rows and app files). It never touches music files.

### NG-SES-004 — Stages
Priority: Must | Status: Draft | Source: D10

A session runs through these stages: Recognize → Propose → Review → Apply. The UI shows them as a wizard (NG-APP-004).

### NG-SES-005 — Re-running a stage invalidates the later stages
Priority: Must | Status: Draft | Source: D10

The user can re-run any stage explicitly. Before the re-run, the app warns which later stages become invalid. After a re-run, every later stage is marked invalid and must run again. The survival rules NG-SES-008 to NG-SES-010 decide what is kept.

Example: recognize → propose → re-recognize. Propose becomes invalid and must run again. Propose is fast thanks to the provider cache (NG-PRV-012).

### NG-SES-006 — Re-recognize the whole source or a subfolder
Priority: Must | Status: Draft | Source: D35, D46

Inside a session, the user can re-run recognize for the whole source folder or for one subfolder of it. A subfolder run invalidates only the releases under that subfolder.

Example: re-recognize `<source>\ZZ Top`. Releases of other artists keep their stage and status.

### NG-SES-007 — New and missing releases after re-recognize
Priority: Must | Status: Draft | Source: D46

After a re-recognize:
- releases found for the first time are added to the session;
- releases that disappeared get the status `Source missing`. They are not deleted, and their user edits stay. The user can remove them by hand.

### NG-SES-008 — User edits survive invalidation
Priority: Must | Status: Draft | Source: D25 | Depends on: NG-LAY-004

User-layer edits stay for every source item that still exists. Edits for source items that are gone move to a visible **"dropped edits"** list on the release (or on the session, if the whole release is gone).

### NG-SES-009 — Approvals reset only for changed releases
Priority: Must | Status: Draft | Source: D25

After a re-run, an approval resets to `Ready` (or to a "needs attention" status) only when the release's recognized or proposed data changed. The approvals of unchanged releases stay.

### NG-SES-010 — Applied output becomes outdated
Priority: Must | Status: Draft | Source: D25, D58

If a release was already applied and its data changes after a re-run, its applied output stays where it is. The release gets the mark **"outdated, apply again"**.

The applied output lives in temp (NG-PTH-004). Whether "apply again" may replace it depends on NG-PTH-008.

## Release statuses

### NG-SES-011 — Release status set
Priority: Must | Status: Draft | Source: D43, D14, D46

| Group | Status | Meaning |
|---|---|---|
| Needs attention | `Error` | A stage failed for this release |
| | `Not found` | No provider found a match |
| | `Ambiguous` | Several candidates, none clearly best |
| | `Needs review` | At least one Blocking or Warning reason code (NG-REV-002) |
| | `Source missing` | The source items are gone after re-recognize (NG-SES-007) |
| Waiting | `Ready` | No open issues. Waiting for the user's Approve. |
| Decided | `Approved` | The user approved it. It can be applied. |
| | `Rejected` | The user rejected it. It is never applied. |
| Final | `Applied` | Apply finished for this release |

The default sort order of the review page is based on this table (NG-REV-003).

### NG-SES-012 — Explicit approval per release
Priority: Must | Status: Draft | Source: D15

Every release needs an explicit Approve or Reject from the user. Nothing is auto-approved. There is no bulk approve in the UI or in the CLI.

### NG-SES-013 — Apply per release
Priority: Must | Status: Draft | Source: D28, D52

The user can apply one release, several selected releases, or all approved releases of the session. Apply processes `Approved` releases only. Apply may run before the whole session is reviewed.

Example: 20 of 100 releases are approved. The user applies those 20 now and keeps researching the rest.

Apply writes only to temp, through a staging folder (NG-PTH-004, NG-PTH-007).

### NG-SES-014 — Session milestones
Priority: Must | Status: Draft | Source: D43, D59

| Milestone | Condition | Pipeline point |
|---|---|---|
| **Reviewed** | Every release is `Approved` or `Rejected` | End of the Review stage |
| **Done** | Every release is `Applied` or `Rejected` | End of the Apply stage |

There is no status or milestone for "moved from temp to the library". The user moves the folders by hand. An applied release shows a computed Location instead (NG-PTH-011).

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Initial version (Docs part A). |
| 0.2 | 2026-10-04 | Docs part B: open points of NG-SES-002, 010, 013, 014 resolved with links to doc 11. |
