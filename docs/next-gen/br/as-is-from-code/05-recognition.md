# Recognition — as-is from code (REC)

Status: Draft | Version: 0.1 | Last updated: 2026-10-10

### AS-CODE-REC-001 — Disc-folder name pattern
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:10 › Test-IsDiscFolder

A folder name is recognized as a disc folder when it starts (case-insensitive) with "CD", "Disc", "Disk", or "LP", followed by optional spaces/underscores, an optional "#", an optional ".", optional more spaces/underscores, then one or more digits, and then either a space, underscore, period, hyphen, or the end of the string.

Example: "CD1", "Disc 02", "LP_3", "CD #1" all match. "CD10xyz" does not match, because the digits are not followed by a separator or end of string.

### AS-CODE-REC-002 — Disc number extraction
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:21 › Get-ReshelfDiscNumber

A disc folder's number is the digit group captured by the same pattern as AS-CODE-REC-001. If the name does not match the pattern, no number is returned.

Example: "Disc 02" → disc number 2.

### AS-CODE-REC-003 — Disc folder discovery is one level deep, non-recursive
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:34 › Get-ReshelfDiscFolders

Disc folders are found by scanning only the immediate subfolders of a given folder (not recursively) and keeping those whose name matches the disc-folder pattern. A folder that can't be listed (e.g. inaccessible) is treated as having no subfolders rather than erroring.

### AS-CODE-REC-004 — Disc folders are returned sorted by disc number
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:34 › Get-ReshelfDiscFolders

The disc folders found are sorted ascending by their extracted disc number before being returned.

### AS-CODE-REC-005 — Release folder: direct audio makes it a release
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:52 › Test-IsReleaseFolder

A folder is a release folder if it directly contains at least one audio file (not counting files in subfolders).

### AS-CODE-REC-006 — Release folder: no subfolders and no direct audio means not a release
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:52 › Test-IsReleaseFolder

If a folder has no direct audio files and no subfolders at all, it is not a release folder.

### AS-CODE-REC-007 — Release folder: disc subfolders with audio also qualify
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:52 › Test-IsReleaseFolder

If a folder has no direct audio files but has subfolders, it is still a release folder if at least one of its disc folders (named like "CD1"/"Disc 2"/etc., see AS-CODE-REC-001) directly contains at least one audio file. A folder with subfolders but no disc-named subfolders at all is not a release folder by this rule.

### AS-CODE-REC-008 — Category subfolder names are a fixed list, matched case-insensitively
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:83 › Test-IsCategorySubfolder

A folder name is a "category" folder if it case-insensitively equals one of a fixed set of names: EPs, Singles, Lives, Live, Compilations, Bootlegs.

### AS-CODE-REC-009 — Album-wrapper folder requires a leading year in its own name
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:96 › Test-IsAlbumWrapperFolder

A folder can only be an "album-wrapper" (a release-looking folder that wraps edition/pressing subfolders instead of holding tracks directly) if its own leaf name starts with a parseable leading year (see AS-CODE-REC-039–042). Without a leading year, it is never an album-wrapper.

Example: "1975 - T.N.T. (Australian Release)" containing a subfolder "1989 Australia Albert 465262 2" with the actual tracks.

### AS-CODE-REC-010 — Album-wrapper folder must have no direct audio
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:96 › Test-IsAlbumWrapperFolder

A folder with any direct audio files is never classified as an album-wrapper (it is handled by the plain release-folder rule instead).

### AS-CODE-REC-011 — Album-wrapper folder needs at least one release-folder subfolder
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:96 › Test-IsAlbumWrapperFolder

At least one immediate subfolder must itself qualify as a release folder (AS-CODE-REC-005–007); otherwise the folder is not an album-wrapper.

### AS-CODE-REC-012 — Album-wrapper folder: every non-release subfolder must have zero audio anywhere below it
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:96 › Test-IsAlbumWrapperFolder

Every immediate subfolder that does not itself qualify as a release folder must contain zero audio files anywhere underneath it (checked recursively). If any non-release subfolder has audio hiding somewhere below it, the folder is not treated as an album-wrapper (there is an unknown layer of nesting, e.g. a real band-member folder, that must not be silently swallowed as "just another edition").

### AS-CODE-REC-013 — Grouping folder must have zero direct files
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:138 › Test-IsGroupingFolder

A folder with any direct files (of any kind) is never classified as a grouping folder.

### AS-CODE-REC-014 — Grouping folder needs at least 2 subfolders
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:138 › Test-IsGroupingFolder

A folder with fewer than 2 immediate subfolders is never classified as a grouping folder.

### AS-CODE-REC-015 — Grouping folder: no subfolder may itself look like a release, disc, category, or album-wrapper folder
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:138 › Test-IsGroupingFolder

If any immediate subfolder is a release folder, a disc folder (by name), a category subfolder (by name), or an album-wrapper folder, the folder is not classified as a grouping folder.

### AS-CODE-REC-016 — Grouping folder exception: subfolders' own releases matching the grouping folder's own name
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:138 › Test-IsGroupingFolder

Even when AS-CODE-REC-013–015 all pass, the folder is NOT a grouping folder if: release folders exist two levels down (inside its subfolders), and the release-level artist/performer metadata of those releases confirms (majority agreement, see AS-CODE-REC-024) that the grouping folder's own leaf name is the actual artist. In that case it is treated as a single artist with category-like subfolders instead of a grouping of unrelated artists.

Example: "Iron Maiden\{Studio Albums, Compilation Albums}\<releases>" — structurally looks like a grouping folder, but every release's metadata artist is "Iron Maiden" (matching the folder's own name), so it is not treated as a grouping.

### AS-CODE-REC-017 — Band-member folder: name must differ from the parent artist's name
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:179 › Test-IsBandMemberFolder

A subfolder whose (normalized) name equals the (normalized) parent artist name is never classified as a band-member folder.

### AS-CODE-REC-018 — Band-member folder: name must not be a category name
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:179 › Test-IsBandMemberFolder

A subfolder whose name matches the fixed category-folder-name list (AS-CODE-REC-008) is never classified as a band-member folder.

### AS-CODE-REC-019 — Band-member folder must have no direct files
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:179 › Test-IsBandMemberFolder

A folder with any direct file (audio or not) sitting loose inside it is never classified as a band-member folder — a genuine band-member wrapper is expected to be a pure container; any loose file is treated as messiness that should go to human review instead of being auto-classified.

