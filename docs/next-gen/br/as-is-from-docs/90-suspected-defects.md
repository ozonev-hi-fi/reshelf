# 90 — Suspected defects and contradictions (as-is, from docs and tests)

Status: Draft | Version: 0.2 | Last updated: 2026-10-10

## How to read this file

This file lists everything in the legacy docs and tests that looks odd. Phase 4 decides each item: keep the behavior, fix it, or drop the item. Rule D2 applies: this file describes, it never fixes. It has no next-gen ideas.

There are two types:

- **Contradiction**: two sources disagree. The area file describes the higher source. Precedence: tests > `legacy/README.md` > `legacy/plan/` > `MANIFESTO.md` (see [README.md](README.md#source-precedence)).
- **Suspected defect**: behavior that looks wrong, even if all sources agree.

Some items have a `Kind`:

- `test quality`: a test name, comment or data does not match what the test checks, or a documented rule has no test.
- `unimplemented idea`: a source describes an idea that no doc or test shows as built.
- `wording only`: the sources seem to disagree, but they agree once the wording is read closely.

`Related:` lists the requirement IDs in the area files. `Sources:` uses the same format as the area files: path, ` › `, section or test name, and line numbers where known.

## Summary

| Area | Contradictions | Suspected defects | Total | IDs |
|---|---|---|---|---|
| GEN | 0 | 1 | 1 | 001 |
| DAT | 4 | 3 | 7 | 002–008 |
| TXT | 4 | 1 | 5 | 009–013 |
| SET | 3 | 0 | 3 | 014–016 |
| SES | 1 | 0 | 1 | 017 |
| REC | 9 | 12 | 21 | 018–038 |
| DSC | 2 | 2 | 4 | 039–042 |
| MAT | 6 | 5 | 11 | 043–053 |
| PRP | 9 | 6 | 15 | 054–068 |
| REV | 5 | 9 | 14 | 069–082 |
| APL | 6 | 8 | 14 | 083–096 |
| LSY | 2 | 1 | 3 | 097–099 |
| CLI | 2 | 4 | 6 | 100–105 |
| BND | 0 | 0 | 0 | — |
| ERR | 4 | 1 | 5 | 106–110 |
| Cross-cutting | 1 | 0 | 1 | 111 |
| **Total** | **58** | **53** | **111** | |

Of the 53 suspected defects, 16 are `Kind: test quality` and 1 is `Kind: unimplemented idea`. One contradiction is `Kind: wording only`.

## GEN

### AS-DOC-DEF-001 — Links from the review UI to Discogs and Bandcamp pages
Status: Draft | Type: Suspected defect | Kind: unimplemented idea | Area: GEN | Related: —

Plan 00 lists an idea: the review UI links to the Discogs release page (when the exact pressing is known) or to the master release page, also in the "ambiguous" section, and in the same way to Bandcamp. The section says it must be cleaned up once an item is planned. No README section, plan file or test says that these links exist.

Sources: legacy/plan/00-overview.md › Rough ideas (L80–87)

## DAT

### AS-DOC-DEF-002 — Plan 03 settings.json example is missing three required keys
Status: Draft | Type: Contradiction | Area: DAT | Related: AS-DOC-DAT-026

The `settings.json` example in plan 03 has no `discogsTokenEncrypted`, `ffmpegPath` and `taglibSharpPath`. The schema requires all three. The example is not valid against the current schema. The area file follows the schema and the schema-example fixture.

Sources: legacy/plan/03-domain-model-and-json-schemas.md › settings.json (L198–213); legacy/schemas/settings.schema.json (L7–21); legacy/tests/fixtures/schema-examples/settings-example.json

### AS-DOC-DEF-003 — Plan 03 recognition example uses an old shape
Status: Draft | Type: Contradiction | Area: DAT | Related: AS-DOC-DAT-035, AS-DOC-DAT-037, AS-DOC-DAT-038, AS-DOC-DAT-040, AS-DOC-DAT-044

Plan 03 shows `"cueSheet": null` (one object or null). The schema has `cueSheets` (an array). The plan example also lacks the required release fields `editionFolderName`, `ignoredFiles`, `cueSheets` and the required track fields `existingCoverArtPath`, `cueTimestamp`, `isCueVirtualTrack`. It does not mention the optional `recognizedReleaseDate` and `recognizedReleaseType`. Plan 03 › Definition of done says its examples validate, but this one does not.

Sources: legacy/plan/03-domain-model-and-json-schemas.md › recognition.json (L30–80, L63, L85); › Definition of done (L263–264); legacy/schemas/recognition.schema.json › release (L43–58), track (L113–126); legacy/tests/fixtures/schema-examples/recognition-example.json

### AS-DOC-DEF-004 — Plan 03 lists three lossy/lossless actions, the schema has five
Status: Draft | Type: Contradiction | Area: DAT | Related: AS-DOC-DAT-052

Plan 03 says `lossyLossless.action` is `none | log-for-upgrade | replace-existing`. The schema also allows `previously-lossy-different-location` and `previously-lossy-target-missing`, and has an optional `previousLossy` block. The area file follows the schema.

Sources: legacy/plan/03-domain-model-and-json-schemas.md › proposal.json (L142); legacy/schemas/proposal.schema.json › lossyLossless (L174–202)

### AS-DOC-DEF-005 — Plan 03 does not describe optional proposal fields that the schema has
Status: Draft | Type: Contradiction | Area: DAT | Related: AS-DOC-DAT-049, AS-DOC-DAT-057

The schema has `discogsMatch.masterId`, `companionFile.include` and `companionFile.proposedFileName`. Plan 03 says it gives "the exact shape of every JSON document", field by field, but it does not mention these fields.

Sources: legacy/plan/03-domain-model-and-json-schemas.md › Purpose / scope (L5–7), › proposal.json (L101–145); legacy/schemas/proposal.schema.json (L121, L293–294)

### AS-DOC-DEF-006 — Two editions with the same artist, album and year get the same stable key
Status: Draft | Type: Suspected defect | Area: DAT | Related: AS-DOC-DAT-038, AS-DOC-DAT-054, AS-DOC-DAT-064, AS-DOC-DAT-067

The stable key uses only artist, album and year. `editionFolderName` is not an input. Plan 03 itself describes two folders that are "different physical pressings of the same album" and says the user must reject one by hand. So two real editions (for example an original and a reissue from the same year) collide on one key, while plan 03 says the key identifies "the same real-world release". AS-DOC-DEF-057 is the opposite case: one release, two keys.

Sources: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfStableKey (L205–232); legacy/plan/03-domain-model-and-json-schemas.md › stableKey — the linchpin (L18–26), › proposal.json field rules (L172–180); legacy/schemas/recognition.schema.json › editionFolderName (L76)

### AS-DOC-DEF-007 — The placeholder year 1900 is also a valid real year
Status: Draft | Type: Suspected defect | Area: DAT | Related: AS-DOC-DAT-056, AS-DOC-DAT-058, AS-DOC-DAT-061, AS-DOC-DAT-066, AS-DOC-PRP-011, AS-DOC-REV-038

For an unknown year, propose writes the placeholder `1900` (the schema minimum). `tags.year` and the lossy-tracking `year` cannot be `null`. A real recording from 1900 and an unresolved year look the same in the folder name and the tags. Plan 03 notes that target matching cannot use the folder name in this case. The README says only that `1900` means "year not fixed".

Sources: legacy/plan/03-domain-model-and-json-schemas.md › Edge cases (L244–259); legacy/schemas/proposal.schema.json › tags.year (L276); legacy/schemas/lossy-tracking.schema.json › year (L26); legacy/tests/fixtures/expected/proposal.json › Dance With Ghosts, Isidor, PULSAR OLYMP; legacy/README.md › 3. Review in the browser

### AS-DOC-DEF-008 — Companion placement is free text in the schema
Status: Draft | Type: Suspected defect | Area: DAT | Related: AS-DOC-DAT-045

Plan 03 and MANIFESTO §4.5 allow only two placements: `loose` and `nested`. The schema accepts any non-empty string for `placement`. Validation does not catch a typo.

Sources: legacy/schemas/recognition.schema.json › companionFile.placement (L158); legacy/plan/03-domain-model-and-json-schemas.md › recognition.json Notes (L94–95); MANIFESTO.md › 4.5 Companion / Extra Materials

## TXT

### AS-DOC-DEF-009 — The release type list has no "SP"
Status: Draft | Type: Contradiction | Area: TXT | Related: AS-DOC-TXT-045, AS-DOC-DAT-037

MANIFESTO §4.3 lists the release types album (LP), EP, SP, single and maxi single. The `recognizedReleaseType` enum is `album, mini-album, ep, single, maxi-single, lp`. It has no `sp`. It has `mini-album` and `lp` as separate values. The area files follow the schema.

Sources: MANIFESTO.md › 4.3 Level 2 — Release (L89–90); legacy/schemas/recognition.schema.json › recognizedReleaseType (L72–75)

### AS-DOC-DEF-010 — Tags "must match" folder and file names, but names are made safe and shortened
Status: Draft | Type: Contradiction | Area: TXT | Related: AS-DOC-TXT-059, AS-DOC-TXT-066, AS-DOC-TXT-068, AS-DOC-TXT-070, AS-DOC-TXT-071, AS-DOC-TXT-072, AS-DOC-GEN-006

MANIFESTO §5 says Artist and Album Artist match the artist folder name, Year and Album match the release folder name, and Title is the file name without `NN `. The README title section repeats the Year/Album rule. Plan 03 says tags keep the raw text and only folder and file names are made safe (`_` for invalid characters). Names can also be shortened. So a tag and its folder or file name can differ. The area file follows plan 03.

Sources: MANIFESTO.md › 5. Metadata Rules (L169–174, L194–195, L198–201); legacy/README.md › (title section) (L23–27); legacy/plan/03-domain-model-and-json-schemas.md › proposal.json field rules (L153–171); legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfTruncatedSegment (L403–440)

### AS-DOC-DEF-011 — MANIFESTO says the cue file "must be deleted", but source files are read-only
Status: Draft | Type: Contradiction | Area: TXT | Related: AS-DOC-TXT-051, AS-DOC-DAT-044

MANIFESTO §4.4 says that after the split "the `.cue` file must be deleted afterward". Plan 04 and the README say source files are always read-only (copy mode only). Plan 03 says the used cue sheet is kept out of companions and ignored files, so it is just not copied to the target. The area file describes "no cue file in the final structure".

Sources: MANIFESTO.md › 4.4 Level 3 — Media Files (L128–131); legacy/plan/04-settings-module.md › Purpose / scope (L274–277); legacy/plan/03-domain-model-and-json-schemas.md › recognition.json Notes (L89–93)

### AS-DOC-DEF-012 — The truncated segment can be longer than the limit
Status: Draft | Type: Suspected defect | Area: TXT | Related: AS-DOC-TXT-038

When the limit is smaller than prefix + suffix, the helper keeps one body character. The result is then longer than the limit: limit 5 → `01 S.flac` (9 characters). Truncation exists to stay within a path length limit.

Sources: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfTruncatedSegment › keeps at least one body character when the budget is smaller than prefix+suffix (L420–426)

### AS-DOC-DEF-013 — Plan 05 "renumbered continuously across discs" reads like the Track tag
Status: Draft | Type: Contradiction | Kind: wording only | Area: TXT | Related: AS-DOC-TXT-049, AS-DOC-TXT-058, AS-DOC-PRP-020, AS-DOC-REC-066, AS-DOC-GEN-006

Plan 05 says track numbers inside disc folders "are combined and renumbered continuously across discs" when propose builds `proposedFileName`. The README title section says "`Track` restarts at 1 on each disc". These are two different numbers, and all sources agree on both:

| Number | Rule | Sources |
|---|---|---|
| File number `NN` | zero-padded, keeps counting across discs | MANIFESTO §4.4, plan 03, plan 05, plan 06, test |
| `Track` tag | restarts at 1 on each disc, no leading zero | MANIFESTO §5, README, plan 03, plan 06, test |

Example: 2 discs with 2 tracks each → files `01`–`04`; Track tags `1, 2, 1, 2`. Only the plan 05 wording ("track numbers") is unclear.

Sources: legacy/plan/05-recognition-module.md › Track/disc parsing (L119–124); legacy/README.md › (title section) (L24); MANIFESTO.md › 4.4 Level 3 — Media Files (L117–126), › 5. Metadata Rules (L155–158); legacy/plan/03-domain-model-and-json-schemas.md › proposal.json field rules (L150–151); legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags (L110–113); legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › numbers a multi-disc release continuously across discs while tags.track restarts per disc (manifesto section 5 table)

## SET

### AS-DOC-DEF-014 — README "settings init" still offers "copy or move"
Status: Draft | Type: Contradiction | Area: SET | Related: AS-DOC-SET-006, AS-DOC-SET-021, AS-DOC-SET-030, AS-DOC-CLI-005

README › One-time setup says init prompts "Copy mode: copy or move (default: copy)" and that `move` deletes source files after apply. Plan 04 › functions also says init prompts "copy-vs-move". The tests say init never prompts for the copy mode and rejects `move` as "no longer supported". README › 5. Apply, README › Reference: settings and plan 04 › Purpose / scope agree with the tests, so the README contradicts itself. The area file follows the tests. See also AS-DOC-DEF-088 (the same remnant in README › 5. Apply).

Sources: legacy/README.md › One-time setup (L87–88); legacy/README.md › 5. Apply (L297–300); legacy/README.md › Reference: settings (L376); legacy/plan/04-settings-module.md › Reshelf.Settings.psm1 functions (L294–296); legacy/tests/Reshelf.Settings.Tests.ps1 › Initialize-ReshelfSettings › prompts only for fields left unsupplied, in an interactive host (L83–96, comment L91–92); › Initialize-ReshelfSettings › rejects -CopyMode move - it was removed for source-file safety (L162–164); › Set-ReshelfSettings › rejects copyMode move - it was removed for source-file safety (L286–288)

### AS-DOC-DEF-015 — When the target-root write access is checked
Status: Draft | Type: Contradiction | Area: SET | Related: AS-DOC-SET-005, AS-DOC-SET-031, AS-DOC-SET-034, AS-DOC-SET-040

Plan 04 says an unwritable `targetRoot` fails fast "at settings load time". The README says the check runs "on set/init". The tests cover init and set only. No test checks write access when settings are loaded. The area file follows the README and the tests.

Sources: legacy/plan/04-settings-module.md › Edge cases (L353–354); legacy/README.md › Reference: settings (L375); legacy/tests/Reshelf.Settings.Tests.ps1 › Initialize-ReshelfSettings › throws when TargetRoot is not writable (L166–171); › Set-ReshelfSettings › re-validates writability (L290–297); › Get-ReshelfSettings (L209–249)

### AS-DOC-DEF-016 — The documented default of targetRoot is not valid against the schema
Status: Draft | Type: Contradiction | Area: SET | Related: AS-DOC-SET-005, AS-DOC-DAT-027

The README gives `targetRoot` the default `""` (required). The schema needs `minLength: 1`. A settings file with the documented default fails validation. Plan 04 names a template file `legacy/config/settings.default.json`, which also has `"targetRoot": ""`.

Sources: legacy/README.md › Reference: settings (L375); legacy/schemas/settings.schema.json › targetRoot (L24); legacy/plan/04-settings-module.md › Inputs / outputs (L281)

## SES

### AS-DOC-DEF-017 — A session is "recognized" from the moment it is created
Status: Draft | Type: Contradiction | Area: SES | Related: AS-DOC-SES-007, AS-DOC-SES-009, AS-DOC-SES-012, AS-DOC-DAT-031, AS-DOC-DAT-032, AS-DOC-CLI-012

Plan 04 says the session gets `stage = "recognized"` "once step 5 finishes". The test shows the stage is `recognized` right at creation. The area file follows the test. The schema has no stage for "recognition running" or "recognition failed", and `recognitionPath` must be non-empty at creation. So a session whose recognition failed or stopped looks like a finished `recognized` session, and resume suggests `propose`. See also AS-DOC-DEF-104 (a failed recognize leaves the session behind).

Sources: legacy/plan/04-settings-module.md › Session persistence (L324–326); legacy/tests/Reshelf.Settings.Tests.ps1 › New-ReshelfSession › creates the session folder and a session.json with stage recognized (L333–339); › Resume-ReshelfSession › reports the next command for stage recognized (L381–384); legacy/schemas/session.schema.json (L21–25)

## REC

### AS-DOC-DEF-018 — The plan definition of a release folder does not match the tests
Status: Draft | Type: Contradiction | Area: REC | Related: AS-DOC-REC-011, AS-DOC-REC-012

Plan 05 says a release folder "looks like `yyyy Name` or `Name`, and directly contains audio files with sequential-looking numbering". The tests say a folder with only disc subfolders (no direct audio) is a release. A folder with unnumbered files (`Unnumbered\2015 No Numbers`) is also a release. The area file follows the tests.

Sources: legacy/plan/05-recognition-module.md › Heuristic functions (L34–35); legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsReleaseFolder (private) › recognizes a multi-disc release folder whose children are LP#-numbered disc subfolders (L28); legacy/tests/fixtures/expected/recognition.json › `Unnumbered` release

### AS-DOC-DEF-019 — Plans still describe the override-file design
Status: Draft | Type: Contradiction | Area: REC | Related: AS-DOC-REC-010, AS-DOC-REC-026, AS-DOC-REC-029, AS-DOC-REC-036, AS-DOC-REV-077, AS-DOC-ERR-007, AS-DOC-ERR-014, AS-DOC-GEN-007

The README says there is no override file: the user moves or renames the folder on disk and runs `recognize` again. The tests walk a grouping folder automatically and flag it `grouping-folder-auto-resolved`. Several plan texts still describe the old design with `overrides.json`:

- Plan 05: the "superseded" note at the top says grouping folders are auto-walked and `overrides.json` was removed. But the body still says a grouping folder goes to `unrecognized[]` with `grouping-folder-suspected` unless `overrides.json` resolves it. It also says `overrides.json` can override the name of a category or band-member folder. Inputs / outputs, Decisions & rationale ("never auto-resolve ambiguous folder types", "overrides.json per source root") and Definition of done (an `overrides.json` test) still name the file.
- Plan 07: the unrecognized panel shows a generated `overrides.json` entry (kind `artist` / `grouping`), a copy button and the `recognize` command. The UI tests check only path, reason and children.
- Plan 10, plan 12 and plan 02 resolve unclear folders through `overrides.json`. Plan 12 points to a README section "Reference: overrides file", which does not exist.

The area files follow the tests and the README. AS-DOC-ERR-007 and AS-DOC-ERR-014 name the plan 10 design only as the contradicted source.

Sources: legacy/plan/05-recognition-module.md › (superseded note) (L3–10), › Inputs / outputs (L20–21), › The rule: only genuinely ambiguous cases go to a human (L62–80), › Decisions & rationale (L171–180), › Definition of done (L206–207); legacy/plan/07-editing-ui-module.md › Unrecognized folders (L159–169); legacy/plan/10-error-handling-and-edge-cases.md › Ambiguous/unrecognizable folders (L50–56); legacy/plan/12-build-order-and-milestones.md (L18, L71, L88, L171, L191); legacy/plan/02-discogs-account-and-api-access.md (L86); legacy/README.md › Reference: automatic folder recognition (L420–422); legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › walks a grouping folder automatically, treating each subfolder as its own artist flagged for review (L948); legacy/tests/ui/specs/unrecognized.spec.js › unrecognized folders

### AS-DOC-DEF-020 — Category list: "configurable" or "fixed"?
Status: Draft | Type: Contradiction | Area: REC | Related: AS-DOC-REC-025

Plan 05 calls the category names "a configurable list (`EPs`, `Singles`, `Lives`, `Live`, `Compilations`, `Bootlegs`, ...)". A test name says "recognizes configured category names". The README says "with no configuration needed" and "the fixed list above". The tests use only `EPs`, `Singles` and `Lives`. No settings key for this list is documented.

Sources: legacy/plan/05-recognition-module.md › Heuristic functions (L40–42); legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsCategorySubfolder (private) › recognizes configured category names case-insensitively (L167); legacy/README.md › Reference: automatic folder recognition (bullets 1 and 3)

### AS-DOC-DEF-021 — The plan disc folder pattern is narrower than the tests
Status: Draft | Type: Contradiction | Area: REC | Related: AS-DOC-REC-062, AS-DOC-REC-063, AS-DOC-REC-064

Plan 05 gives `^(CD|Disc|Disk|LP)\s*#?\.?\s*(\d+)$`. This pattern does not allow `_` (`CD_1`) or text after the number (`CD1. Forwards`, `Disc 2 - Bonus`). The tests accept both. The area file follows the tests.

Sources: legacy/plan/05-recognition-module.md › Track/disc parsing (L118); legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsDiscFolder / Get-ReshelfDiscFolders (private) › recognizes an underscore separator… (L461), › recognizes a disc number followed by trailing text after a separator (L468)

### AS-DOC-DEF-022 — The plan track-number patterns are fewer than the tests
Status: Draft | Type: Contradiction | Area: REC | Related: AS-DOC-REC-056, AS-DOC-REC-057, AS-DOC-REC-059

Plan 05 lists only `NN - Title`, `NN – Title` and `NN Title`. The tests also accept `[01] …` and `(02) …`, do not read `(1999) …` as a track number, and split `Artist - Title` into parts.

Sources: legacy/plan/05-recognition-module.md › Track/disc parsing (L111–117); legacy/tests/Reshelf.Recognition.Tests.ps1 › ConvertFrom-ReshelfTrackFileName (private) › parses a bracketed numbered filename… (L255), › parses a parenthesized numbered filename (L266), › does not read a parenthesized year as a track number (L275)

### AS-DOC-DEF-023 — "Exactly one audio file and one .cue" (plan) vs more in the tests
Status: Draft | Type: Contradiction | Area: REC | Related: AS-DOC-REC-068, AS-DOC-REC-075, AS-DOC-REC-076, AS-DOC-REC-079

Plan 05 says a cue release has exactly one audio file and one `.cue` file. The tests accept one audio file with two cue files (one matches by name). They also accept several audio + cue pairs in one folder (flat multi-disc).

Sources: legacy/plan/05-recognition-module.md › Single-file + cue detection (L128); legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › still recognizes a single-file + .cue release when an orphaned second .cue for an unused rip format is also present (L1284), › splits a flat multi-disc folder (several flac+cue pairs, no CD subfolders)… (L1333)

### AS-DOC-DEF-024 — Companion kind of `back.jpg`: "scan" (plan) vs "booklet" (tests)
Status: Draft | Type: Contradiction | Area: REC | Related: AS-DOC-REC-084

Plan 05 says images named `booklet`, `back` or `insert` get `kind: "scan"`. The test and the golden file give `scans\back.jpg` the kind `booklet`. The inputs do not say whether the folder name `scans` or the file name `back` decides the kind.

Sources: legacy/plan/05-recognition-module.md › Companion file classification (L142–143); legacy/tests/Reshelf.Recognition.Tests.ps1 › Get-ReshelfCompanionFiles (private) › classifies a nested companion file under a non-disc subfolder (L683–690); legacy/tests/fixtures/expected/recognition.json › `ZZ Top\2003 Mescalero\scans\back.jpg`, `…\1989 Country Label 123\scans\back.jpg`

### AS-DOC-DEF-025 — "Empty release folder → no-audio-files" (plan) vs an entry at artist level (test)
Status: Draft | Type: Contradiction | Area: REC | Related: AS-DOC-REC-017

Plan 05 says an empty release folder goes to `unrecognized[]` with `no-audio-files`. The test and the golden file put the top-level folder `Empty Artist` there, not the empty release folder `2010 Nothing Here`. The inputs do not show what happens to an empty release folder next to normal releases of the same artist.

Sources: legacy/plan/05-recognition-module.md › Edge cases (L184–185); legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › flags an empty artist folder (no audio anywhere) as unrecognized (L1106); legacy/tests/fixtures/expected/recognition.json › `unrecognized[1]`

### AS-DOC-DEF-026 — The invalid date `2006.13.01 - X` loses the valid year 2006
Status: Draft | Type: Suspected defect | Area: REC | Related: AS-DOC-REC-049

The test comment says the name "falls back to the plain `yyyy - Title` form". But the test asserts year `null` and title `2006.13.01 - X`. The name starts with a valid year, yet the release gets no year. The comment and the assertion do not agree.

Sources: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › parses a full release date and a release-type hint from each real-world folder name form (session 2026-10-03-0010, Maximum The Hormone) (L919–921)

### AS-DOC-DEF-027 — The band-member test name does not match its data
Status: Draft | Type: Suspected defect | Kind: test quality | Area: REC | Related: AS-DOC-REC-030

The test "rejects a subfolder whose normalized name matches the parent artist" uses `Talking Heads\1980 Remain In Light` with the parent `Talking Heads`. The names do not match. The test really checks that a release folder is not a band-member folder. The "same normalized name" rule has no real test.

Sources: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsBandMemberFolder (private) › rejects a subfolder whose normalized name matches the parent artist (L192–197)

### AS-DOC-DEF-028 — The numeric disc sort test does not prove a numeric sort
Status: Draft | Type: Suspected defect | Kind: test quality | Area: REC | Related: AS-DOC-REC-065

The test "sorts disc folders numerically, not lexically" uses only `CD 1` and `CD 2`. A text sort gives the same order. A case like `CD 2` / `CD 10` is missing.

Sources: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsDiscFolder / Get-ReshelfDiscFolders (private) › sorts disc folders numerically, not lexically (L482–490)

### AS-DOC-DEF-029 — The "all disc subfolders" test uses a folder with other children
Status: Draft | Type: Suspected defect | Kind: test quality | Area: REC | Related: AS-DOC-REC-011, AS-DOC-REC-012

The test uses `ZZ Top\2003 Mescalero`, which also has a `scans` folder and a loose `Stray Bonus Track.mp3`. The direct audio file alone already makes it a release (AS-DOC-REC-011). So the test does not check the disc-folder rule on its own. Only the LP# test (`2004 - LP Reissue`) does.

Sources: legacy/tests/Reshelf.Recognition.Tests.ps1 › Test-IsReleaseFolder (private) › recognizes a multi-disc release folder whose children are all disc subfolders (L21–26); legacy/tests/fixtures/sample-source-tree/ZZ Top/2003 Mescalero/

### AS-DOC-DEF-030 — A cue track duration can become negative
Status: Draft | Type: Suspected defect | Area: REC | Related: AS-DOC-REC-073

The last cue track lasts "whole-file duration minus its start". Two test comments say that a whole-file duration shorter than the last track's start "would make the now-computed per-track duration negative". The tests avoid this case by changing the mock (400 s, 300 s). No test shows a guard, a flag or a review reason for it, for example after a wrong duration from the tag reader or a bad cue sheet.

Sources: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › names cue-sheet virtual tracks from an .ape source as flac, since ffmpeg cannot write .ape (comment L1154–1158); › still recognizes a single-file + .cue release when an orphaned second .cue for an unused rip format is also present (comment L1304–1308)

### AS-DOC-DEF-031 — The recognitionConfidence rule is not documented and looks inconsistent
Status: Draft | Type: Suspected defect | Area: REC | Related: AS-DOC-REC-093

No doc or test describes `recognitionConfidence`. In the golden file, releases with review reasons (`grouping-folder-auto-resolved`, `artist-name-split-from-folder-name`, `album-folder-has-loose-files`) have 1.0. Releases with only an info flag (`artist-name-prefix-stripped`, `no-track-number`) have 0.8. So a release that needs review can have a higher confidence than one that does not.

Sources: legacy/tests/fixtures/expected/recognition.json › `recognitionConfidence` of all releases

### AS-DOC-DEF-032 — After an "Artist - Album" split, the artist source path is the whole source root
Status: Draft | Type: Suspected defect | Area: REC | Related: AS-DOC-REC-022

For `PULSAR OLYMP - 94Shine` and `Isidor - 3218 (…)` at the source root, the golden file gives the artist `sourcePaths` = `["<SOURCE_ROOT>"]`. That folder holds all other artists too, not only this one.

Sources: legacy/tests/fixtures/expected/recognition.json › artists `Isidor`, `PULSAR OLYMP`; legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › splits a flat "Artist - Album" release folder (no artist wrapper) into a review-flagged release (L1016)

### AS-DOC-DEF-033 — `discFolder` holds a value for flat cue pairs that have no disc folder
Status: Draft | Type: Suspected defect | Area: REC | Related: AS-DOC-REC-079

Flat multi-disc cue pairs have no disc folders. Still, each track's `discFolder` holds a label with the catalog number (the test checks only `-like '*TOCP-8588*'`). The field name says "folder", but the value is not a folder. The exact value is not documented.

Sources: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › splits a flat multi-disc folder (several flac+cue pairs, no CD subfolders)… (L1366–1370); legacy/README.md › Reference: automatic folder recognition (flat multi-disc bullet)

### AS-DOC-DEF-034 — A genre folder is treated as a parent artist in the merge test
Status: Draft | Type: Suspected defect | Area: REC | Related: AS-DOC-REC-019, AS-DOC-REC-029

In the merge test, `Genre A` and `Genre B` are "plain filler folders" with one subfolder each. The comment says each `Shared Artist` is recognized as a band-member folder of `Genre A` / `Genre B`. So the genre folders are handled as parent artists. The test does not check whether artists `Genre A` / `Genre B` (with zero releases) appear in the output.

Sources: legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › merges sourcePaths when the same artist name is found under two different parents (comment L1226–1230)

### AS-DOC-DEF-035 — One unnumbered file drops the number order of all other files
Status: Draft | Type: Suspected defect | Area: REC | Related: AS-DOC-REC-061

When one file in a folder has no track number, all files are sorted A–Z by name. Their own numbers are not used for the order, and all get `inferredTrackOrder` = `true`. Plan 05 says the same ("fall back to alphabetical filename order within the folder"). The result may not be what the user wants.

Example (illustration): `2 - B.flac`, `10 - A.flac`, `Bonus.flac` → order `10 - A.flac`, `2 - B.flac`, `Bonus.flac`.

Sources: legacy/tests/Reshelf.Recognition.Tests.ps1 › Get-ReshelfTrackOrder (private) › falls back to whole-folder alphabetical order when any file lacks a number (L426–437); legacy/plan/05-recognition-module.md › Track/disc parsing (L114–117)

### AS-DOC-DEF-036 — The companion test name promises more than it checks
Status: Draft | Type: Suspected defect | Kind: test quality | Area: REC | Related: AS-DOC-REC-083, AS-DOC-REC-084

The test "classifies loose and nested companions, routing playlists to ignored" uses only `ZZ Top\1999 XXX`. It checks one loose `cover.jpg`. It checks no nested companion and no playlist.

Sources: legacy/tests/Reshelf.Recognition.Tests.ps1 › Get-ReshelfCompanionFiles (private) › classifies loose and nested companions, routing playlists to ignored (L673–681)

### AS-DOC-DEF-037 — Three documented recognition rules have no test
Status: Draft | Type: Suspected defect | Kind: test quality | Area: REC | Related: AS-DOC-REC-028, AS-DOC-REC-029, AS-DOC-REC-084

(a) Plan 05 names a companion kind `text` (`.txt`, `.pdf`, `.nfo` with `lyrics`, `article`, `interview`). No test covers it. (b) The README says the metadata-confirmed category check uses the cue `PERFORMER` first, "then the audio file's artist tag", and needs "most" releases to agree. The tests cover only the cue `PERFORMER` case with all releases in agreement. (c) The README says a band-member folder holds "only release folders, no loose files". No test covers a band-member folder with loose files.

Sources: legacy/plan/05-recognition-module.md › Companion file classification (L144–145); legacy/README.md › Reference: automatic folder recognition (bullets 2–3); legacy/tests/Reshelf.Recognition.Tests.ps1 › Invoke-ReshelfRecognition › walks an artist folder with category subfolders whose releases carry its name as cue PERFORMER into one artist bucket (real-world Iron Maiden\Studio Albums + Compilation Albums case) (L1425)

### AS-DOC-DEF-038 — Plan 05 "Reading existing tags" is still an open recommendation
Status: Draft | Type: Contradiction | Area: REC | Related: AS-DOC-REC-089, AS-DOC-ERR-012

Plan 05 calls TagLibSharp "a deviation from the user's mp3tag decision — please confirm". The README treats TagLibSharp as the agreed tool for reading tags. The plan text was not updated.

Sources: legacy/plan/05-recognition-module.md › Reading existing tags (L155–162); legacy/README.md › Requirements (TagLibSharp.dll)

## DSC

### AS-DOC-DEF-039 — The plan lists two token sources; the tests and README have three
Status: Draft | Type: Contradiction | Area: DSC | Related: AS-DOC-DSC-002, AS-DOC-DSC-006, AS-DOC-SET-044

Plan 02 has two token sources (environment variable, `.env`). Step 3 throws an error that names "both places checked". The tests and the README settings table (key `discogsTokenEncrypted`) add a third source after `.env`: the DPAPI-encrypted token in `settings.json`. The area file follows the tests.

Sources: legacy/plan/02-discogs-account-and-api-access.md › Token resolution — `Get-DiscogsToken` (L32–45); legacy/tests/Reshelf.Discogs.Tests.ps1 › Get-DiscogsToken › falls through to the DPAPI-encrypted settings.json token… (L158–168), › still prefers … (L170–194); legacy/README.md › Reference: settings

### AS-DOC-DEF-040 — The error message names "both" sources, but there are three
Status: Draft | Type: Suspected defect | Area: DSC | Related: AS-DOC-DSC-006

The test is named "throws naming both sources when neither is set". It asserts only `*DISCOGS_ACCESS_TOKEN*`. With three sources (AS-DOC-DEF-039), the docs and tests do not show whether the message names the encrypted settings token. They also do not show whether the message uses a custom `discogsTokenEnvVar` name.

Sources: legacy/tests/Reshelf.Discogs.Tests.ps1 › Get-DiscogsToken › throws naming both sources when neither is set (L151–156)

### AS-DOC-DEF-041 — The plan endpoint list is incomplete
Status: Draft | Type: Contradiction | Area: DSC | Related: AS-DOC-DSC-007, AS-DOC-MAT-006, AS-DOC-MAT-007, AS-DOC-MAT-010, AS-DOC-MAT-011

Plan 02 › API basics lists only `GET /database/search?type=release` and `GET /releases/{id}`. The matching tests also use `type=master`, `type=artist`, `/masters/{id}`, `/masters/{id}/versions`, `/artists/{id}` and `/artists/{id}/releases`.

Sources: legacy/plan/02-discogs-account-and-api-access.md › API basics (L67–69); legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) (L1311–1633)

### AS-DOC-DEF-042 — Rate limit 0 has no defined meaning
Status: Draft | Type: Suspected defect | Area: DSC | Related: AS-DOC-DSC-017

The test checks only that `RateLimitPerMinute = 0` does not crash. It does not say whether 0 means "no limit", "block" or something else. The README and plan do not define 0 either.

Sources: legacy/tests/Reshelf.Discogs.Tests.ps1 › Invoke-DiscogsRequest › does not crash when RateLimitPerMinute is 0 (L469–475)

## MAT

### AS-DOC-DEF-043 — The plan search query keys differ from the tests
Status: Draft | Type: Contradiction | Area: MAT | Related: AS-DOC-MAT-006, AS-DOC-MAT-007, AS-DOC-MAT-009

Plan 02 shows the search as `q=...&artist=...&year=...`. The tests check the keys `release_title`, `artist`, `type` and `per_page`. No matching test uses `q` (only the client tests do).

Sources: legacy/plan/02-discogs-account-and-api-access.md › API basics (L68); legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › falls back to the cleaned title variant… (L1222), › falls back to the artist master list… (L1423), › normalizes a Cyrillic look-alike… (L1387)

### AS-DOC-DEF-044 — "At most 4 searches" is no longer the whole search
Status: Draft | Type: Contradiction | Area: MAT | Related: AS-DOC-MAT-006, AS-DOC-MAT-007, AS-DOC-MAT-008, AS-DOC-MAT-009, AS-DOC-MAT-010, AS-DOC-MAT-011

Plan 06 step 2 says the lookup is "at most 4 cached searches, not one fixed query" and stops at the first non-empty result. The README and tests show more steps after these 4: the artist master list, a plain release search, master promotion, an artist search and the artist catalog. A note in plan 06 itself says that the section "hasn't been fully reconciled".

Sources: legacy/plan/06-edit-proposal-module.md › Discogs lookup (step 2, L47–52; note L67–80); legacy/README.md › How Discogs matching works; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private)

