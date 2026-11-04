# Raw notes and decision log

Status: Draft | Version: 0.11 | Last updated: 2026-11-04

This file holds:
- **Part 1**: the user's original notes, **verbatim** (word for word). This is the original source.
- **Part 2**: the decision log. D1–D48 come from the grilling session of Docs part A, D49–D63 from Docs part B, D64 from Phase 1, D65–D85 from later sessions (see the changelog). New decisions take the next free number (D86, D87, ...).

Requirements cite these entries as `Source: D<n>`, or `Source: RAW` for Part 1.

## Part 1 — Raw notes (verbatim)

The notes are split into two blocks at the "Paths twist" heading. The text itself is unchanged.

### General things and implementation plan ideas

```
# Very raw and rought ideas

## Next gen

This is the "mindstream", not a structured requirements.
Use this as points for the brainstorm session, no real implementation yet.
---
### General things

I want to rewrite the application from powershell scripts to dotnet application.

I want to to save cli functionality but in adition to it add full UI controll (web api or asp net mvc with static web site, prefer controllers rather than .MapPath(), or MAUI, I don't know). Not only UI reviewer part, but so user can navigate between stages using next and previous buttons, manage sessions, and do everything from UI without calling cli command. cli is for powerusers.
Use dotnet/skill plugin functionality for analysis, planning, and implementation.
prefer and use nuget packages rather than 3rd party tools (exe, dll, scripts, what ever), like, for example, ffmpeg.
collection of supported media files (.flac, .mp3, .m4a, .wav, .ogg, .wma, .aac, .ape) and such other things are DB stored entries, which are seeded and verified on every startup if it needed to be updated (newer version of app can support more formats, for example)

Instead of .data folder and json files use sqlite - 2 instanses in the development environment (1 for unit tests and end to end tests, 1 for developer) and 1 for published application.
sqlite files are located in `data` directory in the root application folder near executable file in published application; and in configurable directory for dev env (by default it is gitignored `data` folder in the root directory of the repository.

we assume that the current source code is source of truth, but take into account that there still could be loggical errors, bugs, and a lot of them, and many other problems.

consider the work with removable storage devices, that can "disappear", be anmount, be ejected, be changed the disk letter, etc.

UI for everything, so review page/screnn becomes separate thing. Lossy manager leaves separately, available from menu.
review page:
- order of releases is configurable - by artist, by status, by year, etc. - by default it is, status: more 'suspisious' releases first, "ready" latest
- links to Discogs (and other providers) pages. Even when there were several options keep all of them on the page, so user can change opinion after and change source.
- always leave the abbility to resync with provider again
- add field to inseart custom provider page link (once app didn't find the correct option, but user did)

don't utilize discogs and bandcamp search and match silently - show everything was found during `propose` command implementation right on the review page on UI, so user can confirm that source was right, or select other source, or force sync with other source (for example, once release is found in Discogs we don't search the release on Bandcamp since Discogs is primar source of truth, but if user wants to sync with Bandcamp, they need to have this abbility right on UI)
same for pictures - show already existing metadata picture, 'in folder' pictures, and pictures from provider (discogs, bandcamp) as separate sections.

show everything was found during the `recognize` command implementation as a folders/files tree on the review page, so user understans the 'before' structure better without visiting the release in file explorer.

save recognized, proposed, and edited by user information separately. use override flow for the final version (user's version as a top priority, then proposed version, then originally recognized one). Splitting cue into separate files is a part of the original recognition, btw.

---
### Implementation plan ideas:

move existing code to some folder inside the repo, keep it working, so user still will be able to use all the functionality. this folder will be a sort of interactive documentation for the new project.

no new features in old version.

new session: create detailed business requirements based on existing documents and test cases.

new session: read the code and create another version of business specifications.

new session: compare 2 business specifications, read everything required to clarify contraversial points, ask user questions if something is not clear. merge results in one specification.

create detailed technical specification of the future solution based on received specification, code, used tools and their agreed replacement, and code logic.

---
Make detailed plans about things above, commit, update plans with things below
---
```

### Paths twist

```
## Paths twist

I have a better idea for paths in the config file and logic around:

source: user can have different resourse folders (removable drive, memory cards, download folder, etc.), that's why we are using -SourceRoot param at the moment, but maybe some default path, that's why -SourceRoot is not required but releases will be taken from the default folder.

target: user have relatively permanent place for the music collection storing. In my case it can be on D:\ or E:\ disc and it depends on which usb port i'm using for my portable ssd, and it needs to be taken into account... for example we can have an array of paths in config, which considered as the same folder but with alternative paths.
maybe we need the disk identificator (some hardware thing, which can be detected, so once we detect the device we just use it's letter - D, or E, or another - and build paths relatevely from this letter)

temp: user can have temporary folder, some folder where they can put results of the `apply` command to verify results manually before moving them target.

source and target are read only.

in case user wants to use target directly without temp, this means target == temp.

app can't 'apply' to target, only to temp. but as it said above temp can contain the same value as target.

lossy tracker keeps relative paths, which can be added to target or temp path to find real folders and files. check target first then temp while accessing.
```