### AS-CODE-REC-020 — Band-member folder needs at least one release-folder subfolder
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:179 › Test-IsBandMemberFolder

At least one immediate subfolder must qualify as a release folder; otherwise the folder is not a band-member folder.

### AS-CODE-REC-021 — Band-member folder exception: subfolders' releases confirm the parent artist instead
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:179 › Test-IsBandMemberFolder

Even when AS-CODE-REC-017–020 all pass, the folder is NOT a band-member folder if the release-level metadata of its release subfolders confirms (majority agreement) the PARENT artist name rather than a distinct performer. In that case it is treated as a category folder in disguise (e.g. "Studio Albums"), not a separate band member.

Example (illustration): "Talking Heads\David Byrne\<releases>" is a real band-member folder because the releases' metadata artist is "David Byrne", not "Talking Heads".

### AS-CODE-REC-022 — Release-folder metadata artist: cue PERFORMER takes priority over tags
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:223 › Get-ReshelfReleaseFolderMetadataArtist

To determine the "metadata artist" of a release folder, the first audio file found anywhere below the folder is used. If one or more .cue files sit alongside that audio file and one resolves to it, and that cue's disc-level header has a PERFORMER, that PERFORMER is returned as the metadata artist (checked and returned before ever looking at audio tags), because a cue's PERFORMER is release-level while per-track tags on such rips are often empty.

### AS-CODE-REC-023 — Release-folder metadata artist: falls back to the first audio file's own Artist tag
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:223 › Get-ReshelfReleaseFolderMetadataArtist

If no cue PERFORMER is found, the Artist tag of the first audio file is used instead. If the file can't be read for tags at all, or no audio file exists under the folder, or neither signal is present, the metadata artist is null — treated by callers the same as "this folder has nothing to say about its artist", not as a recognition failure.

### AS-CODE-REC-024 — Metadata confirms artist: majority vote among release folders with available metadata
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:257 › Test-ReshelfMetadataConfirmsArtist

Given a set of release folder paths and a target artist name, each folder's metadata artist (AS-CODE-REC-022/023) is compared (case/whitespace-normalized) against the target. If none of the folders produced a metadata artist at all, the result is "not confirmed". Otherwise the result is "confirmed" only if STRICTLY MORE than half (> 0.5, not >=) of the folders that did produce a metadata artist match the target.

Example: 1 match out of 2 folders with metadata → 0.5, not strictly greater than 0.5 → not confirmed.

### AS-CODE-REC-025 — Track ordering: all-numbered files sort by their parsed number
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:288 › Get-ReshelfTrackOrder

Each audio file name is parsed for a track number and title. If every file in the set has a parsed track number, the files are sorted by that number and each keeps its parsed number/title, with no order inferred.

### AS-CODE-REC-026 — Track ordering: any unnumbered file forces alphabetical fallback for the whole set
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:288 › Get-ReshelfTrackOrder

If even one file in the set has no parsed track number, every file in the set (including ones that did parse a number) is instead sorted alphabetically by file name and renumbered sequentially starting at 1, with every file in the set marked as having an inferred order — individually-parsed numbers are discarded in this case.

### AS-CODE-REC-027 — Cue-for-audio resolution: no cue files means no match
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:321 › Get-ReshelfCueSheetPathForAudio

If zero .cue files are given, the result is no match (null).

### AS-CODE-REC-028 — Cue-for-audio resolution: a single cue file always matches
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:321 › Get-ReshelfCueSheetPathForAudio

If exactly one .cue file is given, it is returned unconditionally — its name is not checked against the audio file at all.

### AS-CODE-REC-029 — Cue-for-audio resolution with multiple cues: exact-name match tried first
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:321 › Get-ReshelfCueSheetPathForAudio

When more than one .cue file is present, the first rule tried is an exact-name match: a cue file whose name case-insensitively equals "<audio file name>.cue" (e.g. "Album.flac.cue" for "Album.flac"). If exactly one cue file matches this rule, it is returned.

### AS-CODE-REC-030 — Cue-for-audio resolution with multiple cues: basename match tried second
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:321 › Get-ReshelfCueSheetPathForAudio

If the exact-name rule (AS-CODE-REC-029) did not yield exactly one match, a second rule is tried: a cue file whose base name (without extension) case-insensitively equals the audio file's base name (without extension). If exactly one cue file matches, it is returned. If neither rule yields exactly one match (zero, or more than one, under either rule independently), the result is no match (null). The two rules are tried in this priority order, not merged into a single combined set.

Example: "Album.ape.cue" (exact-name form) and "Album.cue" (basename form) both naming the same present "Album.ape" — this still resolves to one cue (the exact-name match wins), rather than bailing out just because two cue files overall "match something".

### AS-CODE-REC-031 — Cue-sheet release detection requires exactly one audio file plus a resolvable cue
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:351 › Test-IsCueSheetRelease

A folder is treated as a single-file cue-sheet release only if it has EXACTLY one audio file (not zero, not two or more) and that one file resolves to a cue sheet (AS-CODE-REC-027–030).

### AS-CODE-REC-032 — Flat multi-disc cue pairing requires at least 2 audio files
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:367 › Get-ReshelfFlatDiscCuePairs

A release folder is only considered for "flat" multi-disc/cue pairing (whole-disc images with their own cue sitting side by side, with no "CD 1"/"CD 2" subfolders) if it has at least 2 direct audio files. With fewer, no pairs are returned.

Example: "1996 - Best Of The Beast (TOCP-50128-9)" — two whole-CD images, each with its own cue, sitting directly in the release folder.

### AS-CODE-REC-033 — Flat multi-disc cue pairing requires every audio file to resolve to its own distinct cue
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:367 › Get-ReshelfFlatDiscCuePairs

Every audio file in the folder must resolve to a cue sheet (AS-CODE-REC-027–030), and no two audio files may resolve to the same cue file. If any audio file fails to resolve a cue, or two audio files share a cue, the whole operation returns no pairs at all (not a partial result).

### AS-CODE-REC-034 — Flat multi-disc cue pairing: sort by cue DISCNUMBER when every pair has one
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:367 › Get-ReshelfFlatDiscCuePairs

If every audio/cue pair's cue header carries a DISCNUMBER, the pairs are sorted ascending by that disc number (ties broken by audio file name).

### AS-CODE-REC-035 — Flat multi-disc cue pairing: catalog-number-in-folder-name heuristic when disc numbers are missing
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:367 › Get-ReshelfFlatDiscCuePairs