### AS-DOC-DEF-045 — Plan: title alignment is the only fallback; tests: number alignment too
Status: Draft | Type: Contradiction | Area: MAT | Related: AS-DOC-MAT-045, AS-DOC-MAT-047, AS-DOC-PRP-034

Plan 06 › Edge cases says that any track without a good title match (>= 0.8) "falls the whole release back to source titles". The tests show a second method: alignment by detected track number (method `number`) on a single-disc source. See also AS-DOC-DEF-064.

Sources: legacy/plan/06-edit-proposal-module.md › Edge cases (L288–299); legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsTrackAlignment (private) › falls back to track-number alignment… (L769–810)

### AS-DOC-DEF-046 — The version-rank test claims a year preference but passes no folder year
Status: Draft | Type: Suspected defect | Kind: test quality | Area: MAT | Related: AS-DOC-MAT-031

The test "prefers the version whose released year matches the folder year, then a CD/File format over Vinyl, then higher community count" calls the sort with `-FolderYear $null`. So it cannot check the year rule. The winner (id 2) follows from format group and collection count only. No test checks rule 1 (year match) on its own. The 8-Track test gives all versions the same year.

Sources: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Sort-ReshelfDiscogsVersions / Get-ReshelfDiscogsVersionRank (private) (L1637–1648, L1662–1684)

