# 91 — Suspected defects, carried forward (Phase 3)

Status: Draft | Version: 0.4 | Last updated: 2026-10-11

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

## TXT

### CF-TXT-001 — "Is romanized" accepts any non-Japanese letter, not just Latin/romanized text
Sources: `AS-CODE-DEF-003` (`AS-CODE-DEF-TXT-001` in the original per-area
numbering). No `AS-DOC` counterpart (the docs-and-tests view only noted that
"tests do not cover other scripts, for example Cyrillic" — AS-TXT-010 —
without flagging it as a defect).

`Test-ReshelfIsRomanizedText` (AS-TXT-010) does not verify the text is
actually Latin/romanized. It returns true for any non-Japanese string
containing at least one Unicode letter of any script, so pure Cyrillic,
Greek or Arabic text also counts as "romanized". This feeds directly into
`Join-ReshelfBilingualName`'s decision to join (AS-TXT-015): a non-Japanese,
non-Latin `Romanized` value could be accepted and joined as if it were a
valid romanization.

### CF-TXT-002 — A truncated segment can end up longer than the limit
Sources: `AS-DOC-DEF-012`; confirmed by `AS-CODE-TXT-024`.

When the limit is smaller than prefix + suffix, the truncation helper
(AS-TXT-038) still keeps one body character. The result is then longer than
the limit: limit 5 → `01 S.flac` (9 characters). Truncation exists to stay
within a path length limit, so exceeding it defeats the purpose.

### CF-TXT-003 — A mismatched bracket/parenthesis pair is still read as a track number
Sources: `AS-CODE-DEF-004` (`AS-CODE-DEF-TXT-002` in the original per-area
numbering). No `AS-DOC` counterpart (the docs-and-tests view had no test
covering a mismatched pair). Concerns `ConvertFrom-ReshelfTrackFileName`,
which is REC-owned content deferred to that area's merge (see the scope note
in [02-text-and-naming.md](02-text-and-naming.md)) — carried forward here
under TXT because that is where the code-phase agent filed it; cross-reference
`AS-DOC-REC-056` when REC is merged.

The bracket/paren pattern `^[\[\(](\d{1,3})[\]\)]\s*(?:[-–]\s*)?(.+)$` matches
the opening and closing delimiters independently, so a mismatched pair like
`"[01).mp3"` or `"(01].mp3"` is still accepted and yields track number `01`.

## SET

### CF-SET-001 — The `set-token` prompt doesn't say that Enter skips/clears it
Sources: `AS-CODE-DEF-005` (`AS-CODE-DEF-SET-001` in the original per-area
numbering). No `AS-DOC` counterpart (the docs-and-tests view only states the
permissive behavior itself — `AS-SET-042` — without flagging the wording
mismatch as a defect).

`Set-ReshelfDiscogsToken`'s prompt text is plain `Discogs Personal Access
Token`, with no mention that pressing Enter skips/clears it — but the code
right below silently accepts an empty entry and stores `""` anyway,
identical in effect to a "skip". The prompt wording doesn't match the
actual (permissive) behavior. Compare `Initialize-ReshelfSettings`'s token
prompt, whose wording does say "(press Enter to skip, set later with:
Reshelf.ps1 settings set-token)" — `set-token`'s own prompt doesn't carry
the same hint for itself.

### CF-SET-002 — `set-token` on a data home with no settings file silently runs full init first
Sources: `AS-CODE-DEF-006` (`AS-CODE-DEF-SET-002` in the original per-area
numbering). No `AS-DOC` counterpart (the docs-and-tests view describes
`set-token` only against an existing settings file).

Running `settings set-token` against a data home that has no `settings.json`
yet does not fail with a clear "run init first" message — it silently runs
the *entire* interactive settings-initialization flow (target root, source
root, copy mode, and a first token prompt, `AS-SET-042`) before asking for
the token a second time. This coupling is easy to trigger by accident and is
not obviously intentional.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-10 | Started. Area GEN: 1 item carried forward (`CF-GEN-001`). |
| 0.2 | 2026-10-10 | Area DAT: 5 items carried forward (`CF-DAT-001`–`005`); no duplicates found between the `AS-DOC-DEF-*` and `AS-CODE-DEF-*` sets for this area. |
| 0.3 | 2026-10-11 | Area TXT: 3 items carried forward (`CF-TXT-001`–`003`); no duplicates found between the `AS-DOC-DEF-*` and `AS-CODE-DEF-*` sets for this area. `CF-TXT-003` concerns a REC-owned function, cross-referenced for that area's merge. |
| 0.4 | 2026-10-11 | Area SET: 2 items carried forward (`CF-SET-001`–`002`); both `AS-CODE-DEF-*` only, no `AS-DOC-DEF-*` suspected defects exist for this area (only the 3 contradictions resolved in `90-contradictions-resolution.md`). |