If at least one pair's cue is missing a DISCNUMBER, the pairs are instead sorted using this heuristic: for each pair, extract the text inside the LAST trailing parenthesized group of the audio file's base name; if that extracted text appears (case-insensitive, substring) inside the release folder's own name, the pair sorts first; otherwise it sorts after. Ties are broken by audio file name.

Example: release folder "...(TOCP-50128-9)" with audio files whose names end in "(TOCP-50128)" and "(TOCP-50129)" — the folder name contains both catalog fragments, so this heuristic can't fully distinguish by containment alone, but any pair whose own fragment text is found inside the folder name is still ranked ahead of one that isn't.

### AS-CODE-REC-036 — Cue text decoding: trusted UTF-8 BOM
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:411 › ConvertFrom-ReshelfCueSheetText

If the cue file's bytes start with a UTF-8 byte-order mark (EF BB BF), the remaining bytes are decoded as UTF-8 and the BOM bytes are dropped. This is trusted without further checks.

### AS-CODE-REC-037 — Cue text decoding: strict UTF-8 with Windows-1252 fallback
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:411 › ConvertFrom-ReshelfCueSheetText

Without a BOM, the bytes are first decoded as strict UTF-8 (any invalid byte sequence throws, rather than silently substituting a replacement character). If that decoding throws, the bytes are instead decoded using the Windows-1252 codepage (the common case for cue sheets ripped on Windows with accented letters such as a German u-umlaut). Plain-ASCII cue sheets decode identically either way.

### AS-CODE-REC-038 — Cue sheet track parsing: TRACK/TITLE/INDEX 01 state machine
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:440 › ConvertFrom-ReshelfCueSheet

Cue text is split into lines (on CRLF, CR, or LF) and scanned line by line (each line trimmed first). A line matching `TRACK <n> AUDIO` opens a pending track with that number and clears any pending title. While a track is pending, a line matching `TITLE "<text>"` sets its title. While a track is pending, a line matching `INDEX 01 <hh:mm:ss>` commits the track with its number, title (defaulting to "Track <n>" if no TITLE line was seen), and that timestamp, then clears the pending state. Any other INDEX line (e.g. INDEX 00, the pregap) is ignored — only INDEX 01 commits a track. If reading or decoding the file throws, or if zero tracks were found, the result is null (unparseable). Otherwise the committed tracks are returned sorted by track number.

### AS-CODE-REC-039 — Cue sheet header: only lines before the first TRACK line count
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:485 › Get-ReshelfCueSheetHeader

Header scanning stops as soon as the first line matching `TRACK <n>` is reached. A PERFORMER or REM DISCNUMBER line appearing inside a TRACK block (i.e., after the first TRACK line) is never read as header data — a PERFORMER inside a TRACK block describes just that one track (which can differ on a compilation), not the whole disc.

### AS-CODE-REC-040 — Cue sheet header: PERFORMER and REM DISCNUMBER extraction
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:485 › Get-ReshelfCueSheetHeader

Within the header area (AS-CODE-REC-039), a `PERFORMER "<text>"` line with non-blank content sets the header Performer (trimmed); if more than one such line appears before the first TRACK line, the last one read wins. A `REM DISCNUMBER <digits>` line (digits optionally wrapped in quotes) sets the header DiscNumber. Either value can end up null if its line never appears. If reading or decoding the file throws, the whole header result is null.

### AS-CODE-REC-041 — Cue virtual tracks: unreadable audio properties flag for review
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:520 › New-ReshelfCueVirtualTracks

Before splitting, the audio file's own tags/properties are read. If its properties could not be read, the whole cue-track result is flagged needing review with reason "audio-properties-unreadable".

### AS-CODE-REC-042 — Cue virtual tracks: .ape source is reported as splitting to .flac
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:520 › New-ReshelfCueVirtualTracks

If the source audio file's format is "ape", the virtual tracks' reported format is "flac" instead (because the splitting tool has no APE encoder/muxer and always re-encodes an .ape split to .flac, while remaining fully lossless — the isLossless flag is untouched). For every other format, the virtual tracks' format matches the source format unchanged.

### AS-CODE-REC-043 — Cue virtual tracks: unparseable cue falls back to one whole-file track
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:520 › New-ReshelfCueVirtualTracks

If the cue sheet itself can't be parsed (AS-CODE-REC-038 returns null), exactly one virtual track is produced representing the entire audio file: track number 1 in its disc, inferred order = true, cue timestamp "00:00:00", title/artist/album taken from the audio file's own tags, and the release is flagged needing review with reason "unparseable-cue-sheet".

### AS-CODE-REC-044 — Cue virtual tracks: per-track duration is the gap to the next track's start
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:520 › New-ReshelfCueVirtualTracks

When the cue parses successfully, each track's duration is computed as the time between its own INDEX 01 timestamp and the NEXT track's INDEX 01 timestamp; for the last track, the gap is to the whole audio file's total duration instead. The duration is rounded to 3 decimal places. Each track's title comes from the cue (or its "Track <n>" default); its artist/album come from the whole audio file's own tags, not from the cue.

### AS-CODE-REC-045 — Companion kind for images: "photo" and "booklet" keyword priority, else "cover"
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:606 › Resolve-ReshelfCompanionKind

For a file with an image extension (.jpg, .jpeg, .png, .bmp, .gif, .tiff, .webp), the file name (lowercased) is checked first for the substring "photo" (kind = "photo"); if not found, then for "booklet", "back", or "insert" (kind = "booklet"); if none of those match, the kind defaults to "cover". The "photo" check is checked before the "booklet"/"back"/"insert" check.

### AS-CODE-REC-046 — Companion kind for text-like files: "lyrics" keyword, else "other"
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:606 › Resolve-ReshelfCompanionKind

For a file with extension .txt, .pdf, or .nfo, the name (lowercased) is checked for the substring "lyrics" (kind = "lyrics"); otherwise kind = "other". Any other extension (including no extension at all) is always kind "other".

### AS-CODE-REC-047 — Companion files: audio files are excluded, scanned recursively
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:637 › Get-ReshelfCompanionFiles

All files anywhere under the release folder (recursive, any depth, including inside disc subfolders) are scanned. Files recognized as audio are skipped entirely here (they are tracks, handled elsewhere), regardless of which subfolder they sit in.