### AS-DOC-DEF-047 — The edition-hint test uses a different hint for each version
Status: Draft | Type: Suspected defect | Kind: test quality | Area: MAT | Related: AS-DOC-MAT-003, AS-DOC-MAT-034, AS-DOC-MAT-035

The "does not false-positive" test ranks version 1 with the hint `Limited` and version 2 with the hint `Limited Edition`. So it does not show whether the short hint `Limited` matches the token `Limited Edition`. Plan 06 strips the edition word `Limited` from folder titles, so a short hint is a likely real input. The exact token rule (equal, prefix or word match) is not shown.

Sources: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Sort-ReshelfDiscogsVersions / Get-ReshelfDiscogsVersionRank (private) › does not false-positive… (L1698–1713); legacy/plan/06-edit-proposal-module.md › Discogs lookup (step 1, L25–30)

### AS-DOC-DEF-048 — Auto-"matched" even when no candidate has the source track count
Status: Draft | Type: Suspected defect | Area: MAT | Related: AS-DOC-MAT-028

When several candidates pass the threshold and none has the source track count, the app still returns `matched` by format preference. Example: source 9 tracks, candidates with 5 and 7 tracks → `matched`, release 2. Plan 02 says unclear matches are "never guessed". The tests do not show a review flag for this case.

