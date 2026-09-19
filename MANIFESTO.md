# MANIFESTO — Personal Music Collection Organizer ("Tagger")

This document is meant to be the source of truth for a future planning session. It contains no implementation plan — only the goal, the rules, some thoughts, and the open questions.

## 1. Problem

I have a large, messy pile of music folders and files ("music collection")
that I want to organize into a consistent structure, release by release.

My current collection has no guaranteed system I can rely on as a pattern
for finding releases (going forward, "release" is the key unit I care
about). I originally tried to organize it like this:

- Root folder (`music`)
  - Genre folder (`pop rock`, `industrial`, `idm`, `post metal`, ...)
    - Main artist folder (`Metallica`, `Imelda May`, `Cranberries`, ...)
      - Release folder (`yyyy - Release Name`)
        - Media files (`flac`, `mp3`, `alac`, ...) named `NN - Track Name.ext`
        - Extra materials (booklet scans, cover images, lyrics, artist
          articles) — sometimes directly in the release folder, sometimes
          in a nested subfolder

But actually following this structure is a different story. Known
inconsistencies:

- Some filenames have no track number and/or no `-` separator.
- Sometimes there's a "grouping" folder instead of a real main-artist
  folder — e.g. "Godspeeds and their projects" containing subfolders for
  "Godspeed You! Black Emperor", "Silver Mountain Zion", etc.
- Sometimes inside a main-artist folder there are subfolders like `EPs`,
  `Singles`, `Lives`, and the corresponding releases live inside those
  instead of directly under the artist.
- Sometimes inside a band's folder there are also folders for individual
  band members (treated as their own main artist), containing their solo
  releases — e.g. a `David Byrne` folder inside `Talking Heads`.
- This is only the relatively logical part of the chaos I can remember —
  there could be other patterns I'm not even aware of.
- On top of folder/file nesting problems: media file metadata has no
  consistent pattern either, and is often missing or wrong.

## 2. Core Idea

Focus reorganization on two concepts: **Main Artist** (band or performer
name) and **Release** (album, single, maxi-single, etc.).

The human eye can already recognize a "release" while browsing the current
messy structure in almost any file explorer or player, using simple visual
cues:
- A folder whose name looks like a release name (maybe with a year).
- Inside it, media files whose names look like track names, usually with
  sequential numbering.
- Other files/folders inside are recognized by name/type: lyrics, articles,
  cover scans, etc.
- Multiple physical discs are recognized by subfolders like `CD 1`, `CD 2`.

## 3. Goal

Reorganize the storage into a clean, consistent structure (defined below).

**This is not a one-time operation — it's an ongoing process.** First,
organize everything already on disk. After that, the collection keeps
growing from various sources: phone storage, `Downloads` folders on
different devices connected to the PC, various folders on USB flash
drives. So the tool must be runnable repeatedly, each time pointed at a
different source folder.

Example CLI usage (pseudo):
- `/run` — organizes music from the default source directory.
- `/run c:\downloads\folder` — organizes music from the given source
  directory instead.

## 4. Target Storage Structure

### 4.1 Root