### AS-CODE-REC-048 — Companion files: used cue sheets are silent, unused ones are "ignored"
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:637 › Get-ReshelfCompanionFiles

A .cue file whose full path is among the cue sheets actually used for track-splitting is skipped silently (neither a companion nor an ignored file). Any other .cue file is recorded in the "ignored" list with reason "cue-sheet-not-used" — it is never silently dropped.

### AS-CODE-REC-049 — Companion files: playlist files are always "ignored"
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:637 › Get-ReshelfCompanionFiles

Files with extension .m3u, .m3u8, or .pls are recorded in the "ignored" list with reason "playlist-file".

### AS-CODE-REC-050 — Companion files: placement is "loose" at the release root, "nested" elsewhere
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:637 › Get-ReshelfCompanionFiles

Any remaining file (not audio, not .cue, not a playlist extension) is recorded as a companion with its kind (AS-CODE-REC-045/046) and a placement: "loose" if the file sits directly in the release folder itself, "nested" if it sits in any subfolder (e.g. a disc folder).

### AS-CODE-REC-051 — Embedded cover caching: empty picture data yields no cache file
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:685 › Save-ReshelfEmbeddedCoverToCache

If the embedded picture has no bytes (null or zero-length), no file is written and null is returned.

### AS-CODE-REC-052 — Embedded cover caching: content-addressed by SHA-256 hash, extension from MIME type
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:685 › Save-ReshelfEmbeddedCoverToCache

The cache file name is the lowercase hex SHA-256 hash of the picture's bytes, so identical cover images always map to the same cache file regardless of which track they came from. The extension is ".png" for MIME type "image/png", ".jpg" for "image/jpeg", and ".jpg" for any other MIME type (default).

### AS-CODE-REC-053 — Embedded cover caching: existing cache file is reused, not overwritten
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:685 › Save-ReshelfEmbeddedCoverToCache

The cache file is written under "<data home>/embedded-covers/". If a file with the computed hash+extension name already exists there, it is reused as-is and not rewritten; otherwise it is written.

### AS-CODE-REC-054 — Audio tag reading: corrupt-properties fallback to tag-only read
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:725 › Get-ReshelfAudioTags

Opening the audio file is first attempted normally. If that specifically throws a "corrupt file" exception, the file is reopened in a tag-only mode that skips parsing audio properties entirely, and the result is flagged "PropertiesUnavailable". This recovers tag data from files that carry something the properties parser for their format doesn't expect (e.g. an ID3v2 tag prepended to a .mpc file) instead of failing the whole file. Any other kind of exception from the first open attempt is not caught here and propagates to the caller.

### AS-CODE-REC-055 — Audio tag reading: Artist/Album/Title fall back to null when blank
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:725 › Get-ReshelfAudioTags

Artist is the file's first performer tag, or null if blank. Album is the Album tag, or null if blank. Title is the Title tag, or null if blank. Format is the file's extension without the leading dot, lowercased. DurationSeconds is 0.0 when properties could not be read (AS-CODE-REC-054), otherwise the actual parsed duration in seconds.

### AS-CODE-REC-056 — Audio tag reading: embedded cover picks FrontCover, else the first picture
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:725 › Get-ReshelfAudioTags

If the file has one or more embedded pictures, the picture whose type is FrontCover is preferred; if none is marked FrontCover, the first picture in the file's list is used instead. The chosen picture is then cached to disk (AS-CODE-REC-051–053). If the file has no embedded pictures, the cover path is null.

### AS-CODE-REC-057 — Artist/album from track tags: requires at least one audio file
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:783 › Resolve-ReshelfArtistAlbumFromTags

A folder with zero direct audio files yields no artist/album guess from tags (null).

Example: a folder "edbl" containing "edbl - edbl minibeats, vol.1 - 01 ....flac" with no artist-name wrapper folder — the folder itself has no name-based artist, but this function can still promote it based on tags.

### AS-CODE-REC-058 — Artist/album from track tags: every track must agree, or the result is discarded entirely
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:783 › Resolve-ReshelfArtistAlbumFromTags

If any audio file is missing either its Artist or Album tag, the whole result is null. Otherwise, the first file's Artist/Album (normalized) become the baseline, and if any other file's normalized Artist or Album differs from that baseline, the whole result is null. Only when every single track agrees is the common Artist/Album pair returned — even one outlier track blocks the promotion (nothing ambiguous is auto-guessed).

### AS-CODE-REC-059 — Folder-kind resolution priority: category beats everything when inside an artist-like context
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:821 › Resolve-ReshelfFolderKind

When the current walk context is ArtistBody, CategoryBody, or BandMemberBody (i.e., we are already inside something artist-like), a child folder whose name matches the category-name list (AS-CODE-REC-008) is classified "category" before any other check runs, regardless of what else that folder might structurally look like.

### AS-CODE-REC-060 — Folder-kind resolution priority: release, then album-wrapper, then band-member, then grouping
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:821 › Resolve-ReshelfFolderKind

After the category check (AS-CODE-REC-059), the folder is classified "release" if it is a release folder; else "album-wrapper" if it qualifies as one; else "band-member" if we're in an artist-like context, an artist name is already known, and it qualifies as a band-member folder; else "grouping" if it qualifies as a grouping folder. Each check is only reached if all earlier ones failed.

### AS-CODE-REC-061 — Folder-kind resolution: no audio anywhere means "unrecognized"
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:821 › Resolve-ReshelfFolderKind

If none of the specific shapes (AS-CODE-REC-059/060) match and the folder has zero audio files anywhere below it (recursive), it is classified "unrecognized" with reason "no-audio-files".

### AS-CODE-REC-062 — Folder-kind resolution: anything else with audio below it is a transparent "pass-through" layer
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:821 › Resolve-ReshelfFolderKind

If the folder doesn't match any specific shape but does have audio somewhere below it, it is classified "pass-through" — a transparent nesting layer to keep walking through. Direct non-audio files sitting in such a folder (discography notes, cover art, Thumbs.db, playlists, etc.) are implicitly ignored rather than blocking recognition, since any folder with a direct audio file would already have been claimed as "release" earlier.

### AS-CODE-REC-063 — Folder-kind resolution: at the scan root, a pass-through folder's own name becomes the artist name
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:821 › Resolve-ReshelfFolderKind

When a pass-through folder (AS-CODE-REC-062) is found directly at the walk's Root context, its own leaf name is proposed as the new artist name for everything found inside it. At any other (non-Root) context, a pass-through folder does not introduce a new artist name — whatever artist name was already in effect continues to apply.