Sources: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › prefers an Album-format candidate over a Promo one… (L1276–1309); legacy/plan/02-discogs-account-and-api-access.md › Decisions & rationale (L124–126)

### AS-DOC-DEF-049 — Threshold wording: "above" vs "at or above"
Status: Draft | Type: Contradiction | Area: MAT | Related: AS-DOC-MAT-015, AS-DOC-MAT-023

A Resolve test name and plan 02 say "above the threshold". The scoring tests treat `>= 0.85` ("at the threshold") as a pass. The docs do not say whether a score of exactly 0.85 gives `matched`.

Sources: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) › returns matched with fetched detail when the top score is above the threshold (L1130); › Get-ReshelfDiscogsCandidateScore (private) (L347–434); legacy/plan/02-discogs-account-and-api-access.md › Matching confidence (L109–110)

### AS-DOC-DEF-050 — "Top 5 candidates" for "ambiguous" has no test
Status: Draft | Type: Suspected defect | Kind: test quality | Area: MAT | Related: AS-DOC-MAT-024, AS-DOC-MAT-030

Plan 02 says an `ambiguous` result carries the top 5 candidates. The tests only check "more than 0". On the master path, the candidates are the master's versions (2 in the test). The docs do not say whether this list is also cut to 5.

Sources: legacy/plan/02-discogs-account-and-api-access.md › Matching confidence (L111–112); legacy/tests/Reshelf.EditProposal.Tests.ps1 › Resolve-ReshelfDiscogsMatch (private) (L1147–1162, L1348)

### AS-DOC-DEF-051 — Pad width: the plan says "highest NN", the test input is the track count
Status: Draft | Type: Contradiction | Area: MAT | Related: AS-DOC-MAT-058, AS-DOC-MAT-059, AS-DOC-PRP-018, AS-DOC-TXT-050

Plan 06 sets the width to `max(trackNumberPadWidth, digits of the highest NN)`. The tests pass a "total track count". The two differ when the source has gaps, because missing tracks keep their real numbers.

Example (illustration): a Discogs list of 100 tracks, the source misses one → 99 files, but the highest NN is 100.

Sources: legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags (L112–114); legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfProposalPadWidth (private) (L291–316)

