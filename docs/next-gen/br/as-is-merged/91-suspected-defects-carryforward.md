# 91 — Suspected defects, carried forward (Phase 3)

Status: Draft | Version: 0.2 | Last updated: 2026-10-10

Every `AS-DOC-DEF-*` and `AS-CODE-DEF-*` entry of type "Suspected defect"
(not "Contradiction" — those are resolved in
[90-contradictions-resolution.md](90-contradictions-resolution.md)),
de-duplicated and cross-referenced where both sets flagged the same issue.

**Disposition (keep / fix / drop) is deferred to phase 4** — see
[../../sessions/br-apply-ng-vision.md](../../sessions/br-apply-ng-vision.md).
Nothing here is decided yet.

Filled in area by area, alongside the area files.

## GEN

### CF-GEN-001 — Links from the review UI to Discogs and Bandcamp pages
Sources: `AS-DOC-DEF-001` (Kind: unimplemented idea). No `AS-CODE` counterpart
(nothing to find in code for a feature that was never implemented).

Plan 00 lists an idea: the review UI links to the Discogs release page (when
the exact pressing is known) or to the master release page, also in the
"ambiguous" section, and in the same way to Bandcamp. No README section, plan
file, test or code says that these links exist.

## DAT

### CF-DAT-001 — Two different editions of the same artist/album/year collide on one stable key
Sources: `AS-DOC-DEF-006`. No `AS-CODE` counterpart (this is a design-level
consequence of the stable-key formula, not a code-level bug).

The stable key uses only artist, album and year (`AS-DAT-064`).
`editionFolderName` is not an input. So two real editions — for example an
original pressing and a same-year reissue — collide on one key, even though
plan 03 says the key identifies "the same real-world release" and separately
describes the user having to manually reject one of two folders that turn
out to be different pressings. See also `CF-PRP` (when that area is merged)
for the related, opposite case: one real release getting two different
stable keys because the source folder was renamed (`AS-DOC-DEF-057`).

### CF-DAT-002 — The placeholder year 1900 is indistinguishable from a real year 1900
Sources: `AS-DOC-DEF-007`. No `AS-CODE` counterpart (the placeholder is
written by the propose step, outside this area's code source).

For an unknown year, propose writes the placeholder `1900` (the schema
minimum, see `AS-DAT-058`). `tags.year` and the lossy-tracking `year` cannot
be `null`, so a real recording from 1900 and an unresolved year look
identical in the folder name and the tags. Plan 03 notes that target
matching cannot rely on the folder name in this case.

### CF-DAT-003 — Companion file placement is schema-free text, not limited to loose/nested
Sources: `AS-DOC-DEF-008`. No `AS-CODE` counterpart (schema constraints
aren't part of the code-only source set).

Plan 03 and MANIFESTO §4.5 describe only two placements, `loose` and
`nested`, but `recognition.schema.json`'s `companionFile.placement` accepts
any non-empty string (`AS-DAT-045`). Validation would not catch a typo or a
third value.

### CF-DAT-004 — Relative-path root check is a plain string prefix match, not a folder-boundary match
Sources: `AS-CODE-DEF-001` (`AS-CODE-DEF-DAT-001` in the original per-area
numbering). No `AS-DOC` counterpart (the docs-and-tests view had no test
covering this edge case).

`Get-ReshelfRelativePath`'s "is this path under the root" check
(`AS-DAT-083`) is `$Path.StartsWith($normalizedRoot, ...)` with no check
that a path separator follows the root. A root of `C:\Music` textually
matches `C:\MusicArchive\foo.flac` too, producing a wrong "relative" result
(`Archive/foo.flac`) for a path that is not actually inside the root folder.

### CF-DAT-005 — `.alac` is classified lossless but is never found as an audio file
Sources: `AS-CODE-DEF-002` (`AS-CODE-DEF-DAT-002` in the original per-area
numbering). No `AS-DOC` counterpart (the docs-and-tests view had no test
exercising a standalone `.alac` file).

`Test-ReshelfIsLosslessFormat` treats `.alac` as lossless (`AS-DAT-078`), but
`.alac` is absent from the audio-extension list (`AS-DAT-076`) used by
`Test-ReshelfIsAudioExtension` and therefore by `Get-ReshelfAudioFilesInFolder`.
A standalone `.alac` file is never discovered as an audio file through the
normal folder-scan path, making the "lossless" classification for that
extension effectively unreachable in practice.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-10 | Started. Area GEN: 1 item carried forward (`CF-GEN-001`). |
| 0.2 | 2026-10-10 | Area DAT: 5 items carried forward (`CF-DAT-001`–`005`); no duplicates found between the `AS-DOC-DEF-*` and `AS-CODE-DEF-*` sets for this area. |