### AS-CODE-REC-064 — Unrecognized entries carry path, reason, and direct children
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:878 › New-ReshelfUnrecognizedEntry

Every unrecognized-folder entry records the folder's path, a reason code, and the list of names of files/folders directly inside it (for human triage), defaulting to an empty list if none are given.

### AS-CODE-REC-065 — Inherited review reasons force needsReview and are merged in, de-duplicated
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:893 › Add-ReshelfInheritedReviewReasons

If a release is given one or more inherited review reasons (reasons that apply because an ancestor folder in the walk was already auto-classified), its needsReview flag is forced to true and those reasons are appended to its review-reasons list, with duplicates removed. If no inherited reasons are given, the release is returned unchanged.

### AS-CODE-REC-066 — Artist bucketing: grouping key is case/whitespace-normalized, but the first-seen spelling is kept as the display name
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:914 › Merge-ReshelfArtistBucket

Releases are grouped into artist "buckets" keyed by a normalized form of the artist name (so differently-cased or whitespace-variant spellings of the same artist merge into one bucket). The bucket's displayed "recognizedName" is set once, from the FIRST release that creates the bucket, and is never updated by later releases that match the same normalized key under a different spelling.

### AS-CODE-REC-067 — Artist bucketing: source paths are de-duplicated, releases are not
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:914 › Merge-ReshelfArtistBucket

Each artist bucket keeps a list of distinct source folder-parent paths (a path already present is not added again) and a flat list of every release merged into it (releases are always appended, never deduplicated).

### AS-CODE-REC-068 — Leading-year split: full release-date form ("yyyy.mm.dd" / "yyyy-mm-dd")
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:947 › Split-ReshelfLeadingYear

If the folder name starts with a 4-digit year, a separator (. or -), a 2-digit month, the same kind of separator, and a 2-digit day, followed by either a dash/en-dash (optionally surrounded by spaces) or at least one space, and then the rest of the text: this is parsed as a full release date. It is only accepted if the year is 1900–2100, the month is 1–12, and the day is 1–31 (day-of-month validity against the specific month is NOT checked further — see Suspected defects). On success, the year, the remaining title, and a formatted "yyyy-MM-dd" release date are all returned.

Example: "1999.08.29 - (album) A.S.A. Crew" → year 1999, release date "1999-08-29", remaining title "(album) A.S.A. Crew".

### AS-CODE-REC-069 — Leading-year split: plain spaced year form
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:947 › Split-ReshelfLeadingYear

If the full-date form (AS-CODE-REC-068) doesn't match, and the folder name starts with a 4-digit year (1900–2100) followed by at least one space (optionally with a dash/en-dash before the space), the rest of the text is the title, with no release date.

Example: "yyyy - Release Name" format described in the manifesto, e.g. "1975 - T.N.T.".

### AS-CODE-REC-070 — Leading-year split: glued year form, rejected when it would misread a year range
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:947 › Split-ReshelfLeadingYear

If neither AS-CODE-REC-068 nor AS-CODE-REC-069 matched, and the folder name starts with a 4-digit year (1900–2100) glued directly to a dash/en-dash with no space, this is accepted as year + title UNLESS the remaining text itself starts with what looks like a second 4-digit year (1900–2100) followed by a space or end of string — in that ambiguous case the whole thing is left unparsed (falls through to AS-CODE-REC-071) rather than guessed.

Example: "2006-Fire Without Flame" → year 2006, title "Fire Without Flame". Counter-example: "1999-2003 Anthology" is NOT parsed as year 1999 + title "2003 Anthology" — it is left as an unparsed year range, because "2003 Anthology" itself looks like a second year.

### AS-CODE-REC-071 — Leading-year split: no match leaves the text unchanged
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:947 › Split-ReshelfLeadingYear

If none of AS-CODE-REC-068–070 match, the year and release date are null and the title is the original text, unchanged. A 4-digit value that is not followed by a recognized separator shape, or that falls outside 1900–2100, is never mistaken for a year.

Example: "Artist - 3218 (Edition)" — "3218" is a catalog number, not a leading year, so it is never misparsed as one (its position is also not leading, but even a leading 4-digit catalog number is bounds-checked out by the 1900–2100 range).

### AS-CODE-REC-072 — Release-type hint: bracketed type word at the START of the title is stripped
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:999 › Split-ReshelfReleaseTypeHint

If the title starts with a bracket group — "(" or "[" — containing ONLY one of the recognized type words (mini-album / mini album, maxi-single / maxi single, album, single, ep, lp; case-insensitive) and nothing else, followed by the rest of the title, that bracket group is stripped from the front. The recognized type word becomes the release type (lowercased, internal spaces turned to hyphens), and the remaining text (trimmed) becomes the title.

Example: "(album) A.S.A. Crew" → title "A.S.A. Crew", release type "album".

### AS-CODE-REC-073 — Release-type hint: bracketed type word at the END of the title is stripped
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:999 › Split-ReshelfReleaseTypeHint

If the leading form (AS-CODE-REC-072) doesn't match, and the title ends with a bracket group containing only one of the same recognized type words, preceded by at least some other text, that trailing bracket group is stripped and becomes the release type the same way.

Example: "Hou (EP)" → title "Hou", release type "ep". "'Kyo's Poem Book' [EP]" → release type "ep".

### AS-CODE-REC-074 — Release-type hint: a bracket with extra text is never touched
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:999 › Split-ReshelfReleaseTypeHint

A bracket group is only stripped when it contains NOTHING but a single recognized type word. A bracket containing a type word plus other text, or a non-type word, is left in the title untouched, and no release type is extracted.

Example: "Greatest (Deluxe)" is left unchanged (no type word). "(What's The Story) Morning Glory?" is left unchanged (bracket content is not purely a type word).

### AS-CODE-REC-075 — Artist-name-prefix stripping: matches artist name, optional bracketed year, then a separator
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1025 › Remove-ReshelfArtistNamePrefixFromTitle

A title is checked against a pattern anchored at the start: optional leading whitespace, the given artist name (matched exactly, case-insensitive), optional whitespace, optionally a 4-digit year wrapped in parentheses or brackets (with whitespace tolerance), then one of the separator characters hyphen / colon / en-dash / em-dash, then optional whitespace. If this whole prefix matches and does not consume the ENTIRE title, the matched prefix is removed from the front.

