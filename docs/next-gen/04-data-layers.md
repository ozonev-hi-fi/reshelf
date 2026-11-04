# 04 — Data layers: Recognized, Proposed, User

Status: Draft | Version: 0.2 | Last updated: 2026-11-04

## Today vs next-gen

| Topic | Today (legacy) | Next-gen |
|---|---|---|
| Storage | `recognition.json` (recognized) and `proposal.json` (proposed **and** user edits mixed) | Three separate layers per field |
| User edits | Overwritten when `propose` runs again | Kept, and marked stale when the provider value changes |
| Cue sheets | Recognized as one audio file + cue. Split only at apply. | Recognized as **virtual tracks** in the Recognized layer. Split only at apply. |

## Requirements

### NG-LAY-001 — Three separate layers
Priority: Must | Status: Draft | Source: RAW, D11

The app stores three layers separately:

| Layer | Written by | Content |
|---|---|---|
| **Recognized** | Recognize | What the source shows: folder and file names, structure, existing tags, cue sheets |
| **Proposed** | Propose / re-sync | What the selected provider candidate and the templates suggest |
| **User** | The user, in the UI | The user's edits |

A later stage never overwrites an earlier layer.

### NG-LAY-002 — Effective value
Priority: Must | Status: Draft | Source: RAW, D11

The final (effective) value of each field is: `User ?? Proposed ?? Recognized`. The first layer that has a value wins. Apply uses the effective value.

### NG-LAY-003 — Per-field granularity
Priority: Must | Status: Draft | Source: D11

The layers work per field:
- **Release fields**: Album Artist, Album, Year, Compilation flag, artist folder name, release folder name, cover choice, companion include/exclude and rename.
- **Track fields**: Disc, Track, Artist, Title, file name.

### NG-LAY-004 — Track identity is the source item
Priority: Must | Status: Draft | Source: D26

A track is identified by its **source item**: one audio file, or one track of a cue sheet (for example "track 3 of `Side One.cue`"). User edits attach to the source item, not to a position in a provider tracklist.

Example:
```
Source: 01 Intro.flac, 02 Song.flac, 03 Hidden.flac
User sets the title of 03 Hidden.flac → "Hidden Track"
User switches to another Discogs candidate. "Hidden Track" is now position 1 there.
Result: 03 Hidden.flac keeps the title "Hidden Track", wherever it lands in the new order.
```

### NG-LAY-005 — Cue sheets become virtual tracks at recognize
Priority: Must | Status: Draft | Source: D16, RAW

Recognize turns a single-file + cue release into **virtual tracks**: start time, end time, title and performer from the cue. They appear as normal tracks in the Recognized layer and in the tree view (NG-REV-007). The physical split into files happens only at apply.

### NG-LAY-006 — Reset is UI-only
Priority: Must | Status: Draft | Source: D11, D73

The edit page has a "reset" action for a field and for the whole page. It restores the values the page had when it was loaded. It does not change the DB.

The user can also load another layer into the edit page: "go back to Recognized" or "go back to Proposed". The stored User values stay unchanged until the user presses Save. Save replaces them with the values on the page.

Example:
```
Stored:     Recognized "Welcom to Sky Valley", Proposed "Welcome To Sky Valley", User "Sky Valley"
Page load:  field shows "Sky Valley"
User types "Sky Valey", presses Reset        → field shows "Sky Valley", DB unchanged
User presses "go back to Recognized"         → field shows "Welcom to Sky Valley", DB unchanged
User fixes the typo and presses Save          → User = "Welcome to Sky Valley"
```

### NG-LAY-007 — "No override" is not "empty"
Priority: Must | Status: Draft | Source: D11

The User layer separates two states:
- **No override**: the user did not touch the field;
- **Override to empty**: the user deliberately cleared the field.

An empty override does not fall back to the lower layers. Validation still applies, for example an empty Year blocks apply.

### NG-LAY-008 — Stale overrides
Priority: Must | Status: Draft | Source: D11

When a re-sync or a candidate switch changes the Proposed value under a User override:
- the override stays;
- the field is marked **stale**;
- the UI shows the user value and the new proposed value side by side.

### NG-LAY-009 — Show the suggestion next to the user value
Priority: Must | Status: Draft | Source: D26

When a field has a User override, the UI shows the provider suggestion next to it, with a "use suggestion" button. On request (for example on hover or expand), the UI also shows the Recognized value.

### NG-LAY-010 — Edit at any stage, prefilled from an earlier layer
Priority: Must | Status: Draft | Source: D73

The user can edit a release at any stage: after Recognize, after Propose, or later. Save writes only to the User layer. When a field has no User value yet, its edit field is prefilled from the selected earlier layer: Proposed when it exists, else Recognized, or the layer the user chose with "go back to" (NG-LAY-006).

Example: right after Recognize, the Album field is prefilled with "Welcom to Sky Valley". The user fixes it and saves; Propose has not run.

### NG-LAY-011 — Delete my edits
Priority: Must | Status: Draft | Source: D73

The user can delete all User values of a release from the DB. The effective value (NG-LAY-002) then falls back to Proposed, else Recognized. The app asks for confirmation first.

Example: the user saved 12 track-title edits, then sees that the Discogs titles were right. "Delete my edits" removes the 12 User values; apply uses the Proposed titles.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-04 | Initial version (Docs part A). |
| 0.2 | 2026-11-04 | Phase 4, area GEN (D73): NG-LAY-006 rewritten — reset is UI-only, plus "go back to Recognized / Proposed". New NG-LAY-010 (edit at any stage, prefilled) and NG-LAY-011 (delete my edits). |