### AS-DOC-DEF-052 — The README version ranking skips the third format group
Status: Draft | Type: Contradiction | Area: MAT | Related: AS-DOC-MAT-031, AS-DOC-MAT-033

README step 2 names only "CD/File over Vinyl/Cassette". The tests show a third, lowest group for every other format (for example 8-Track Cartridge). A test comment says this order was "backwards" before (a past defect, now fixed in the test).

Sources: legacy/README.md › How Discogs matching works (step 2); legacy/tests/Reshelf.EditProposal.Tests.ps1 › Sort-ReshelfDiscogsVersions / Get-ReshelfDiscogsVersionRank (private) › ranks Vinyl/Cassette above a rarer format… (L1662–1684)

### AS-DOC-DEF-053 — Various Artists evidence: the exact minimum is not defined
Status: Draft | Type: Suspected defect | Area: MAT | Related: AS-DOC-MAT-054

One test says "every track has a different tagged artist than the folder". Another says a split release fails for "not enough distinct artists". The tests show 3 distinct artists → yes and 2 → no. The docs give no rule for other cases, for example 4 tracks with 3 distinct artists, or one track equal to the folder artist.

Sources: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Get-ReshelfVariousArtistsEvidence (private) (L587–673)

## PRP

### AS-DOC-DEF-054 — Default cover: the embedded cover wins, not the Discogs primary image
Status: Draft | Type: Contradiction | Area: PRP | Related: AS-DOC-PRP-051, AS-DOC-PRP-054

Plan 06 says propose pre-selects the Discogs primary image. The test shows that a decodable embedded cover is the default, even when Discogs has images. The area file follows the test.

Sources: legacy/plan/06-edit-proposal-module.md › Cover art candidates ("Pre-select the Discogs primary image"); legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › cover art › defaults to an already-embedded cover even when Discogs also has images (~L2455)

### AS-DOC-DEF-055 — An undecodable local cover is still a candidate and is chosen
Status: Draft | Type: Suspected defect | Area: PRP | Related: AS-DOC-PRP-052, AS-DOC-PRP-053

An undecodable embedded cover is removed from the candidates. But a loose `cover.jpg` with the content `not-a-real-image` stays a candidate and is chosen. The golden file shows it as `width 1, height 1`, the "could not decode" value. A test comment says such a cover fails the ffmpeg resize at apply time.

Sources: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › cover art › falls back to a local companion cover when Discogs has no images (~L2424); › falls back to a Discogs image when the embedded cover is not a decodable image (~L2483, comment); legacy/tests/fixtures/expected/proposal.json › ZZ Top / XXX coverArt

### AS-DOC-DEF-056 — Target actions are not decided by the stable key alone
Status: Draft | Type: Contradiction | Area: PRP | Related: AS-DOC-PRP-066, AS-DOC-PRP-069, AS-DOC-LSY-025

The README table defines every target action through "same stableKey". The tests also find the target folder through the apply-log path and the proposed path, with a different stable key. They also give `create-new` when a folder for the same stable key exists at an older path (`previously-lossy-different-location`). The README table has no row for that case. The area file follows the tests.

Sources: legacy/README.md › Re-runs and duplicates (table); legacy/plan/06-edit-proposal-module.md › Target comparison; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › target comparison › proposes update-existing/replace-existing via the apply-log when the source stableKey differs … (~L2683); › only warns (previously-lossy-different-location) … (~L2725)

### AS-DOC-DEF-057 — The stable key changes when the source folder has a different name
Status: Draft | Type: Contradiction | Area: PRP | Related: AS-DOC-PRP-075, AS-DOC-LSY-026, AS-DOC-GEN-008, AS-DOC-DAT-064

The README says the same release is "always recognized as the same across runs, even from a different source folder". Plan 00 says the same release gets the same key in every run. Plan 06, plan 09 and the tests show that a renamed source folder gives a different stable key (`Forwards Special Edition` vs `Forwards`; `PULSAR OLYMP - 94Shine` vs `Pulsar Olymp\2015 94 Shine`). The name search and the path lookups exist because of this. See also AS-DOC-DEF-006 (the opposite case: two releases, one key).

Sources: legacy/README.md › Re-runs and duplicates (paragraph 1); legacy/plan/00-overview.md › Cross-cutting decisions; legacy/plan/09-lossy-lossless-tracking.md › Lifecycle; legacy/plan/06-edit-proposal-module.md › Target comparison; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › lossy tracking › flags previously-lossy-different-location when a lossless re-import matches … by name (~L2843)

### AS-DOC-DEF-058 — "An organized release is never queried again" vs "Discogs is always queried"
Status: Draft | Type: Contradiction | Area: PRP | Related: AS-DOC-PRP-066, AS-DOC-DSC-019, AS-DOC-DSC-020

The README says "a release you've already organized is never queried again". Plan 06 says "Discogs is always queried first", and only the cache makes a re-run cheap. No test shows which is true. The README may only describe the purpose of the cache.

Sources: legacy/README.md › 2. Propose (cache paragraph); legacy/plan/06-edit-proposal-module.md › Target comparison ("As implemented (checked 2026-09-26)"), › Decisions & rationale

### AS-DOC-DEF-059 — Compilation detection has a third trigger, and Album Artist is not the folder name
Status: Draft | Type: Contradiction | Area: PRP | Related: AS-DOC-PRP-041, AS-DOC-PRP-042

The README and plan 06 list two triggers: the Discogs artist "Various" (id 194), or a folder or artist name `Various` / `Various Artists`. The tests also turn `DIO\1999 - Holy Dio` (tracks by several artists) into a Various compilation, with and without a Discogs match. The README also says "Album Artist stays the folder name ("Various")". In this case the folder name is `DIO`, but Album Artist is `Various`.

Sources: legacy/README.md › Compilations; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › retries under "Various" … (~L2047); › falls back to a proposed "Various" compilation … (~L2115)

### AS-DOC-DEF-060 — Compilation track artist: the file-name step is missing from the docs
Status: Draft | Type: Contradiction | Area: PRP | Related: AS-DOC-PRP-039, AS-DOC-PRP-040

The README and plan 06 give this order: Discogs credit → file Artist tag → "Various" with a review note. The test adds one more step before the last one: the artist part of the file name, with no note. Example: `[01] Blind Guardian - Don't Talk To Stranger.mp3` → `Blind Guardian`.

Sources: legacy/README.md › Compilations; legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags (tags.artist list); legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfProposedTrackSet (private) - real track positions › per-track Artist selection (compilations and split releases) › falls back to the file-name artist on a compilation with no tags at all … (~L1076)

### AS-DOC-DEF-061 — The README says a per-track Artist exists only on compilations
Status: Draft | Type: Contradiction | Area: PRP | Related: AS-DOC-PRP-037

The README track table says "Artist defaults to Album Artist, except on a compilation". The test and plan 06 use the Discogs per-track credit on any release, also on a split release that is not a compilation.

Sources: legacy/README.md › 3. Review in the browser (track table bullet); legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags; legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfProposedTrackSet (private) - real track positions › per-track Artist selection (compilations and split releases) › uses the Discogs per-track artist credit when a track has one, even on a non-compilation release (~L1032)

### AS-DOC-DEF-062 — A stray track gets disc 3 on a release with 2 disc folders
Status: Draft | Type: Suspected defect | Area: PRP | Related: AS-DOC-PRP-030

In the golden file, `ZZ Top\2003 Mescalero` has `discFolderCount = 2`. The stray `Stray Bonus Track.mp3` (outside the disc folders) gets disc 3, Track 1 and file number `06`. This creates a third disc that does not exist. Recognition flags the release (`track-outside-disc-folder-suspected`), but the proposed disc number may still be wrong.

Sources: legacy/tests/fixtures/expected/proposal.json › ZZ Top / Mescalero

### AS-DOC-DEF-063 — A stable-key collision in the target hides one folder without a warning
Status: Draft | Type: Suspected defect | Area: PRP | Related: AS-DOC-PRP-065

`ZZ Top\1999 XXX` and `zz  top\1999 XXX` give one index entry. The test only checks "no error" and count 1. The docs do not say which folder is kept. No warning or review note is shown. The other folder is invisible to the comparison.

Sources: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Build-ReshelfTargetIndex and Test-ReshelfTargetReleaseExists › does not throw on a stable-key collision … (~L1749)

### AS-DOC-DEF-064 — The track-count mismatch test cannot tell "source titles" from "aligned Discogs titles"
Status: Draft | Type: Suspected defect | Kind: test quality | Area: PRP | Related: AS-DOC-PRP-034, AS-DOC-MAT-045

The test name says it "falls back to source titles". Plan 06 says title alignment runs first, and here the alignment would succeed (the source titles equal Discogs titles 1 and 2). Then the Discogs titles are used and a "missing on source" note is added. The asserted titles are the same in both cases, so the test does not show which path ran. See also AS-DOC-DEF-045.

Sources: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › naming and tagging › forces review and falls back to source titles on a Discogs tracklist count mismatch (~L2212); legacy/tests/fixtures/discogs-responses/release-response.json (3 tracks); legacy/plan/06-edit-proposal-module.md › Edge cases

### AS-DOC-DEF-065 — The selection recompute puts review data in other fields than the proposal
Status: Draft | Type: Suspected defect | Area: PRP | Related: AS-DOC-PRP-077, AS-DOC-PRP-078

The selection recompute tests read the review flag as `requiresReview` and the note as `notes` on the returned release. The proposal document keeps them in `humanReview.required` and `humanReview.notes`. The tests do not show that the conflict flag and the `target path collision` note reach `humanReview`.

Sources: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Update-ReshelfReleaseForDiscogsSelection › flags a target conflict when a sibling … (~L3063–3064, ~L3097–3099)

### AS-DOC-DEF-066 — Where the romanized artist half comes from is unclear
Status: Draft | Type: Contradiction | Area: PRP | Related: AS-DOC-PRP-045, AS-DOC-PRP-046

The README says the romanized half "always comes from the source itself". The folder artist is `Maximum the Hormone`, but the result is `Maximum The Hormone = …`. This equals the Discogs name variation `Maximum The Hormone`. It also equals the title-cased folder name. So either the text is title-cased, or it comes from Discogs and not from the source.

Sources: legacy/README.md › Reference: Japanese releases; legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › bilingual (Japanese) release naming (session 2026-10-03-0010) › names the album/track "{romanized} = {original}" … (~L2317, `namevariations`)

### AS-DOC-DEF-067 — Title case breaks a real name in the compilation fallback
Status: Draft | Type: Suspected defect | Area: PRP | Related: AS-DOC-PRP-038