Example: artist folder "Dance with the dead" containing release folder "DANCE WITH THE DEAD - Blackout" → title becomes "Blackout" (case differences in the artist name are ignored). "Aerosmith (1973) - Aerosmith" with artist name "Aerosmith" → title becomes "Aerosmith", captured year 1973.

### AS-CODE-REC-076 — Artist-name-prefix stripping: a captured year outside 1900–2100 cancels the whole strip
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1025 › Remove-ReshelfArtistNamePrefixFromTitle

If the matched prefix (AS-CODE-REC-075) captured a bracketed 4-digit number as a "year" but that number is outside 1900–2100, the entire prefix-strip is rejected and the original title is returned unchanged (the bracketed number is treated as not actually a year, e.g. a catalog number, and the match as a whole is untrustworthy).

### AS-CODE-REC-077 — Artist-name-prefix stripping: no match, or a match that would consume the whole title, leaves it unchanged
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1025 › Remove-ReshelfArtistNamePrefixFromTitle

If the artist-name pattern doesn't match at all, or the match would consume the entire title text (leaving nothing as the actual title), the title is returned unchanged and nothing is marked as stripped.

### AS-CODE-REC-078 — Release record: leaf name source and year/title split
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1064 › New-ReshelfReleaseRecord

A release record's working leaf name is the explicit folder-name override when given, otherwise the actual on-disk leaf folder name. That leaf name is run through the leading-year split (AS-CODE-REC-068–071) to get an initial year/title/release-date.

### AS-CODE-REC-079 — Release record: artist-name-prefix stripped from the title, flagged
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1064 › New-ReshelfReleaseRecord

The release's artist name is stripped as a prefix from the title (AS-CODE-REC-075–077). If stripped, the recognition flag "artist-name-prefix-stripped" is added. If no year had been found yet from the folder name but the prefix-strip itself captured a year, that year is adopted.

### AS-CODE-REC-080 — Release record: re-splits for a year that sits between the artist prefix and the real title
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1064 › New-ReshelfReleaseRecord

If, after stripping the artist-name prefix, the release still has no year, the leading-year split (AS-CODE-REC-068–071) is run again on the NOW-stripped title. This catches a year that sits after the artist-name prefix rather than before it, which the very first split (run on the raw, un-stripped leaf name) could not have seen.

Example: "Nostromo - 1998 - Argue FLAC" with artist name "Nostromo" — the initial split sees no leading year (the name starts with "Nostromo"); after the artist prefix is stripped, the remaining "1998 - Argue FLAC" is re-split to find year 1998 and title "Argue FLAC".

### AS-CODE-REC-081 — Release record: release-type hint is split out of whatever title remains
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1064 › New-ReshelfReleaseRecord

After year/prefix handling, the release-type hint (AS-CODE-REC-072–074) is split off the remaining title and stored separately as the release's recognized release type, rather than being left embedded in the title text.

### AS-CODE-REC-082 — Release record: near-path-length-limit flag
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1064 › New-ReshelfReleaseRecord

If the release's source path needed long-path handling to address (its long-path form differs from the original path string), the recognition flag "path-near-length-limit" is added.

### AS-CODE-REC-083 — Release record, no disc folders: flat multi-disc cue pairs take priority
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1064 › New-ReshelfReleaseRecord