Storage starts at some root directory on disk (a new root, separate from
today's messy `music` folder).

### 4.2 Level 1 — Main Artist

The root directory contains **only** main-artist folders. No genre layer.

- Format: `Main Artist Name`
- Examples: `Imelda May`, `Metallica`, `Talking Heads`, `David Byrne`,
  `Cranberries`, `Dolores O'Riordan`

### 4.3 Level 2 — Release

Inside an artist folder are release folders: album (LP), EP, SP, single,
maxi single.

- The **album** is the primary unit, since singles can always be found
  inside their albums.
- If a single exists but its album doesn't, the album is most likely just
  not released yet — but presumably will be eventually.
- Format: `yyyy The Album Name`

Example — artist `ZZ Top`:
```
2012 La Futura
2003 Mescalero
1999 XXX
```

### 4.4 Level 3 — Media Files (Tracks)

- Format: `NN The Track Name` (plus file extension)

Example — album `1999 XXX` by `ZZ Top`:
```
01 Poke Chop Sandwich.flac
02 Crucifixx A Flatt.flac
...
```
Note: filename can contain featured artists, mix/remix word, and other related things after the actual name.

**Multi-disc releases:** track numbers in the filename keep counting up
across discs (they do not restart per disc). Example — a 2-CD release,
2 tracks on disc 1 and 3 tracks on disc 2:
```
01 Track One.mp3    (from CD 1)
02 Track Two.mp3    (from CD 1)
03 Track One.mp3    (from CD 2)
04 Track Two.mp3    (from CD 2)
05 Track Three.mp3  (from CD 2)
```

**Single file + cue sheet:** if a release's tracks exist as one big media
file plus a `.cue` sheet (timestamps + track names), the media file must be
split into separate track files, and the `.cue` file must be deleted
afterward.

**No playlist files** are allowed in the final structure.

### 4.5 Companion / Extra Materials

Inside a release folder, besides media files, there can be extra material:
cover scans, lyrics, artist photos, etc. Two allowed placements:

1. In a nested subfolder inside the release folder, **or**
2. Directly in the release folder next to the media files — in this case,
   their filenames must start with a **letter**, not a digit, so that
   normal alphabetical sorting in a file explorer always puts tracks
   first.

Which placement is used depends on how the material was organized in the
original source directory being imported from.

We don't care about genres anymore. Not in folders, not in metadata.

## 5. Metadata Rules (critical section)

- **Disc Number** — always set, even for single-disc releases. Numbering
  starts at 1 (not `01`).
- **Track** — the track's number on its disc. Numbering restarts at 1 for
  each disc, and has **no leading zero** (unlike the `NN` in the filename,
  which does have a leading zero and keeps counting across discs — see
  §4.4). Example, a release on 3 discs with 2 tracks each:

  | File Name             | Disc Number | Track | Title        |
  |-----------------------|:-----------:|:-----:|--------------|
  | 01 First Track.flac   | 1           | 1     | First Track  |
  | 02 Second Track.flac  | 1           | 2     | Second Track |
  | 03 Third Track.flac   | 2           | 1     | Third Track  |
  | 04 Fourth Track.flac  | 2           | 2     | Fourth Track |
  | 05 Fifth Track.flac   | 3           | 1     | Fifth Track  |
  | 06 Sixth Track.flac   | 3           | 2     | Sixth Track  |

- **Artist** and **Album Artist** — both required, and must have the
  **exact same value**. Reason: some players read/display these two tags
  differently, and sometimes don't show one of them at all. Since a
  release folder lives inside its artist's folder, both tags must match
  the artist folder's name.
- **feat. artists** — only mentioned in the track title, in both the
  filename and the `Title` tag. Never added to `Artist`/`Album Artist`.
  Reason: `Metallica` and `Metallica feat. Justin Bieber` can and will be read
  by some players as 2 different artists, which will break scanned library.
  So once I want to play "that Metallica's album" which originally contains
  12 tracks, player will play 11 track album instead thinking that that one song
  with the featured artist is the separate album from another artist.
- **Title** — the track name, i.e. the filename's `NN The Track Name` part
  minus the `NN ` prefix.
- **Cover art** — embedded in every media file, image no larger than
  600×600 px.
- **Year** and **Album** tags — required, and must match the release
  folder name, which is always `yyyy The Album Name`. Example: album `XXX`
  by ZZ Top, released 1999, folder `1999 XXX` → `Year = 1999`,
  `Album = XXX`.
- **Filename** — format `NN The Track Name.extension` (track name
  includes any feat. artists, mix, remix, remaster and other words).
- **Source of truth** for all of the above metadata, including cover art,
  as well as Release (folder) names and Track (file) names, is **Discogs**.

## 6. Additional Feature — Lossy/Lossless Tracking

If a release's media files are in a lossy format (e.g. mp3) instead of
lossless (e.g. flac), that release must be logged in a separate tracking
file, so it can later be found and upgraded (lossy replaced with
lossless).

## 7. Proposed Process / Module Breakdown

The process should be split into independently developed modules:

1. **Settings module**
   - Default source and target folders paths storing — empty initially; user is asked for it on
     first run; can also be overridden by passing a path as a run
     parameter.
   - Templates for folder names, file names, and metadata fields (the
     rules from §4 and §5), with their placeholder values.
   - Edit mode: copy or move source files. Default: copy.
   - Some way to persist sessions, so the editing process can be resumed
     later.

2. **Reading & Recognition module**
   - Builds a full map of directories, subdirectories, and files under
     the source folder.
   - Recognizes release folders.
   - Recognize additional materials (scans, covers, texts). We need to see them in Editing module, so they can be (should be) renamed according to `4.5 Companion / Extra Materials` expectations.
   - Reads media files metadata.
   - Outputs a document (e.g. JSON) listing everything found, grouped by
     artist → releases, including full file paths.

3. **Edit Proposal module**
   - Reads the document produced by module 2.
   - Produces a new document proposing changes to folder names, file
     names, and metadata (including cover art) according to the
     configured templates.
   - First looks up the identified release on **Discogs** (source of
     truth), including offering multiple candidate cover images to choose
     from — since it's often unclear which release edition the files
     actually are (e.g. Japanese vs. German pressing), and image quality
     varies between editions.
   - Output: a document similar to module 2's, but with proposed changes
     attached (i.e. "before" state + proposed "after" state).
   - This should manage lossy/lossless tracking suggestions too.
     Maybe I brought lossless release into "source" folder while there is
     a lossy release in the "target" folder, so it should be replaced.

4. **Editing module**
   - Opens module 3's document in a UI editor.
   - Displays music in a convenient "before" → "after" view.
   - Allows manual adjustments when something isn't right.
   - Saves changes back into the same document.

5. **Implementation module**
   - Applies the approved changes to real files: copies each release from
     its source folder into the destination folder (splitting single-file albums by cue at the same time) with the correct nesting and names, edits metadata, then moves on to the next release,
     repeating until all releases are processed.
   - Add to lossy/lossless tracking file 

## 8. Tooling Philosophy

- Prefer well-established, lightweight existing tools over building new
  ones from scratch.
- Likely shape: a set of **PowerShell scripts**, one per module, each
  calling out to appropriate CLI tools (e.g. a CLI metadata tagger).
- UI: a **static website** (no server/backend), plain HTML with minimal
  JS. Open question: how to implement editing (module 4) on a purely
  static site.
- Final product = scripts + JSON documents + HTML/JS files.
- For steps that seem hard to fully automate (e.g. recognizing releases
  reliably), human involvement or AI assistance is expected. Where full
  automation isn't realistic — or as an enhancement to automated steps —
  the plan is to use AI tooling in the form of general-purpose "skills"
  usable across AI assistants (Claude, Antigravity, etc.), rather than
  building a custom automation for that step. But always prefer scripts.

## 9. Open Questions for the Next Planning Session

These were not fully specified in the original brainstorm and should be
clarified before building a concrete plan:

- How should the static-site UI actually implement editing and persist
  changes (module 4), given there's no server?
- What Discogs integration approach should be used (API access, auth,
  rate limits, matching confidence when multiple candidate releases are
  found)?
- How are re-runs handled — e.g. avoiding reprocessing releases already
  present in the destination, detecting duplicates, or updating a release
  that's already there?
- How should conflicts/edge cases be handled: same release imported
  twice from different sources, Windows path-length limits, invalid
  filename characters, ambiguous or unrecognizable release folders that
  don't fit any known pattern?
- What exactly gets persisted in a "session" (module 1) and how is
  resuming a session supposed to work end to end?
- Which CLI metadata tagging tool(s) are acceptable/preferred (e.g.
  `mp3tag`, `metaflac`, other taggers with a CLI/CLI-scriptable mode)?