The file Artist tag `johnny mcevoy` becomes `Johnny Mcevoy`. The real name is "Johnny McEvoy". Title case on an all-lowercase tag cannot restore inner capitals. The proposal writes a wrong name without a review note.

Sources: legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfProposedTrackSet (private) - real track positions › per-track Artist selection (compilations and split releases) › falls back to the file's existing Artist tag on a compilation when Discogs has no per-track credit (~L1048)

### AS-DOC-DEF-068 — Repeated source numbers: the plan says "force review", the test checks only the note
Status: Draft | Type: Contradiction | Area: PRP | Related: AS-DOC-PRP-028

Plan 06 says repeated source numbers add a note "and force review". The track-set test checks only the renumbering and the note. No test shows the review flag. The area file keeps the plan rule until Phase 2 confirms it.

Sources: legacy/plan/06-edit-proposal-module.md › Computing proposed names and tags (step 4, L132); legacy/tests/Reshelf.EditProposal.Tests.ps1 › New-ReshelfProposedTrackSet (private) - real track positions › renumbers a disc sequentially and adds a note when source file numbers repeat (~L1000)

## REV

### AS-DOC-DEF-069 — Discogs edition pick: README "no re-fetch" vs tests that recompute the release
Status: Draft | Type: Contradiction | Area: REV | Related: AS-DOC-REV-067, AS-DOC-PRP-076

The README says picking an edition "only records your choice; it does not re-fetch tags/tracklist/cover". The recompute test fetches the chosen release and recomputes names, titles, file names, cover and target action. `helpers.js` says the real endpoint always makes a live Discogs `/releases/{id}` call, and the page merges the answer (tracks, proposed, coverArt …) into the release. The UI spec only proves the mocked path. The area files follow the tests. Phase 2 must check that the server endpoint calls the recompute.

Sources: legacy/README.md › 3. Review in the browser (Discogs edition picker bullet, L228–230); legacy/tests/Reshelf.EditProposal.Tests.ps1 › Update-ReshelfReleaseForDiscogsSelection › recomputes track titles, album/artist names, cover art, and target action from the chosen candidate (~L2985); legacy/tests/ui/helpers.js › mockDiscogsSelection (comment, L74–84); legacy/tests/ui/specs/review-state.spec.js › review state: Discogs match, Approve, Reject › an ambiguous release shows the Discogs candidate picker and the "ambiguous" badge; picking a candidate resolves it

### AS-DOC-DEF-070 — The "Needs review only" filter hides ambiguous releases that also need review
Status: Draft | Type: Suspected defect | Area: REV | Related: AS-DOC-REV-029, AS-DOC-REV-031

The filter works on the badge, not on `needsReview`. The rich release has `needsReview: true` but the badge `ambiguous`, so `Needs review only` hides it. The label suggests it would be shown.

Sources: legacy/tests/ui/specs/review-state.spec.js › review state: Discogs match, Approve, Reject › the "Needs review" and "Ambiguous" filters narrow the list … (L79–81 of the test)

### AS-DOC-DEF-071 — Unsaved manual cover uploads leave files on disk
Status: Draft | Type: Suspected defect | Area: REV | Related: AS-DOC-REV-063

