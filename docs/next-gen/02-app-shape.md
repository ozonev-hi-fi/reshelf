# 02 — Application shape: CLI, UI, navigation

Status: Draft | Version: 0.3 | Last updated: 2026-11-03

## Today vs next-gen

| Topic | Today (legacy) | Next-gen |
|---|---|---|
| Entry point | `pwsh scripts/Reshelf.ps1 <command>` | A .NET CLI and a local UI over one shared core |
| UI scope | Review/edit of `proposal.json`, plus the lossy list. No UI endpoint runs recognize, propose or apply. | Full control of the pipeline and sessions from the UI |
| Navigation | One page. It loads the latest session that has a proposal. | Menu with sections. A wizard with Next/Previous per session. |
| Concurrent edits | "Last save wins", no conflict detection | Conflict detection |

## Requirements

### NG-APP-001 — One core, two front-ends
Priority: Must | Status: Draft | Source: D18

The CLI and the UI call the same application core. The same operation with the same input gives the same result from either front-end.

### NG-APP-002 — The UI covers the whole pipeline
Priority: Must | Status: Draft | Source: RAW, D10

From the UI the user can do all of these, with no CLI command:
- create and manage sessions;
- run every stage (recognize, propose, review, apply);
- re-run a stage;
- manage settings, reference data and the lossy tracker.

### NG-APP-003 — Main menu
Priority: Must | Status: Draft | Source: RAW, D19, D44

The UI has a menu with these sections:

| Section | Content |
|---|---|
| Sessions | List and manage sessions (NG-SES-003), open the session wizard |
| Review | The review page of the open session ([06-review-page.md](06-review-page.md)) |
| Library | Library index and scan ([07-library-and-quality.md](07-library-and-quality.md)) |
| Lossy manager | The lossy-tracking list, a separate screen (NG-LIB-012) |
| Settings | Settings and naming templates ([08-settings-templates-refdata.md](08-settings-templates-refdata.md)) |
| Reference data | The reference-data lists (NG-CFG-009) |

### NG-APP-004 — Session wizard: Next and Previous
Priority: Must | Status: Draft | Source: D10

Each session opens as a wizard with the pages Source → Recognize → Propose → Review → Apply → Done. The four middle pages are the stages (NG-SES-004). Source and Done are wizard pages only, not stages.
- **Next** runs the next stage. If that stage already ran and is still valid, Next only opens it.
- **Previous** only *shows* the earlier stage. It never re-runs it.
- Re-running a stage is a separate, explicit action (NG-SES-005).

### NG-APP-005 — CLI scope
Priority: Must | Status: Draft | Source: D18, D15

The CLI covers pipeline and batch work:
- settings (show, set, token);
- session list, show, create;
- recognize (also on a subfolder, NG-SES-006), propose, re-sync, apply (per session or per release);
- lossy commands.

Field-level editing (titles, artists, cover choice) is UI-only. The CLI has no bulk approve (NG-SES-012).

### NG-APP-006 — Local, single user
Priority: Must | Status: Draft | Source: D7

The app serves one user on one machine. The UI listens on localhost only and has no login.

### NG-APP-007 — CLI and UI at the same time, with conflict detection
Priority: Must | Status: Draft | Source: D7

The CLI and the UI may run at the same time against the same database. When one front-end saves data that the other front-end changed after loading it, the save is refused. The user sees a clear conflict message. The user can then reload or compare. "Last save wins" is not allowed.

Example: the UI shows release X. The CLI re-syncs release X. The user then presses Save in the UI. The UI says "Release X changed since you opened it" and offers Reload.

### NG-APP-008 — UI technology is decided by an ADR
Priority: Must | Status: Draft | Source: D48, RAW

The BR stays technology-neutral: "a local UI with full control of the pipeline". The UI technology is chosen in a tech-spec ADR after analysis. Candidates: Blazor, ASP.NET with controllers + a static site, MAUI. Inputs for that ADR:
- the user prefers controllers over minimal-API `Map...` endpoints;
- the result must ship as a portable zip (NG-PLT-003).

## Open points

- Long operations (recognize over a large source, propose with many Discogs requests): should the UI show progress and allow cancel? Not discussed. → Phase 4, area CLI (command line), with a back-reference from area REV (review UI). See [br-apply-ng-vision.md](sessions/br-apply-ng-vision.md#open-points--decide-inside-the-owning-area).

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Initial version (Docs part A). |
| 0.2 | 2026-10-10 | Open point's phase pointer corrected from phase 3 to phase 4 (long-operation progress/cancel now decided in br-apply-ng-vision.md step 4). |
| 0.3 | 2026-11-03 | Consistency review: open point now points to phase 4 area CLI (the brief has no "step 4" any more). NG-APP-004 calls Source and Done wizard pages, not stages (NG-SES-004 has four stages). Menu row "Reference data" links to NG-CFG-009 instead of copying an incomplete list. |