## Part 2 — Decision log

Each entry gives the final answer, a short reason, and where the decision is recorded (→). "Superseded" entries are kept for history. Follow the link to the decision that replaced them.

### Process

| ID | Decision | Reason | → |
|---|---|---|---|
| D1 | Docs part A writes the roadmap, the next-gen **delta** requirements and the session briefs. It does not write the full BR. | The planned BR sessions describe current behavior. The notes describe changes. | [00](../00-roadmap.md), [README](../README.md) |
| D2 | The as-is BR sessions describe current behavior only and mark suspected defects. To-be BR = merged as-is + delta. | Old and new behavior stay distinguishable. | [00](../00-roadmap.md) rule D2, NG-VIS-003, briefs |
| D3 | Docs go in `docs/next-gen/`. `MANIFESTO.md` stays at the root. The legacy move is Phase 0, not part of Docs part A. | The move changes script paths and needs its own verification. | [00](../00-roadmap.md), [phase-0 brief](../sessions/phase-0-legacy-move.md) |
| D4 | Each doc has a header (Status, Version), a changelog and stable requirement IDs. Claude must always update statuses, versions and links after work. | Traceability from tasks back to requirements. | [README doc rules](../README.md#doc-rules), D22 |
| D5 | Two commits = two separate Claude sessions with a clean context: Docs part A, then Docs part B (paths). Both on `develop`. | Each step starts clean. The second diff shows only the paths changes. | [00](../00-roadmap.md) |
| D9 | When NG development starts, the legacy app is fully frozen, **even for bug fixes**. From then on only the new app is used, even in alpha or beta. | A clean cut. Legacy is reference only. | [00](../00-roadmap.md) rule D9, NG-STO-009 |
| D22 | A short root `CLAUDE.md` points to `docs/next-gen/README.md`, which holds the full doc rules. | CLAUDE.md is always loaded. Keep it short. | `CLAUDE.md`, [README](../README.md) |
| D23 | This file holds the verbatim notes **and** all conclusions of this session. Part B grills paths itself. Part A marks path-dependent points as `→ Part B`. | The next grilling must know every direction agreed here. | this file, [11](../11-paths-and-devices.md) |
| D41 | Doc set: roadmap, vision, area docs, paths stub, ADR template, briefs, inbox. (Numbering → D47.) | — | [README index](../README.md#index) |
| D42 | *Order updated by D66: "merge" is split into phase 3 (merge as-is) and phase 4 (apply NG vision).* Order: A → B → Phase 0 → BR from docs → BR from code → merge → tech spec → tasks. | The BR sessions read stable `legacy/` paths. | [00](../00-roadmap.md) |
| D47 | Continuous file numbering `00`–`11`. | IDs use prefixes, so gaps are not needed. | [README index](../README.md#index) |
| — | Use the dotnet skills plugin for analysis, planning and implementation (RAW). | User's request in the notes. | [00](../00-roadmap.md) working rules, [tech-spec brief](../sessions/tech-spec.md) |
| D64 | *Phase number updated by D66: priorities and keep / fix / drop are set in phase 4, not phase 3.* As-is requirements (`AS-DOC-*`, `AS-CODE-*`) have no `Priority`. Their `Source:` names the legacy file and the test, function or section (`legacy/tests/X.Tests.ps1 › Describe`), not a `D` entry. One behavior rule per ID, with 1–3 examples. Phase 1 drafts the areas with parallel subagents, and the lead reviews and merges. | As-is behavior is a fact, not a decision. Phase 3 sets the priorities in the to-be BR. Fine-grained IDs make the keep / fix / drop decisions in Phase 3 easier. | [br/as-is-from-docs](../br/as-is-from-docs/README.md), [br-from-code brief](../sessions/br-from-code.md), [README doc rule 6](../README.md#doc-rules) |
| D66 | Phase 3 is split into "merge as-is" (factual reconciliation between AS-DOC and AS-CODE, phase 3) and "apply NG vision" (forward design decisions: defect disposition, NG delta application, to-be BR, phase 4). Legacy as-is BR docs get archived once the to-be BR is Agreed, so the tech-spec phase reads a single source. | Reconciling what currently exists and deciding what to build next are different kinds of judgment and shouldn't be grilled together. | [00](../00-roadmap.md) phase 3/4 rows, [br-as-is-merge brief](../sessions/br-as-is-merge.md), [br-apply-ng-vision brief](../sessions/br-apply-ng-vision.md) |
| D67 | Phase 4 ends with an item-by-item validation step after the draft. Only that step sets `br/to-be/` to Agreed and archives the as-is docs. To-be requirements get new IDs `TB-<AREA>-NNN`; the old `AS-<AREA>-NNN` ID stays in the `Source:` line. | Validating the draft and giving final sign-off are different kinds of care, and old IDs must stay traceable even as to-be text changes. | [00](../00-roadmap.md), [br-apply-ng-vision brief](../sessions/br-apply-ng-vision.md) |
| D68 | Phase 4 session 0: the NG coverage scan is a topic scan (which as-is area covers the same behavior?), because the as-is docs cite no `NG-*` IDs at all. Every NG requirement gets one draft owner file in `br/to-be/`. NG-only to-be files, run after BND/ERR in this order: `14-app-shell`, `15-data-layers`, `16-storage-and-instances`, `17-reference-data`, `18-platform`, `19-paths-and-devices`. | The brief's literal rule ("NG IDs that never show up as a `Source:` in an as-is file") matches all 115 IDs and gives no grouping. | [br/to-be/README](../br/to-be/README.md#ng--to-be-file-map), [br-apply-ng-vision brief](../sessions/br-apply-ng-vision.md) |
| D69 | Next-gen does not support Bandcamp at all: not as a provider, not as a search fallback, not as a custom URL. Decided by the user on 2026-10-14, written down on 2026-11-03. | Bandcamp has no official API. Scraping its public pages is the only way, and the user does not consider it viable. | NG-PRV-001, NG-PRV-007, NG-PRV-008, NG-PRV-009 (Withdrawn), [01](../01-vision-scope.md#glossary) glossary, NG-PLT-005 |
| D70 | Doc rule 6 also allows `MANIFESTO §n` as a source. A link to another requirement is not a source: it goes in `Depends on:`. | MANIFESTO is the shared source of truth for both generations, and NG-PTH-004 and NG-LIB-011 already cite it. The consistency review on 2026-11-03 found these and NG-PRV-002 (`Source: D44, NG-VIS-004`) breaking the old rule. | [README doc rule 6](../README.md#doc-rules), NG-PRV-002 |
| D81 | Doc examples use well-known public releases or invented names, never folder names, drive paths, session IDs or groupings from a contributor's own collection (new doc rule 10). The local library maps stay a test input for the matching logic; an example written into a doc keeps only the public artist, album and year, with a neutral folder pattern. Personal examples replaced in D65, NG-CFG-013 and MANIFESTO §2. The as-is docs are left as they are (archived at the end of phase 4). Decided 2026-11-04 (phase 4, area GEN). | Personal examples expose the user's collection to collaborators and reviewers, who also do not understand them. | [README doc rule 10](../README.md#doc-rules), D65, NG-CFG-013, [MANIFESTO](../../../MANIFESTO.md), [br-apply-ng-vision brief](../sessions/br-apply-ng-vision.md) |
| D82 | Doc rule 6 gets a second exception: a to-be requirement (`TB-*`) lists its origin `AS-*`, `NG-*` and `D<n>` IDs in `Source:`; `Depends on:` is for other `TB-*` requirements. Decided 2026-11-04 (phase 4, area GEN). | D70 ("a requirement is not a source") was written for NG docs and missed the to-be format of D67, where the old IDs are the real origin and the coverage check needs them. | [README doc rule 6](../README.md#doc-rules), [br/to-be/README](../br/to-be/README.md#requirement-format) |
| D83 | The legacy tool set (as-is AS-GEN-010: PowerShell, TagLibSharp, ffmpeg, plain HTML/JS, `Test-Json`, `.data/`) is dropped from the to-be BR: a requirement says what the app does, not which tool. Phase 5 researches the tools before each ADR and starts from what worked in legacy (e.g. TagLibSharp as a NuGet package), kept only if no better alternative exists. The legacy tool list is copied into the phase 5 brief, because phase 5 does not read the as-is docs. Decided 2026-11-04 (phase 4, area GEN). | Tool choice belongs to ADRs (NG-PLT-005, NG-APP-008), but the legacy experience must not be lost. | [tech-spec brief](../sessions/tech-spec.md), NG-PLT-005 |
| D84 | NG-VIS-003 (legacy code is the reference, not the truth) is a process rule, not app behavior. It gets no `TB-*` requirement; the to-be file lists it under "Process only" with this D number, and the coverage check (`92-coverage.md`) accepts that entry. Phase 4 itself applies it (keep / fix / drop of every suspected defect). Decided 2026-11-04 (phase 4, area GEN). | No code could implement it, so phase 5 could not map it to a tech-spec section. | NG-VIS-003, [br/to-be/README](../br/to-be/README.md#requirement-format) |
| D85 | To-be requirements (`TB-*`) start their behavior text with one sentence in an EARS pattern (Easy Approach to Requirements Syntax: Always "The app shall …", Event "When …", State "While …", Unwanted "If …, then …", Optional "Where …"). Details and the example follow. TB-GEN-001–012 rewritten accordingly. Simplified Technical English (ASD-STE100) was considered and not adopted as a rule. Decided 2026-11-04 (after area GEN). | Each requirement says clearly when something happens and what the app does, which helps the Part 2 validation and later tests. | [br/to-be/README](../br/to-be/README.md#requirement-format), [br/to-be/00-general.md](../br/to-be/00-general.md) |

### Platform, storage, dependencies

| ID | Decision | Reason | → |
|---|---|---|---|
| D6 | Windows-only v1. OS-specific logic sits behind interfaces, e.g. a path builder: `d:\music\here` (Windows) vs `/mnt/d/music/here` (Linux). | Keep a later port possible. | NG-PLT-001, NG-PLT-002 |
| D7 | One user, UI on localhost only, no login. CLI and UI may run at the same time, with conflict detection instead of "last save wins". | Personal tool, but two front-ends share one DB. | NG-APP-006, NG-APP-007 |
| D8 | Migrate **only** the lossy ledger. Sessions, apply log and settings start fresh. Converting absolute paths → Part B (resolved by D55). | The ledger is the only long-lived valuable data. | NG-STO-008, NG-STO-009, NG-LIB-013, D55 |
| D19 | Reference data in the DB: formats, companion kinds, ignored extensions, category folders, reason codes. Built-in rows: upsert on startup, can be disabled but not deleted. User rows: app updates never touch them. Lossy/lossless comes from the codec. Plus library-quality scenarios (→ D29, D30, D32). | Newer versions can add formats. The `.m4a`/ALAC case. | NG-CFG-009…012, NG-LIB-006 |
| D65 | WavPack (`.wv`) must be in the built-in audio-formats list, same as `.flac`/`.ape`, including the single-file + `.cue` case. | Legacy's hard-coded extension list (`legacy/scripts/common/Reshelf.Common.psm1:3`) does not include `.wv`. A real collection had 3 albums as `.wv` + `.cue` that recognize silently skips (no error, not even in `unrecognized[]`). | NG-CFG-013 |
| D20 | SQLite for structured data, binaries on disk under `data/`. Auto-migrations with a backup first. DPAPI token in the DB, env var overrides it. **Portable zip only**, no installer (maybe one day). Unit tests use no DB. Integration/e2e tests use the test DB, reset per run. | Small DB. `data/` next to the exe must be writable. | NG-STO-001…007, NG-PLT-003 |
| D21 | Every tool, NuGet or external, gets an ADR with pros and cons. The user should not need extra installs, and licenses must allow bundling. But better functionality comes first. (Exact order → D38.) | — | NG-PLT-004, NG-PLT-005 |
| D33 | Reference data: **both** (a) a startup confirmation UI for pending built-in changes and (b) draft editing of user rows with Save/Cancel. | User wants to see changes before they reach the DB. | NG-CFG-010, NG-CFG-012 |
| D34 | *Superseded by D38.* Dependency priority order "3, 4, 1, 2". | — | D38 |
| D38 | Dependency rule: 1) compare functionality; 2) if equal, prefer NuGet; 3) if a third-party tool is better, check whether the license allows bundling; 4) if not, the app checks that it is installed and asks the user to install it. | Functionality first, zero install where possible. | NG-PLT-004, NG-PLT-006 |
| D48 | The UI technology is chosen in a tech-spec ADR after analysis ("maybe it will be Blazor after all"). Candidates: Blazor, controllers + static site, MAUI. Preference: controllers over minimal APIs. | Needs real analysis. | NG-APP-008, [tech-spec brief](../sessions/tech-spec.md) |

### Sessions and statuses

| ID | Decision | Reason | → |
|---|---|---|---|
| D10 | Wizard stages Source → Recognize → Propose → Review → Apply → Done. Next runs or opens a stage. Previous only shows. Re-running a stage is explicit and invalidates all later stages, with a warning. Per-release status. Session actions: list, create, open, rename, archive, delete (app data only). Propose re-run is fast thanks to the cache. *The idea "a second recognize on the same folder updates the session" is superseded by D24.* | Full UI control of the pipeline. | NG-APP-004, NG-SES-003…005, NG-PRV-012 |
| D14 | Reason codes with severity (Blocking/Warning/Info). Status order most suspicious first. Default sort: status, artist, year. Other sorts and filters. "OK for the first iteration." (Status list refined by D43.) | Today `propose` writes only free text. | NG-REV-002…005 |
| D15 | Every release needs an explicit Approve. No auto-approve, no bulk approve, no `approve-all-ready` in the CLI. Session "approved" = all releases Approved or Rejected. | The user wants to check each release. | NG-SES-012, NG-SES-014, NG-APP-005 |
| D18 | CLI scope: settings, session list/show/create, recognize, propose, re-sync, apply, lossy. Field editing is UI-only. One shared core. | CLI for power users and batch work. | NG-APP-001, NG-APP-005 |
| D24 | Every `recognize` creates a **new** session. ("Let's not overcomplicate.") | Avoids conflicts between sessions on one folder. | NG-SES-001 |
| D25 | On invalidation: user edits kept for existing source items, gone ones go to a visible "dropped edits" list. Approvals reset only for changed releases. Applied output is marked "outdated, apply again". | Losing edits because one folder changed would hurt. | NG-SES-008…010 |
| D28 | Apply works per release. A release is finished when applied; the session is finished when every release is finished (including rejected). | Check results early. | NG-SES-013, NG-SES-014 |
| D35 | Same as D24, plus an info message (not a block) when an open session overlaps. Recognize can also be re-run on a **subfolder** of the source root. | — | NG-SES-001, NG-SES-002, NG-SES-006 |
| D39 | *Superseded by D43.* (Q39 was misunderstood: "step 2" meant Docs part B, not the pipeline stage.) | — | D43 |
| D43 | Release statuses: needs attention (`Error`, `Not found`, `Ambiguous`, `Needs review`), `Ready` (no issues, waiting for Approve), `Approved`, `Applied`, `Rejected` (+ `Source missing`, D46). Milestones: **Reviewed** = all Approved/Rejected (end of stage 3). **Done** = all Applied/Rejected (end of stage 4). | Two different "done" points. | NG-SES-011, NG-SES-014 |
| D72 | Propose runs automatically after Recognize. Setting, default on. When it is off, the user runs Propose by hand, for the whole session or for one release. Propose can also be skipped: the user may approve and apply a release straight from its recognized values. Decided 2026-11-04 (phase 4, area GEN). | Recognize alone is sometimes good enough, and the user may not want proposals at all. | NG-SES-015, NG-SES-016 |
| D74 | A stage re-run replaces only its own layer. The later layers stay in the DB and get an "outdated" mark; they are never deleted automatically. Propose runs again by D72 (auto) or by hand. User edits follow NG-SES-008. Decided 2026-11-04 (phase 4, area GEN). | The app deletes automatically only data it can rebuild cheaply. User edits cost the user's time; provider data costs network requests. | NG-SES-005 |
| D46 | Subfolder re-recognize: only the affected releases are invalidated. New releases are added. Disappeared releases become `Source missing`, kept with their edits, removable by hand. | — | NG-SES-006, NG-SES-007 |

### Data layers

| ID | Decision | Reason | → |
|---|---|---|---|
| D11 | Per-field layers `User ?? Proposed ?? Recognized` for release and track fields. Reset per field. "No override" ≠ "override to empty". Overrides stay when Proposed changes and get a "stale" mark. | The user's version always wins, but stays visible. | NG-LAY-001…003, 006…008 |
| D16 | Cue sheets become **virtual tracks** at recognize (Recognized layer). The physical split happens at apply. | Recognize stays fast and needs no extra disk space. | NG-LAY-005 |
| D26 | A user edit follows its **source item** (file or cue track), not a tracklist position. The UI shows the user value with the provider suggestion next to it ("use suggestion"). | The edit describes this audio, not a slot. | NG-LAY-004, NG-LAY-009 |
| D73 | The user can edit at any stage. When the User layer has no value yet, the edit fields are prefilled from the selected earlier layer (Recognized or Proposed). **Reset** is UI-only: it restores the values the page had when it was loaded; the DB does not change. "Go back to Recognized / Proposed" loads that layer's values into the edit page; the stored User values stay until Save, and Save replaces them. **Delete my edits** removes all User values of a release from the DB, so the effective value falls back to Proposed, then Recognized. Decided 2026-11-04 (phase 4, area GEN). Replaces the "reset a field deletes the override" part of D11. | The user may find that their saved edits were wrong and the earlier stage was right. Saving a copy of the earlier values would make a duplicate that no longer follows re-sync. | NG-LAY-006, NG-LAY-010, NG-LAY-011 |
| D27 | Releases not yet applied use the current settings. Applied releases are never changed. Applies to every setting. | No retroactive changes to the library. | NG-CFG-007 |

### Providers

| ID | Decision | Reason | → |
|---|---|---|---|
| D12 | Top 5 candidates per provider, each with a link and a score. The selection is **reversible**: today a wrong click cannot be undone. Custom URL field. Snapshots per fetched source. Re-sync always possible. Discogs primary. | No silent matching. Fix the legacy dead end. | NG-PRV-001, 003…009 |
| D32 | **Library** is a provider: names, tags and cover of the existing library copy. (Index design → D44.) | Reuse the library naming when you upgrade quality. | NG-PRV-010 |
| D37 | *Superseded by D44.* Proposal: index by provider IDs in tags. Rejected, because the app must not depend on Discogs. | — | D44 |
| D44 | Library matching: (1) a DB index from "Scan library" with a provider-independent key from tags (folder names as a fallback), plus track count, durations and audio properties; (2) after recognize, a fast DB match confirmed by track count and durations ±3 s; (3) after propose, a live check of the real library files and the proposed target path. **No-provider mode**: the app works only on names, structure and existing tags. | Discogs must not be an integral part of the app. | NG-LIB-001…005, NG-PRV-002 |
| D45 | Apply writes provider IDs as optional tags (setting, default on). They are helpful information only, never identity. | — | NG-PRV-011, NG-CFG-008 |
| D75 | Suspected defect CF-GEN-001 (legacy plan idea: links from the review UI to the provider pages; never built) — disposition **fix**: next-gen implements it, in a provider-neutral form. The candidate panel is always visible. It has one group per provider with the same columns (title, score, link, reason) and one selection across all groups. Clicking another candidate only marks it as picked and shows "Use this one"; nothing changes until the user presses it. Re-sync refreshes the candidate that is already selected. When providers are turned off on purpose, the panel shows an info message, not a warning. A new provider adds one group and needs no change in the panel, selection, re-sync, reset or apply logic. Decided 2026-11-04 (phase 4, area GEN). | Legacy shows candidates only while a match is ambiguous and hides them after one pick, so a choice cannot be changed. Protect against wrong clicks. Keep the door open for more providers. | NG-PRV-001, NG-PRV-002, NG-PRV-003, NG-PRV-004 |
| D71 | Providers can be turned off by the user even when a token exists: a global setting per provider (default on), which a session can change for itself. A provider that is down (answers with errors) is handled like "no network": the release goes on in no-provider mode with a warning, and the user can re-sync later. Decided 2026-11-04 (phase 4, area GEN). | The user may not want Discogs right now, and Discogs may be down. Both must not block the work. | NG-PRV-002 |

### Review page and pictures

| ID | Decision | Reason | → |
|---|---|---|---|
| D13 | Picture sections: embedded, in folder, per provider (selected candidate; others collapsed), manual upload. Each shows px and bytes, with a warning below the max size. Max cover dimension (default 600, longest side) is a setting, not hard-coded. It applies to new work only, not to already processed releases. | — | NG-REV-010…012, NG-CFG-002, NG-CFG-007 |
| D17 | Tree view of the source per release and per session, including unrecognized folders. A manual "mark as release" action = **Should**. | Understand the "before" structure without a file explorer. | NG-REV-007…009 |

### Library, quality, templates

| ID | Decision | Reason | → |
|---|---|---|---|
| D29 | Quality is compared to decide replacements. Mixed releases count as their lowest track. A "better" source is a replacement candidate. (Order → D36: real numbers, no tiers.) | "If the library has 24/48 and the source has 24/96, I prefer 24/96." | NG-LIB-007, NG-LIB-008 |
| D30 | Match actions: Identical → Skip (or Keep both); Lower → Skip (Overwrite, Keep both); Higher → Overwrite (Skip, Keep both); Same quality, different files → the user must choose. How Overwrite runs → Part B (resolved by D57). | — | NG-LIB-009, NG-REV-013, D57 |
| D31 | Keep-both folder template `{year} {album} [{quality}]`, configurable. **All** templates configurable, not only the release name. (Details → D40.) | — | NG-LIB-010, NG-CFG-003 |
| D80 | Tag rules (MANIFESTO §5) are built in and always on in v1 (Must). A later version makes them reference data: the user can turn a rule off, change it, or add their own (Could). v1 keeps each rule a separate unit, so this stays a small change. Decided 2026-11-04 (phase 4, area GEN). | The user likes the rules as default, but other users may want other rules. | NG-CFG-006, NG-CFG-015, [tech-spec brief](../sessions/tech-spec.md) |
| D79 | Future feature (Won't in v1): manage copies of the main library on other devices (SD card in a player, phone): compare, sync, a different quality per copy, choose what a partial copy holds, find stray files. A copy is a new root role; the main library stays read-only. v1 must not block it. Decided 2026-11-04 (phase 4, area GEN). | The user keeps a full copy on a player's SD card and a partial copy on a phone. | NG-LIB-014 |
| D36 | Comparison order: lossless > lossy, then bit depth (**bit depth beats sample rate**), then sample rate, then lossy bitrate. No "you decide" case for mixed trade-offs. | — | NG-LIB-007 |
| D40 | Templates for artist folder, release folder, track file, keep-both suffix and companion rename. Placeholders, live preview, validation. MANIFESTO naming = default templates. Tag rules stay fixed. | The user may change templates, so matching must not depend on names. | NG-CFG-003…006 |
| D77 | Placeholders are reference data in the DB. Each has a **kind** (Simple: one tag for Recognized and one field per provider for Proposed; Computed: built-in code, e.g. `{trackNumber}`, `{quality}`) and a **value type** (Text, Number, Dictionary). A new Simple placeholder is added by data only and adds an editable field to all three layers. A Dictionary placeholder stores the ID of a dictionary entry (e.g. a Genres list). On Save, a value equal to an entry after normalization (case, spaces) reuses it; a similar value asks "Did you mean …?"; a new value creates an entry. `{genre}` is not in v1. Mechanism priority: Should. Decided 2026-11-04 (phase 4, area GEN). | New placeholders such as `{genre}` should need no code change. Dictionaries avoid near-duplicate values; no silent merge, because similar names can be different values (Post-Rock vs Post-Punk). | NG-CFG-004, NG-CFG-009, NG-CFG-014 |
| D76 | The output path is **one path template made of levels**, not three fixed templates. Each level is one name template; the last level is the track file name, the level above it is the release folder. The user can add, remove and reorder levels; only the target root is fixed. Stored templates and stored paths (library index, lossy list) hold **no OS separator** (`\` or `/`): they are lists of levels, and the app joins them with the separator of the current OS. The UI shows the OS separator between levels. "Use `Path` APIs, never separator literals" is a coding rule for the tech spec. Decided 2026-11-04 (phase 4, area GEN). | Users may want another folder layout, for example an extra Genre level. A later Linux/macOS port (NG-PLT-002) must read the same stored data. Levels avoid empty levels and string parsing, and each level is validated as one folder name. | NG-CFG-003, NG-CFG-005, NG-PTH-010, [tech-spec brief](../sessions/tech-spec.md) |

### Paths and devices (Docs part B)

Grilling session of 2026-10-04, Docs part B (questions Q1–Q15 of that session).

| ID | Decision | Reason | → |
|---|---|---|---|
| D49 | One optional default source folder in settings. The UI "New session" page has an editable path field with a "Browse…" button, filled with the default. CLI `--source` overrides it. | Sources change often (download folder, SD card). A default saves typing. | NG-PTH-003 |
| D50 | A location = volume serial number + path inside the volume. The app finds the mounted volume by serial and builds the path from its current letter. Not found → `Offline` + "Re-locate" with a folder picker. | Works for any drive letter and never picks a wrong drive with the same folder name. | NG-PTH-001, NG-PTH-002 |
| D51 | Source, target and temp all use the same location model. A session stores its source as a location + relative path. | One model. The overlap message and old sessions survive a letter change. | NG-PTH-001, NG-SES-002 |
| D52 | Roles: target = read only, temp = the only place where apply writes. Target and temp may have the same **value**, but the roles stay separate. The user moves results from temp to the target by hand. A "Move to library" action is a Could. | Keeps the rule from the raw notes simple and safe for v1. | NG-PTH-004…006 |
| D53 | Temp is required. "Use the library as temp" is an explicit option, not an empty field. Temp may be inside the target; the library scan skips it. | An empty field must not silently mean "write into my library". | NG-PTH-003, NG-PTH-005 |
| D54 | The library index covers target and temp. Each entry has a root role + a relative path. If both have the release, target wins. | Without temp in the index, the app proposes the same release again and creates duplicates. | NG-PTH-010, NG-LIB-001 |
| D55 | The legacy lossy import strips the current target path, or a "legacy root" the user types in the import dialog (case-insensitive). An entry that matches no root is imported as `Path unresolved`. The lossy manager shows it, and the user can fix or delete it. | No data is lost, and the problem stays visible. | NG-STO-008, NG-LIB-013 |
| D56 | A location disappears: recognize stops and keeps the state from before the run; the library scan stops and keeps the old index; offline ≠ deleted; apply builds in a staging folder in temp and moves once, a failed release gets `Error`, leftovers are cleaned on the next start. | Never corrupt data or leave half-written output. | NG-PTH-007, NG-PTH-012, NG-PLT-007 |
| D57 | Overwrite: the app prepares, the user swaps. The new copy goes to temp, and the release shows "Replace pending". If the final name is taken (always when temp == target), the new copy gets a replacement suffix from a template. Keep both needs no special rule. | The app never deletes in the target role. | NG-PTH-009, NG-LIB-009, NG-CFG-003 |
| D58 | The app may replace a temp folder only if it wrote that folder itself (DB record) and nobody changed it since (file list, sizes, modified times). Otherwise it is foreign and the D57 suffix rule applies. | Re-apply stays easy, and manual edits in temp are never lost. | NG-PTH-008, NG-SES-010 |
| D59 | No new status after `Applied`; the Done milestone does not change. An applied release shows a computed Location: `Temp`, `Library`, `Missing` or `Offline`. It is found by relative path, target first, then temp. A renamed folder is found again by its release key after a library scan. | The move is manual and outside the app, so a stored status could become wrong. | NG-PTH-011, NG-SES-014 |
| D60 | A lossy entry becomes `upgraded` when the better copy is applied. | The user has decided, and the new copy exists. Same as legacy. | NG-LIB-011 |
| D61 | v1 has exactly one target and one temp. Several libraries are a Won't for v1. | The raw notes describe one collection on one portable SSD. | NG-PTH-003 |
| D62 | The name-length budget counts from the longer of the temp and target roots. | The release must fit in temp and after the move to the target. | NG-PTH-013 |
| D78 | Phones connected by USB (MTP devices) are not a direct source in v1: the app explains it and asks the user to copy the folder to a disk first (Must). A later version copies from the device into app-managed temporary storage; the user sees and manages that copy, and the app suggests deleting it when the session is finished (Should). Direct reading over MTP is not planned. Decided 2026-11-04 (phase 4, area GEN). | MTP devices have no drive letter or volume serial, and normal file APIs, the tag library and ffmpeg cannot open their files. Copies must not waste the user's disk space silently. | NG-PTH-014, NG-PTH-015 |
| D63 | UNC paths (`\\server\share`) are allowed for any root. They are stored as plain paths, without device identity. Offline = not reachable. | Low cost, and the offline rules still work. | NG-PTH-001, NG-PTH-002 |

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Created in Docs part A: verbatim notes + decisions D1–D48. |
| 0.2 | 2026-10-04 | Docs part B: decisions D49–D63 (paths and devices). D8 and D30 point to their resolutions. |
| 0.3 | 2026-10-05 | Phase 1: decision D64 (format of as-is requirements). |
| 0.4 | 2026-10-07 | Decision D65 (WavPack `.wv` must be a built-in audio format). |
| 0.5 | 2026-10-10 | Decision D66 (phase 3 split into "merge as-is" and "apply NG vision"). |
| 0.6 | 2026-11-03 | Decision D67 (phase 4 ends with an item-by-item validation step; to-be requirements get new `TB-<AREA>-NNN` IDs). |
| 0.7 | 2026-11-03 | Decision D68 (phase 4 session 0: NG coverage scan by topic, NG-only to-be files `14`–`19`). |
| 0.8 | 2026-11-03 | Decision D69 (no Bandcamp in next-gen, decided 2026-10-14). |
| 0.9 | 2026-11-03 | Consistency review: decision D70 (MANIFESTO allowed as a source). Update notes on D12 (Bandcamp part → D69), D42 and D64 (phase numbers → D66). Intro names D65–D70 and the next free number. |
| 0.10 | 2026-11-04 | Bandcamp cleanup: Bandcamp sentences removed from D12, and the "supersedes D12" note removed from D69. D69 is the only live mention. Decision D71 (providers can be turned off globally and per session; a provider that is down is handled like "no network"). Decisions D72 (auto-propose setting; Propose can be skipped), D73 (editing at any stage, UI-only reset, "delete my edits"), D74 (a re-run marks later layers outdated, never deletes them), D75 (suspected defect CF-GEN-001, provider page links: fix, as a provider-neutral candidate panel), D76 (path template as a list of levels; no OS separator in stored data), D77 (placeholders as reference data: kind, value type, dictionaries), D78 (phones over USB/MTP: message in v1, managed copy later), D79 (copies of the library on other devices, Won't in v1), D80 (tag rules fixed in v1, configurable later), D81 (no personal examples, doc rule 10), D82 (to-be `Source:` may list `AS-*`/`NG-*` IDs), D83 (legacy tool set dropped from to-be; phase 5 researches tools starting from legacy), D84 (NG-VIS-003 is "process only", no to-be requirement); D65 text: personal path and session ID removed. |
| 0.11 | 2026-11-04 | Decision D85 (to-be requirements use EARS). Process decisions D81–D84 moved from the templates section to the Process section. |