The upload writes the file at once. When the user reloads without Save, the candidate is gone, but the file stays in `manual-covers\`. No source says that anything removes it later.

Sources: legacy/tests/ui/specs/covers.spec.js › cover art › uploading a valid image adds it … its file stays on disk; legacy/plan/11-testing-and-verification-strategy.md › UI verification (item 4)

### AS-DOC-DEF-072 — Save accepts any valid JSON, also a proposal that breaks the schema
Status: Draft | Type: Suspected defect | Area: REV | Related: AS-DOC-REV-014, AS-DOC-REV-015

The save test writes `{"artists":[]}` (no `schemaVersion`, no `sessionId`), and the save succeeds. Only "valid JSON" is checked. A bad request body can damage `proposal.json`, and there is only one backup.

Sources: legacy/tests/Reshelf.UiServer.Tests.ps1 › Get-ReshelfUiProposalContent / Save-ReshelfUiProposalContent › writes a rolling backup … (L282–289)

### AS-DOC-DEF-073 — Plan 07: Save applies the reserved-device-name rule; tests: Save writes the body as sent
Status: Draft | Type: Contradiction | Area: REV | Related: AS-DOC-REV-015, AS-DOC-REV-035

Plan 07 says the preview skips the reserved-device-name suffix, but "`propose`/Save still apply that for real". The server save test writes the content unchanged. No test shows that Save makes names safe. So a hand-typed `CON` folder name may be saved as it is.

Sources: legacy/plan/07-editing-ui-module.md › Live folder-name preview (L132–134); legacy/tests/Reshelf.UiServer.Tests.ps1 › Get-ReshelfUiProposalContent / Save-ReshelfUiProposalContent › writes a rolling backup …

### AS-DOC-DEF-074 — Live track numbering is too low when the last track of an earlier disc is missing
Status: Draft | Type: Suspected defect | Area: REV | Related: AS-DOC-REV-042

The page uses the highest Track number of a disc as the disc size. If the last track of disc 1 is missing, the file numbers of disc 2 start too early. Plan 07 names this a known limitation.

Sources: legacy/plan/07-editing-ui-module.md › Live track file-name preview (L150–153)

### AS-DOC-DEF-075 — Older sessions are not renumbered on load
Status: Draft | Type: Suspected defect | Area: REV | Related: AS-DOC-REV-043

A session saved before the numbering rule keeps the old file names until the user types a Track value again in each release. Until then, the page shows names that do not follow the rule.

Sources: legacy/plan/07-editing-ui-module.md › Live track file-name preview (L154–155)

### AS-DOC-DEF-076 — Badge names in plan 07 differ from the tests and README
Status: Draft | Type: Contradiction | Area: REV | Related: AS-DOC-REV-029, AS-DOC-REV-076

Plan 07 lists the badges `needsReview`, `ambiguous match` and `ready`. The tests and the README use `ambiguous`, and they also have `rejected` and `unrecognized`. The area file follows the tests.

Sources: legacy/plan/07-editing-ui-module.md › UI shape (L86–87); legacy/tests/ui/specs/review-state.spec.js; legacy/tests/ui/specs/unrecognized.spec.js; legacy/README.md › 3. Review in the browser

### AS-DOC-DEF-077 — Plan 07: local-file serves only paths in proposal.json; tests: manual covers too
Status: Draft | Type: Contradiction | Area: REV | Related: AS-DOC-REV-016

Plan 07 says a file is served "only if `path` exactly matches one already listed in that session's own `proposal.json`". The test also serves any file inside the session's `manual-covers` folder. The area file follows the test.

Sources: legacy/plan/07-editing-ui-module.md › Server-side persistence (L46–51); legacy/tests/Reshelf.UiServer.Tests.ps1 › Get-ReshelfUiLocalFileBytes › serves a file under manual-covers …

### AS-DOC-DEF-078 — A bad session id gives "bad request", a bad stable key gives "no route"
Status: Draft | Type: Suspected defect | Area: REV | Related: AS-DOC-REV-008, AS-DOC-REV-009

A wrong session id in a route gives `BadRequest`. A wrong stable key in the lossy route or the discogs-selection route gives no route at all, so the request goes to static file serving. The same kind of input error gets two different answers.

Sources: legacy/tests/Reshelf.UiServer.Tests.ps1 › Get-ReshelfUiApiRoute › rejects a session id …; › returns $null for a lossy stable key …; › returns $null for a discogs-selection stable key …

### AS-DOC-DEF-079 — A wrong HTTP method on an API path goes to static file serving
Status: Draft | Type: Suspected defect | Area: REV | Related: AS-DOC-REV-010

`DELETE /api/sessions/{id}/proposal`, `GET …/manual-cover` and similar requests get no API route. They fall through to static files. There is no "method not allowed" answer. The client gets a not-found style answer instead.

Sources: legacy/tests/Reshelf.UiServer.Tests.ps1 › Get-ReshelfUiApiRoute › returns $null for an unsupported verb on a known path; › returns $null for GET on the manual-cover path

### AS-DOC-DEF-080 — "Past sessions" lists all sessions; plan 07 says "the rest"
Status: Draft | Type: Contradiction | Area: REV | Related: AS-DOC-REV-026

Plan 07 says the dropdown "lists the rest" (the other sessions). The test shows both sessions, and the current one is the selected option. The area file follows the test.

Sources: legacy/plan/07-editing-ui-module.md › Server-side persistence (L59–61); legacy/tests/ui/specs/load-and-sessions.spec.js › loading and switching sessions › with 2+ sessions, the Past sessions dropdown lists both …

### AS-DOC-DEF-081 — An empty Year in one release blocks the whole apply run
Status: Draft | Type: Suspected defect | Area: REV | Related: AS-DOC-REV-038, AS-DOC-PRP-011

The README says an empty Year "fails validation and blocks the entire apply run, not just that one release". The page lets the user save an empty Year. No source documents a warning on the page.

Sources: legacy/README.md › 3. Review in the browser (L240–242)

### AS-DOC-DEF-082 — Seed data: the minimal release has needsReview = true but humanReview.required = false
Status: Draft | Type: Suspected defect | Kind: test quality | Area: REV | Related: AS-DOC-REV-029

Plan 07 says `humanReview.required` is set whenever a release is flagged. The seed has `needsReview: true`, `reviewReasons: ["no-track-number"]` and `humanReview.required: false`. The badge follows `needsReview`. The sources do not make clear which field the page and apply really use.

Sources: legacy/tests/ui/seed-session.ps1 (L212–225); legacy/plan/07-editing-ui-module.md › Approval gate

## APL

### AS-DOC-DEF-083 — Cue split: "no re-encoding" vs FLAC and APE re-encoding
Status: Draft | Type: Contradiction | Area: APL | Related: AS-DOC-APL-008, AS-DOC-APL-029, AS-DOC-GEN-010

The README says apply splits cue releases "with ffmpeg (no re-encoding)". Plan 00 says ffmpeg runs with `-c copy`, no re-encoding. Plan 08 step 2 says one `ffmpeg ... -c copy` call per track for all formats. The tests show that `.flac` and `.ape` sources are re-encoded with `-c:a flac`; only other formats use `-c copy`. The area files follow the tests (AS-DOC-GEN-010 quotes plan 00 and points here).

Sources: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfFfmpegSplit codec selection (L260–305); legacy/README.md › 5. Apply (L287); legacy/plan/00-overview.md › Tech stack (L58); legacy/plan/08-implementation-module.md › Per-release pipeline step 2 (L41–47)

### AS-DOC-DEF-084 — README: an existing target folder is "deleted and replaced" — always?
Status: Draft | Type: Contradiction | Area: APL | Related: AS-DOC-APL-018, AS-DOC-APL-019

README › 5. Apply warns: "If a folder already exists at that target path, it is deleted and replaced", with no condition. The tests and plan 08 step 8 replace the folder only for `update-existing` or `conflict`. For `create-new` (and any other action) the release fails and the folder stays untouched. The area file follows the tests.

Sources: legacy/README.md › 5. Apply (L295); legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › fails a create-new release whose target folder already exists … (L1445–1471); legacy/plan/08-implementation-module.md › Per-release pipeline step 8 (L90–99)

### AS-DOC-DEF-085 — Which releases apply skips by default
Status: Draft | Type: Contradiction | Area: APL | Related: AS-DOC-APL-003, AS-DOC-APL-004, AS-DOC-REV-030, AS-DOC-REV-070

The sources give different rules for the default skip (without `-IncludeUnresolved`):

| Source | Skipped by default |
|---|---|
| Tests (Implementation, Pipeline) | an unresolved `ambiguous` release, an unresolved `conflict` release (Discogs status `matched`), and every `not-found` release of the fixture tree |
| README | "releases nobody reviewed"; a flagged release is applied only after Approve |
| Plan 07 › Approval gate | every release with `humanReview.resolved != true` |
| Plan 08 › Entry point | only releases with `discogsMatch.status == "ambiguous"` and `humanReview.resolved != true` |
| Comment in `companions.spec.js` | "only an ambiguous-AND-unresolved release is skipped by default" |

The area file follows the tests: a release that needs review and is not resolved is skipped. The comment in `companions.spec.js` does not decide this, because that test passes `-IncludeUnresolved`. No test covers a release with `humanReview.required = false` and `resolved = false`, so the exact condition (required, resolved, or both) is not clear.

Sources: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › skips a targetAction conflict release with humanReview.resolved = false, leaving the existing target untouched, unless -IncludeUnresolved (L1416–1443); legacy/tests/Reshelf.Pipeline.Tests.ps1 › Full pipeline: Recognition -> EditProposal -> Implementation › flags every release for human review since Discogs never matches, and apply skips all of them by default (L158–168); legacy/tests/ui/specs/companions.spec.js › companion (other) files › end-to-end … (L178–181); legacy/README.md › 3. Review in the browser (L237–238); legacy/README.md › 5. Apply (L282–283, L313–314); legacy/plan/07-editing-ui-module.md › Approval gate (L192–197); legacy/plan/08-implementation-module.md › Entry point (L28–31)

### AS-DOC-DEF-086 — An edit made after apply does not reach the target on a re-apply
Status: Draft | Type: Suspected defect | Area: APL | Related: AS-DOC-APL-011, AS-DOC-APL-069, AS-DOC-SES-016, AS-DOC-SES-023

The README says: when the user edits a release in the review UI after it was applied, and its source files did not change, a new `apply` run skips it. The edit never reaches the target. The skip check uses the source file-set hash, not the proposal. The README itself calls this a caveat.

Sources: legacy/README.md › Sessions and resuming (L346–348); legacy/tests/Reshelf.Implementation.Tests.ps1 › Test-ReshelfReleaseNeedsApply › reports NeedsApply false when a matching applied entry with the same source-file-set hash already exists under the current TargetRoot

### AS-DOC-DEF-087 — Old test comment: cue-split releases "lose" their source
Status: Draft | Type: Suspected defect | Kind: test quality | Area: APL | Related: AS-DOC-APL-021

The BeforeEach comment in the pipeline test says: "Implementation mutates its source (cue-split releases always lose their original cue+audio file, regardless of copy/move mode)". The same file (L231) and the Implementation tests assert that the `.cue` and audio source files stay. The README and plan 08 also say the source is read-only. The comment is out of date.

Sources: legacy/tests/Reshelf.Pipeline.Tests.ps1 › Full pipeline: Recognition -> EditProposal -> Implementation › BeforeEach comment (L126–128) vs L231; legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › cue-sheet release (L1600–1603)

### AS-DOC-DEF-088 — README and plan 08: "copied/moved"
Status: Draft | Type: Contradiction | Area: APL | Related: AS-DOC-APL-002, AS-DOC-APL-021, AS-DOC-SET-006

README › 5. Apply defines Applied as "copied/moved and tagged successfully". The README Pipeline diagram says apply "copies/moves files". Plan 08 › Purpose / scope also says "copy/move". The same README section says `copy` is the only mode and `move` was removed. See also AS-DOC-DEF-014 (the same remnant in the `settings init` prompt).

Sources: legacy/README.md › 5. Apply (L312 vs L297–300); legacy/README.md › Pipeline (L47); legacy/plan/08-implementation-module.md › Purpose / scope (L5)

### AS-DOC-DEF-089 — A test name says a "missing" entry means no re-apply
Status: Draft | Type: Suspected defect | Kind: test quality | Area: APL | Related: AS-DOC-APL-016

One test is named "treats a missing/already-applied entry as not needing re-apply, when every source file is already gone". The next test shows that with no entry at all (sources gone) the release DOES need apply. The first test covers only an existing `applied` entry. The "missing" part of the name is wrong.

Sources: legacy/tests/Reshelf.Implementation.Tests.ps1 › Test-ReshelfReleaseNeedsApply (L591–608 vs L610–619)

### AS-DOC-DEF-090 — All sources gone + an applied entry: skip, whatever the hash and the target state
Status: Draft | Type: Suspected defect | Area: APL | Related: AS-DOC-APL-015, AS-DOC-APL-016

When all source files are gone and an `applied` entry exists, apply skips the release, even though the logged hash (`irrelevant`) cannot match. The test creates the target folder, so it is not clear whether apply still checks the target root and the target folder in this case. The outcome when the target folder was also deleted is not documented.

Sources: legacy/tests/Reshelf.Implementation.Tests.ps1 › Test-ReshelfReleaseNeedsApply (L591–608)

### AS-DOC-DEF-091 — A retry over an old staging folder is not documented
Status: Draft | Type: Suspected defect | Area: APL | Related: AS-DOC-APL-020, AS-DOC-ERR-001

A failed release leaves `.reshelf-staging\<stableKey>\` in place, and the README says the next apply retries it. No test and no doc says what happens to the old staged files on the retry: reused, cleared, or a name clash.

Sources: legacy/README.md › Troubleshooting / known limitations (L488–490); legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › removes the now-empty .reshelf-staging folder … leaves a failed release staged (L1152–1173)

### AS-DOC-DEF-092 — The plan 08 apply-log fields are incomplete
Status: Draft | Type: Contradiction | Area: APL | Related: AS-DOC-APL-062

Plan 08 step 10 lists `{ stableKey, appliedAtUtc, status, targetPath, sourceFileSetHash }`. The tests also write and read `errorMessage` and `truncated`. The area file follows the tests.

Sources: legacy/plan/08-implementation-module.md › Per-release pipeline step 10 (L102–103); legacy/tests/Reshelf.Implementation.Tests.ps1 › Get-ReshelfApplyLogPath / Get-ReshelfApplyLog / Add-ReshelfApplyLogEntry (L494–522)

### AS-DOC-DEF-093 — Step order: split before or after staging
Status: Draft | Type: Contradiction | Area: APL | Related: AS-DOC-APL-008

Plan 08 lists the cue split (step 2) before staging (step 3). The README lists staging (1) before the split (2). The tests do not show the order. This is a minor difference.

Sources: legacy/plan/08-implementation-module.md › Per-release pipeline; legacy/README.md › 5. Apply (L286–287)

### AS-DOC-DEF-094 — The FLAC retry drops 50 ms of audio
Status: Draft | Type: Suspected defect | Area: APL | Related: AS-DOC-APL-030

The "invalid block size" retry moves the track start 0.05 s later (`322.200` → `322.250`). The previous track still ends at `322.200`. So 50 ms of audio is in no track. The test treats this as intended.

Sources: legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfFfmpegSplit FLAC "invalid block size" retry (L308–328)

### AS-DOC-DEF-095 — Truncation can shrink a release folder name to 1 character
Status: Draft | Type: Suspected defect | Area: APL | Related: AS-DOC-APL-058

With a very tight budget, `3218 Some Catalog Album` becomes a 1-character folder name, and `2010 Some Album` becomes 6 characters (`2010 ` + 1). The test asserts this. A 1-character folder name is not useful for the user.

Sources: legacy/tests/Reshelf.Implementation.Tests.ps1 › Resolve-ReshelfTruncatedReleaseNames › does not treat a non-year 4-digit catalog-number prefix … (L458–477)

### AS-DOC-DEF-096 — The split track-count check has no test
Status: Draft | Type: Suspected defect | Kind: test quality | Area: APL | Related: AS-DOC-APL-032

Plan 08 says apply checks the split track count against the cue sheet and fails the release on a mismatch. No test shows this check.

Sources: legacy/plan/08-implementation-module.md › Per-release pipeline step 2, › Decisions & rationale

## LSY

### AS-DOC-DEF-097 — Upgrade detection does not need a ledger entry
Status: Draft | Type: Contradiction | Area: LSY | Related: AS-DOC-LSY-024

Plan 09 says propose detects an upgrade when "an existing target entry is `pending-upgrade`" and the new source is lossless. The tests detect it from the target folder content only, with no ledger entry. The area file follows the tests.

Sources: legacy/plan/09-lossy-lossless-tracking.md › Lifecycle (bullet 2); legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › target comparison › proposes update-existing/replace-existing when a lossless source would upgrade a lossy target (~L2664); › … when a lossy folder sits at the proposed path, even with no apply-log entry and a different stableKey (~L2707)

### AS-DOC-DEF-098 — Propose writes the library-wide ledger before review and apply
Status: Draft | Type: Suspected defect | Area: LSY | Related: AS-DOC-LSY-020, AS-DOC-LSY-021

Propose adds a `pending-upgrade` entry (with the proposed target path) as soon as it sees a lossy source. When the user later rejects the release, or never applies it, the entry stays in the ledger. Its target path points to a folder that may never exist. Propose re-runs on test sessions also add entries.

Sources: legacy/tests/Reshelf.EditProposal.Tests.ps1 › Invoke-ReshelfEditProposal › lossy tracking › creates a pending-upgrade ledger entry for a lossy source release (~L2798); legacy/plan/09-lossy-lossless-tracking.md › Lifecycle; legacy/README.md › Reference: lossy/lossless tracking

### AS-DOC-DEF-099 — When propose logs a lossy release: always, or only on create-new?
Status: Draft | Type: Contradiction | Area: LSY | Related: AS-DOC-LSY-020

Plan 09 says propose adds the entry "whenever it proposes a `create-new`" for a lossy source. The README and MANIFESTO §6 say every lossy release is logged. No test covers a lossy release with `conflict` or `skip-existing-identical`. The area file follows the README.

Sources: legacy/plan/09-lossy-lossless-tracking.md › Lifecycle (bullet 1); legacy/README.md › Reference: lossy/lossless tracking; MANIFESTO.md › 6. Additional Feature — Lossy/Lossless Tracking

## CLI

### AS-DOC-DEF-100 — The seed script header says two releases; it seeds four
Status: Draft | Type: Suspected defect | Kind: test quality | Area: CLI | Related: AS-DOC-CLI-038

The `.DESCRIPTION` says "a schema-valid proposal.json for two releases" and shows the output `{…, rich, minimal}`. The script seeds `rich`, `minimal`, `empty` and `compilation`, and prints all four.

Sources: legacy/tests/ui/seed-session.ps1 (L7–17 vs L300–326)

### AS-DOC-DEF-101 — Plan 11 lists 6 UI spec files; 10 exist
Status: Draft | Type: Contradiction | Area: CLI | Related: AS-DOC-CLI-037

Plan 11 › UI verification covers `load-and-sessions`, `edit-and-save`, `review-state`, `covers`, `companions` and `server-down`. It does not list `folder-name-preview`, `lossy-tracker`, `track-artist` and `unrecognized`.

Sources: legacy/plan/11-testing-and-verification-strategy.md › UI verification (L145–172); legacy/tests/ui/specs/

### AS-DOC-DEF-102 — The plan 01 command list has no "ui" command; the repo tree is out of date
Status: Draft | Type: Contradiction | Area: CLI | Related: AS-DOC-CLI-002

Plan 01 says `Reshelf.ps1 dispatcher: settings|session|recognize|propose|apply|lossy`. The README has `ui start`. The plan 01 tree also has no `Start-ReshelfUiServer.ps1`, no UI server module and no `tests/ui/`. The area file follows the README.

Sources: legacy/plan/01-repo-and-tooling-scaffolding.md › Repo tree (L36); legacy/README.md › 3. Review in the browser

### AS-DOC-DEF-103 — "-IncludeUi" reports success when the UI suite did not run
Status: Draft | Type: Suspected defect | Area: CLI | Related: AS-DOC-CLI-033

Without `tests/ui/node_modules`, the runner shows a warning and exits with 0. Plan 11 says that a silent skip of the integration tests "would let this coverage gap reopen unnoticed", and makes those tests fail instead. The two policies disagree.

Sources: legacy/tests/Invoke-ReshelfTests.ps1 (L66–71); legacy/plan/11-testing-and-verification-strategy.md › Implementation module verification (L92–96), › Test runner (L222–226)

### AS-DOC-DEF-104 — A failed recognize leaves an orphan session
Status: Draft | Type: Suspected defect | Area: CLI | Related: AS-DOC-CLI-012, AS-DOC-SES-007

When recognition fails after the session is created, the session stays (count = 1). It has no `recognition.json`. The error message names the session, but nothing removes or marks it. It then appears in `session list` and in the UI session list. See also AS-DOC-DEF-017 (such a session has the stage `recognized`).

Sources: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › recognize surfaces a clear error (naming the orphaned session) … (L153–170)

### AS-DOC-DEF-105 — Different exit-code checks for a missing session id
Status: Draft | Type: Suspected defect | Kind: test quality | Area: CLI | Related: AS-DOC-CLI-016, AS-DOC-CLI-026

`apply` without a session id is tested for exit code exactly 1 and no message. `propose` and `session …` without an id are tested for "non-zero" and the text `requires a session id`. The docs do not say whether `apply` prints the same message.

Sources: legacy/tests/Reshelf.Tests.ps1 › Reshelf.ps1 settings/session dispatch › apply without a session id exits 1; › propose fails with a clear error when no session id is given

## BND

No items. The Bandcamp fallback is plan only (AS-DOC-BND-001, AS-DOC-BND-002), and its sources do not disagree.

## ERR

### AS-DOC-DEF-106 — Plan 10: short names in staging, rename at commit
Status: Draft | Type: Contradiction | Area: ERR | Related: AS-DOC-APL-017, AS-DOC-ERR-003

Plan 10 says external tools run on short-named files inside staging, and the rename to the full name happens only at the final commit. The tests show that staged files already have their final names (tags are written on `.reshelf-staging\a1b2c3d4e5f60708\01 Track.flac`). Plan 08 step 4 also renames inside staging. The area files do not describe the plan 10 design as behavior.

Sources: legacy/plan/10-error-handling-and-edge-cases.md › Windows path length (L68–72); legacy/tests/Reshelf.Implementation.Tests.ps1 › Invoke-ReshelfImplementation › produces the correct final layout … (L960–963); legacy/plan/08-implementation-module.md › Per-release pipeline step 4

### AS-DOC-DEF-107 — MANIFESTO §8: a static website with no server
Status: Draft | Type: Contradiction | Area: ERR | Related: AS-DOC-ERR-008, AS-DOC-ERR-014, AS-DOC-GEN-010, AS-DOC-REV-001

MANIFESTO §8 says the UI is a static website with no server or backend. The README describes `ui start`, a port, and `-Port <N>` when the port is in use. So the UI has a localhost server. The area files follow the README.

Sources: MANIFESTO.md › 8. Tooling Philosophy (L274–276); legacy/README.md › Troubleshooting / known limitations (L491)

### AS-DOC-DEF-108 — MANIFESTO §8: a CLI tagger and one script per module
Status: Draft | Type: Contradiction | Area: ERR | Related: AS-DOC-ERR-012, AS-DOC-GEN-010, AS-DOC-CLI-001

MANIFESTO §8 expects "a set of PowerShell scripts, one per module, each calling out to CLI tools (e.g. a CLI metadata tagger)". Plan 08 writes tags in-process with TagLibSharp (mp3tag was dropped). The README uses one entry script, `scripts/Reshelf.ps1 <command>`. Plan 08 still names the old entry point `Invoke-Implementation.ps1 -SessionId <id> [-WhatIf] [-IncludeUnresolved]`.

Sources: MANIFESTO.md › 8. Tooling Philosophy (L272–273); legacy/plan/08-implementation-module.md › Entry point (L23), › Decisions & rationale; legacy/README.md › 5. Apply (L273, L279)

### AS-DOC-DEF-109 — The long-path prefix and the full-disk case have no test
Status: Draft | Type: Suspected defect | Kind: test quality | Area: ERR | Related: AS-DOC-ERR-002, AS-DOC-ERR-003

Plan 10 (the `\\?\` prefix) and plan 08 › Edge cases (disk full during the copy) describe behavior that no test covers. Plan 10 › Definition of done asks for a path-length fixture and an invalid-character fixture. The tests have the path-length cases only as unit tests with a synthetic deep root.

Sources: legacy/plan/10-error-handling-and-edge-cases.md › Windows path length, › Definition of done; legacy/plan/08-implementation-module.md › Edge cases

### AS-DOC-DEF-110 — MANIFESTO §9 still lists questions that later docs answer
Status: Draft | Type: Contradiction | Area: ERR | Related: AS-DOC-ERR-003, AS-DOC-ERR-004, AS-DOC-ERR-005, AS-DOC-ERR-006, AS-DOC-ERR-007, AS-DOC-ERR-012

MANIFESTO §9 lists open questions: static-site editing, the tagger choice, re-runs, path length, sessions. Plan 08, plan 10 and the README answer all of them. Some answers contradict the premise of the question (static site: AS-DOC-DEF-107; CLI tagger: AS-DOC-DEF-108). The manifesto was not updated.

Sources: MANIFESTO.md › 9. Open Questions for the Next Planning Session; legacy/plan/10-error-handling-and-edge-cases.md › Purpose / scope

## Cross-cutting

### AS-DOC-DEF-111 — Paths and "repo root" locations are unclear after the Phase 0 move to `legacy/`
Status: Draft | Type: Contradiction | Area: Cross-cutting | Related: AS-DOC-GEN-003, AS-DOC-GEN-010, AS-DOC-DAT-004, AS-DOC-SET-044, AS-DOC-DSC-002, AS-DOC-CLI-001, AS-DOC-CLI-030, AS-DOC-CLI-036

The README and the plans were written when the app was at the repo root. Since Phase 0 the app is in `legacy/`, and these texts are now unclear:

| Text in the docs | What the tests show |
|---|---|
| "run from the repo root": `pwsh scripts/Reshelf.ps1`, `pwsh tests/Invoke-ReshelfTests.ps1`, `cd tests/ui` (README) | the paths work only from `legacy/` |
| the data home `.data\` "inside the repo"; `TagLibSharp.dll` at `.data\lib\` (README) | the default resolves to `legacy/tests/../.data` = `legacy/.data`; the UI setup expects `legacy/.data/lib/TagLibSharp.dll` |
| `.env` "at the repo root" (README, plan 02) | not tested: every token test passes an explicit `-EnvFilePath` |

The area files quote the paths as written and use `legacy/.data` where a test shows it (AS-DOC-DAT-004). Side note: the default-location test creates the real `.data` folder, by design (see its comment).

Sources: legacy/README.md › Pipeline (L53); legacy/README.md › Requirements (L67); legacy/README.md › One-time setup (L97–99); legacy/README.md › Reference: data folder (L468–469); legacy/README.md › For developers (L502, L512); legacy/plan/02-discogs-account-and-api-access.md › Account and token (L24–28), › Token resolution — `Get-DiscogsToken` (L40); legacy/tests/Reshelf.Common.Tests.ps1 › Resolve-ReshelfDataHome › defaults to a .data folder inside the repo when RESHELF_HOME is not set (L43–54); legacy/tests/Reshelf.Discogs.Tests.ps1 › Get-DiscogsToken (all tests use `-EnvFilePath`); legacy/tests/ui/global-setup.js (L14, L68)

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-05 | Phase 1 draft: merged from the six area drafts. |
| 0.2 | 2026-10-10 | "Phase 3" → "Phase 4" for defect disposition, matching roadmap rule D2. |