When the release folder has no named disc subfolders, if at least 2 flat disc/cue pairs are found (AS-CODE-REC-032–035), each pair becomes its own virtual disc (labeled by its audio file's own base name), the release is flagged needing review with reason "flat-multi-disc-cue-pairs", virtual cue tracks are built per pair (AS-CODE-REC-041–044), and the release's reported disc count is the pair count.

### AS-CODE-REC-084 — Release record, no disc folders: single-file cue-sheet release is the next choice
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1064 › New-ReshelfReleaseRecord

If flat multi-disc pairing (AS-CODE-REC-083) doesn't apply, but the folder qualifies as a single-file cue-sheet release (AS-CODE-REC-031), virtual cue tracks are built for that one audio/cue pair, with no disc-folder label.

### AS-CODE-REC-085 — Release record, no disc folders: plain track ordering is the fallback
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1064 › New-ReshelfReleaseRecord

If neither AS-CODE-REC-083 nor AS-CODE-REC-084 applies, the folder's audio files are ordered via the track-ordering rules (AS-CODE-REC-025/026). Every track whose order had to be inferred gets the recognition flag "no-track-number"; every track whose audio properties couldn't be read triggers needsReview with reason "audio-properties-unreadable".

### AS-CODE-REC-086 — Release record, no disc folders: nested-release suspicion
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1064 › New-ReshelfReleaseRecord

Still within the "no named disc subfolders" branch: if the folder produced at least one track by any of AS-CODE-REC-083–085 AND it also has at least one immediate subfolder that independently qualifies as its own release folder, the release is flagged needing review with reason "nested-release-suspected" (tracks found directly here look like they might be duplicated one level down).

### AS-CODE-REC-087 — Release record, with disc folders: each disc is a cue release or a plain track list
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1064 › New-ReshelfReleaseRecord

When the release folder has named disc subfolders, each one (in disc-number order) is checked for being a single-file cue-sheet release (AS-CODE-REC-031); if so, virtual cue tracks are built for it, labeled with that disc folder's name. Otherwise, its audio files are ordered via the plain track-ordering rules, with the same "no-track-number" and "audio-properties-unreadable" flagging as AS-CODE-REC-085, and each track is labeled with that disc folder's name.

### AS-CODE-REC-088 — Release record, with disc folders: loose audio directly in the release folder is kept and flagged
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1064 › New-ReshelfReleaseRecord

After processing all disc subfolders, any audio file sitting directly in the release folder itself (outside every disc subfolder) is still collected as its own track (not silently dropped, since it's excluded from both per-disc track lists and from companion-file scanning), and the release is flagged needing review with reason "track-outside-disc-folder-suspected".

### AS-CODE-REC-089 — Release record: with-disc-folders branch has no nested-release check
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1064 › New-ReshelfReleaseRecord

Unlike the no-disc-folders branch (AS-CODE-REC-086), the with-disc-folders branch never checks whether another, non-disc subfolder independently qualifies as its own release folder — see Suspected defects.

### AS-CODE-REC-090 — Release record: companion files exclude every cue actually used for splitting
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1064 › New-ReshelfReleaseRecord

Companion-file scanning (AS-CODE-REC-047–050) is run over the whole release folder, passing along every cue file path that was actually used to build tracks across the whole release (flat pairs, single cue, or per-disc cues), so none of those cues are reported as "cue-sheet-not-used".

### AS-CODE-REC-091 — Release record: three-level recognition confidence
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1064 › New-ReshelfReleaseRecord

Recognition confidence starts at 1.0. It drops to 0.8 if any recognition flag was raised during record construction (e.g. an inferred track order, a stripped artist prefix, a near-path-length-limit path). It drops further to 0.5 (overriding 0.8) if the release needs review for any reason raised during record construction. This confidence is computed once, before the record is returned.

### AS-CODE-REC-092 — Release record: stable key disambiguator for multi-edition albums
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1064 › New-ReshelfReleaseRecord

When a stable-key disambiguator is supplied (used for album-wrapper folders with more than one edition subfolder), the album portion of the release's stable key is "<title> [<disambiguator>]" instead of just the title, so each edition gets a distinct stable key even though they all derive their title/year from the same album folder name.

### AS-CODE-REC-093 — Release record: reported disc count defaults to 1
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1064 › New-ReshelfReleaseRecord

The release's reported disc-folder count is the flat-pair count when the flat multi-disc-cue-pairs path was used (AS-CODE-REC-083); otherwise it is the number of named disc subfolders, with a floor of 1 — a release with no disc subfolders at all is always reported as having 1 disc.

### AS-CODE-REC-094 — Release record: recognition flags and review reasons are de-duplicated
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1064 › New-ReshelfReleaseRecord

Both the recognition-flags list and the review-reasons list are de-duplicated before being stored on the returned release record.

### AS-CODE-REC-095 — Folder walk, release with known artist: builds directly, inherits ancestor review reasons
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1299 › Invoke-ReshelfFolderWalk

When a child folder is classified "release" and an artist name is already known from the walk context, the release record is built under that artist, any inherited review reasons from ancestor folders (AS-CODE-REC-065) are applied, and it is merged into that artist's bucket (AS-CODE-REC-066/067), keyed by the release folder's own parent path as the source path.

### AS-CODE-REC-096 — Folder walk, release with no artist yet: "Artist - Title" name split is tried first
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1299 › Invoke-ReshelfFolderWalk

When a "release" folder is found with no artist name yet known, the folder's own name is first checked against a flat "Artist - Title" split: the FIRST literal " - " (space, hyphen, space) separates a non-empty artist half from a non-empty title half. If it splits, the release is built from that guessed artist/title, forcibly flagged needing review with reason "artist-name-split-from-folder-name" (a guessed split is never silently trusted).

Example: "PULSAR OLYMP - 94Shine" → artist "PULSAR OLYMP", title "94Shine", always flagged for review.

### AS-CODE-REC-097 — Folder walk, release with no artist yet: tag-agreement fallback, then give up as unrecognized
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1299 › Invoke-ReshelfFolderWalk

If the name-split (AS-CODE-REC-096) doesn't apply, the per-track tag-agreement check (AS-CODE-REC-057/058) is tried instead; if every track agrees on artist/album, the release is built from that, flagged needing review with reason "artist-and-album-from-tags". If neither the name split nor the tag agreement works, the folder is NOT turned into a release at all — it is instead recorded as unrecognized with reason "release-without-artist-suspected", listing its direct children.

### AS-CODE-REC-098 — Folder walk, "Artist - Title" split only recognizes the ASCII hyphen
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1299 › Invoke-ReshelfFolderWalk

The no-artist-yet name-split pattern (AS-CODE-REC-096) only matches a literal " - " (space, ASCII hyphen, space); it does not accept an en-dash or em-dash as the separator, unlike other heuristics in this module (e.g. the leading-year split) that explicitly support en-dash separators — see Suspected defects.

### AS-CODE-REC-099 — Folder walk, album-wrapper: per-edition artist resolution uses the ALBUM folder's name
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1299 › Invoke-ReshelfFolderWalk

For an "album-wrapper" folder, each release-qualifying edition subfolder underneath it is turned into its own release, with title/year always parsed from the ALBUM (wrapper) folder's own name, never the edition subfolder's name. When no artist is known yet, the same name-split / tag-agreement / give-up-as-unrecognized cascade as AS-CODE-REC-096/097 is applied, but splitting the ALBUM folder's name rather than the edition folder's name.

### AS-CODE-REC-100 — Folder walk, album-wrapper: multi-edition disambiguation and loose-file flags
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1299 › Invoke-ReshelfFolderWalk

If an album-wrapper folder has more than one release-qualifying edition subfolder, each resulting release is flagged needing review with reason "multiple-editions-in-album-folder", and each gets a stable-key disambiguator equal to its own edition folder name (AS-CODE-REC-092) so editions don't collide on the same stable key. If the album-wrapper folder additionally has any loose direct files (e.g. cover art sitting next to the pressing subfolders), every resulting release is also flagged "album-folder-has-loose-files". Both flags are added on top of whatever the artist-resolution cascade (AS-CODE-REC-099) already added.

### AS-CODE-REC-101 — Folder walk, category: recurses with the same (or carried) artist name
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1299 › Invoke-ReshelfFolderWalk

A "category" folder is walked with context "CategoryBody", using the parent artist name carried by the classification result if present, otherwise the artist name already in effect.

### AS-CODE-REC-102 — Folder walk, band-member: recurses treating the folder's own name as a new artist
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1299 › Invoke-ReshelfFolderWalk

A "band-member" folder is walked with context "BandMemberBody" and its artist name reset to the band-member folder's own name (a new, distinct artist from its parent).

### AS-CODE-REC-103 — Folder walk, grouping: every grandchild starts a fresh artist walk, forced into review
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1299 › Invoke-ReshelfFolderWalk

A "grouping" folder is not walked as itself; instead, EVERY one of its own immediate subfolders (grandchildren of the grouping folder's parent) starts a fresh walk with context "ArtistBody" and that grandchild's own name as the artist. The reason "grouping-folder-auto-resolved" is added to the inherited review reasons passed down this branch, so every release eventually found under any grouping folder is forced to need review (there is no name-based confirmation that the subfolders are really distinct artists).

### AS-CODE-REC-104 — Folder walk, pass-through: carries artist name forward, promotes Root to ArtistBody
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1299 › Invoke-ReshelfFolderWalk

A "pass-through" folder is walked with the same context, except that context "Root" is promoted to "ArtistBody" (once past the first real folder under the scan root, everything from here on is inside an artist's body). The artist name used is the classification result's proposed new artist name if set (only happens at Root, see AS-CODE-REC-063), otherwise the artist name already in effect.

### AS-CODE-REC-105 — Folder walk, unrecognized: recorded with its own direct children
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1299 › Invoke-ReshelfFolderWalk

An "unrecognized" folder is recorded in the unrecognized list with the classification's reason and the names of its own direct children, for human triage.

### AS-CODE-REC-106 — Recognition document: fixed schema version and ISO-8601-with-milliseconds timestamp
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1458 › New-ReshelfRecognitionDocument

The recognition document always reports schemaVersion 1, and generatedAtUtc is the current UTC time formatted as "yyyy-MM-ddTHH:mm:ss.fffZ".

### AS-CODE-REC-107 — Recognition document: artists array built from the artist-bucket map
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1458 › New-ReshelfRecognitionDocument

The document's "artists" array is built from the artist-bucket map's values, each carrying its recognized name, its de-duplicated source paths, and its full list of releases; the "unrecognized" array is the flat unrecognized-folder list collected during the walk.

### AS-CODE-REC-108 — Recognition entry point: source root must exist and be a directory
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1494 › Invoke-ReshelfRecognition

If the given source root path does not exist or is not a directory, recognition throws immediately rather than proceeding.

### AS-CODE-REC-109 — Recognition entry point: walk starts at Root with no artist name
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1494 › Invoke-ReshelfRecognition

The source root is resolved to its canonical absolute path, the TagLib context is initialized (data home / optional explicit TagLib path), and the folder walk (AS-CODE-REC-095–105) is started at that root with context "Root" and no artist name.

### AS-CODE-REC-110 — Recognition entry point: result is written to a session-specific file and read back
Status: Draft | Source: legacy/scripts/common/Reshelf.Recognition.psm1:1494 › Invoke-ReshelfRecognition

The finished recognition document is written to "<data home>/sessions/<session id>/recognition.json" through the schema-validating JSON writer (schema "recognition"). The function then re-reads that same file back from disk and returns the parsed result, rather than returning the in-memory document directly — so the actual value callers receive has round-tripped through JSON serialization and schema validation.

## Suspected defects

- AS-CODE-DEF-REC-001 — legacy/scripts/common/Reshelf.Recognition.psm1:966 (Split-ReshelfLeadingYear, full-date form): the day value is only range-checked as 1–31 regardless of the month, so an impossible date like "2024.02.30" would still be accepted as a valid release date.
- AS-CODE-DEF-REC-002 — legacy/scripts/common/Reshelf.Recognition.psm1:1193 vs. 1198-1269 (New-ReshelfReleaseRecord): the "nested-release-suspected" check (a non-disc subfolder that independently qualifies as its own release folder) is only performed in the no-named-disc-subfolders branch. A multi-disc release (with "CD1"/"CD2"-style subfolders) that also has an unrelated nested release subfolder gets no equivalent flag.
- AS-CODE-DEF-REC-003 — legacy/scripts/common/Reshelf.Recognition.psm1:1273-1296 and legacy/scripts/common/Reshelf.Recognition.psm1:1343,1353,1395,1406,1419 (New-ReshelfReleaseRecord / Invoke-ReshelfFolderWalk): recognitionConfidence is computed once inside New-ReshelfReleaseRecord, before the function returns. Callers (Invoke-ReshelfFolderWalk and Add-ReshelfInheritedReviewReasons) can subsequently force needsReview=true and append review reasons (e.g. "artist-name-split-from-folder-name", "artist-and-album-from-tags", "multiple-editions-in-album-folder", "grouping-folder-auto-resolved") without ever recalculating recognitionConfidence, so a release can end up with needsReview=true while recognitionConfidence still reads 1.0 or 0.8 instead of 0.5.
- AS-CODE-DEF-REC-004 — legacy/scripts/common/Reshelf.Recognition.psm1:1337 (Invoke-ReshelfFolderWalk) and legacy/scripts/common/Reshelf.Recognition.psm1:1388 (same function, album-wrapper branch): the no-artist-yet "Artist - Title" folder-name split only matches a literal ASCII " - " separator, not an en-dash/em-dash, even though other heuristics in this same module (e.g. Split-ReshelfLeadingYear, Remove-ReshelfArtistNamePrefixFromTitle) explicitly treat en-dash/em-dash as equivalent separators.
- AS-CODE-DEF-REC-005 — legacy/scripts/common/Reshelf.Recognition.psm1:179-221 vs. legacy/scripts/common/Reshelf.Recognition.psm1:138-177 (Test-IsBandMemberFolder vs. Test-IsGroupingFolder): grouping-folder detection requires every subfolder to fail the release/disc/category/album-wrapper checks before granting grouping status, but band-member-folder detection only requires at least one release-folder subfolder to exist, without excluding subfolders that look like disc, category, or album-wrapper folders mixed in alongside it. The two "pure container of releases" heuristics apply different levels of rigor to structurally similar shapes.
- AS-CODE-DEF-REC-006 — legacy/scripts/common/Reshelf.Recognition.psm1:706-710 (Save-ReshelfEmbeddedCoverToCache): the cache file extension is chosen only from a 2-way switch (png vs. everything-else-as-jpg) on the picture's declared MIME type. A picture whose actual bytes are a different format (e.g. GIF or WEBP) than its declared/assumed type would be cached with a ".jpg" extension that doesn't match its real content.
- AS-CODE-DEF-REC-007 — legacy/scripts/common/Reshelf.Recognition.psm1:725-781 (Get-ReshelfAudioTags) called from legacy/scripts/common/Reshelf.Recognition.psm1:539, 803, 1168, 1214, 1247 (New-ReshelfCueVirtualTracks, Resolve-ReshelfArtistAlbumFromTags, New-ReshelfReleaseRecord): only Get-ReshelfReleaseFolderMetadataArtist wraps its call to Get-ReshelfAudioTags in a try/catch. Every other call site invokes it unguarded, so any exception other than TagLib's "corrupt file" case (which is already handled inside Get-ReshelfAudioTags itself) — e.g. an unsupported format — would propagate up and abort the whole recognition run instead of being recorded as a per-track review flag.

## Changelog

| Version | Date | Changes |
|---|---|---|
| 0.1 | 2026-10-10 | Phase 2 draft from code. |
