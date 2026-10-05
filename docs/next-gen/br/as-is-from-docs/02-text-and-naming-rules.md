# 02 — Text and naming rules (as-is, from docs and tests)

Status: Draft | Version: 0.1 | Last updated: 2026-10-05

## Scope

Area **TXT**. How the legacy app compares and cleans text (normalization, look-alike characters, Japanese and romanized text, invisible characters, title case), how it builds safe file and folder names, and the target folder structure and metadata rules.

Owned inputs: `legacy/tests/Reshelf.Common.Tests.ps1` (text, safe name, companion name, truncation, cue timestamp Describes), `MANIFESTO.md` §4 (Target Storage Structure) and §5 (Metadata Rules), and the field rules in `legacy/plan/03-domain-model-and-json-schemas.md` that encode §5. How propose applies these rules to a real release: see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

Suspected defects and contradictions are listed in [90-suspected-defects.md](90-suspected-defects.md): AS-DOC-DEF-009 to AS-DOC-DEF-013 for this area.

## Normalized text for comparison

### AS-DOC-TXT-001 — Normalized text is lowercase, trimmed, without punctuation, with single spaces
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfNormalizedText (private) › lowercases, trims, strips punctuation, and collapses whitespace

To compare names, the app normalizes the text: it lowercases it, trims it, removes punctuation and collapses runs of spaces into one space. A removed apostrophe leaves no space.

Example: `"  ZZ Top's  Best!! "` → `zz tops best`.

### AS-DOC-TXT-002 — Texts that differ only in case, punctuation or spacing are equal
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfNormalizedText (private) › treats different-case, different-punctuation input as equal

Two texts that differ only in case, punctuation or spacing give the same normalized text.

Example: `Talking Heads` and `  talking   HEADS  ` → the same value.

### AS-DOC-TXT-003 — Full-width Latin letters and digits compare equal to plain ones
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfNormalizedText (private) › folds full-width Latin letters/digits (NFKC) …

Normalization applies Unicode NFKC (compatibility form). Full-width Latin letters and digits become ordinary ASCII.

Example: `ＢＢ` (full-width) and `BB` → the same normalized text. Real case: a track `Nitro BB Sensou` on Discogs with full-width letters.

## Look-alike (homoglyph) characters

### AS-DOC-TXT-004 — A Cyrillic look-alike letter inside Latin text becomes Latin
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfHomoglyphNormalizedText › normalizes a single Cyrillic look-alike character mixed into otherwise-Latin text

When a Latin text has a Cyrillic letter that looks the same as a Latin letter (a homoglyph), the app replaces it with the Latin letter. It also reports that the text changed. Reason given in the test: Discogs search returns nothing for such text.

Example: `Inсubus Succubus` with U+0441 (Cyrillic `с`) → `Incubus Succubus`, changed = true.

### AS-DOC-TXT-005 — A real Cyrillic name stays as it is
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfHomoglyphNormalizedText › leaves a genuinely Cyrillic name (no Latin letters at all) untouched

A text with no Latin letters at all is not changed.

Example: `Кино` → `Кино`, changed = false.

### AS-DOC-TXT-006 — A Japanese title stays as it is
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfHomoglyphNormalizedText › leaves a genuinely Japanese title untouched

Japanese text is not changed by look-alike normalization.

Example: `ロッキンポ殺し` → `ロッキンポ殺し`, changed = false.

### AS-DOC-TXT-007 — Plain ASCII text stays as it is
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfHomoglyphNormalizedText › is a no-op for plain ASCII text

Plain ASCII text is not changed.

Example: `Radiohead` → `Radiohead`, changed = false.

## Japanese and romanized text

### AS-DOC-TXT-008 — Text with hiragana, katakana or kanji has Japanese script
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Test-ReshelfHasJapaneseScript

A text has Japanese script when it contains at least one hiragana, katakana or kanji character. Mixed Japanese and Latin text counts too.

Example: `ひらがな`, `マキシマム ザ ホルモン`, `ロッキンポ殺し`, `Nitro BB戦争` → Japanese script.

### AS-DOC-TXT-009 — Romanized and empty text has no Japanese script
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Test-ReshelfHasJapaneseScript › returns false for plain romanized text; › returns false for an empty string

Text with only Latin letters, and empty text, has no Japanese script.

Example: `Rokkinpo Goroshi` → no; `''` → no.

### AS-DOC-TXT-010 — Text is romanized when it has letters and no Japanese script
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Test-ReshelfIsRomanizedText › returns true for plain romanized text; › returns false for Japanese-script text

A text is romanized (Japanese written in Latin letters) when it has letters and no Japanese script. The tests do not cover other scripts, for example Cyrillic.

Example: `Maximum The Hormone` → romanized; `マキシマム ザ ホルモン` → not romanized.

### AS-DOC-TXT-011 — Text without letters is not romanized
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Test-ReshelfIsRomanizedText › returns false for text with no letters at all; › returns false for an empty string; › returns false for whitespace only

Text with no letters, empty text and whitespace-only text are not romanized.

Example: `1999` → no; `''` → no; `'   '` → no.

## Bilingual names

### AS-DOC-TXT-012 — A Japanese-only name gets the romanized form in front
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Join-ReshelfBilingualName › joins a romanized name with a Japanese-only original (Discogs convention)

When the original name is in Japanese script and a romanized form exists, the app joins them as `<romanized> = <original>`. This is the Discogs convention. How Japanese releases use it: see [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md).

Example: romanized `Rokkinpo Goroshi`, original `ロッキンポ殺し` → `Rokkinpo Goroshi = ロッキンポ殺し`.

### AS-DOC-TXT-013 — A name that already has both halves stays as it is
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Join-ReshelfBilingualName › keeps the original as-is when it already has both halves ("X = Y")

When the original already has the `X = Y` form, the app keeps it and ignores the romanized input.

Example: romanized `anything`, original `Tsume Tsume Tsume / 「F」= 爪爪爪 / 「F」` → `Tsume Tsume Tsume / 「F」= 爪爪爪 / 「F」`.

### AS-DOC-TXT-014 — A name without Japanese script stays as it is
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Join-ReshelfBilingualName › keeps the original as-is when it has no Japanese script at all

When the original has no Japanese script, the app keeps it.

Example: romanized `Rokkinpo Goroshi`, original `Falling Jimmy` → `Falling Jimmy`.

### AS-DOC-TXT-015 — Without a romanized form the original stays as it is
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Join-ReshelfBilingualName › keeps the original as-is when there is no romanized text to add

When there is no romanized text, the app keeps the original.

Example: romanized `null`, original `ロッキンポ殺し` → `ロッキンポ殺し`.

### AS-DOC-TXT-016 — A "romanized" input in Japanese script is not used
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Join-ReshelfBilingualName › keeps the original as-is when the romanized text is itself Japanese script

When the romanized input itself contains Japanese script, the app keeps the original.

Example: romanized `マキシマム`, original `ロッキンポ殺し` → `ロッキンポ殺し`.

## Invisible characters

### AS-DOC-TXT-017 — Zero-width spaces and byte-order marks are removed
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Remove-ReshelfInvisibleCharacters

The app removes invisible characters from a text: the zero-width space (U+200B) and the byte-order mark (U+FEFF), also in the middle of the text. Ordinary text is not changed.

Example: `B` + U+200B + `-` + U+200B + `Sides` (real Discogs case) → `B-Sides`; `Some` + U+FEFF + `Title` → `SomeTitle`; `Ordinary Title` → `Ordinary Title`.

## Title case

### AS-DOC-TXT-018 — Title case capitalizes the first letter of each word
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfTitleCase › capitalizes the first letter of every whitespace-separated word; › capitalizes an all-lowercase single word (real "edbl" case)

Title case makes the first letter of every word (separated by spaces) upper case.

Example: `aoki takamasa` → `Aoki Takamasa`; `edbl` → `Edbl`.

### AS-DOC-TXT-019 — Title case does not change the other letters
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfTitleCase › leaves interior/existing capitalization untouched; › returns an empty string unchanged

Title case does not lowercase the other letters. Existing capitals stay. An empty text stays empty.

Example: `DJ Shadow` → `DJ Shadow`; `''` → `''`.

## Safe file and folder names

### AS-DOC-TXT-020 — A safe name is not changed
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-SafeFileName › leaves an already-safe name unchanged

A name that is already valid on Windows is not changed. The result says "not changed" and has no substitutions.

Example: `Poke Chop Sandwich` → `Poke Chop Sandwich`, changed = false, substitutions = none.

### AS-DOC-TXT-021 — Each Windows-invalid character becomes an underscore
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-SafeFileName › replaces each Windows-invalid character with an underscore

The characters `<` `>` `:` `"` `/` `\` `|` `?` `*` are each replaced with `_`.

Example: `Track:Name` → `Track_Name`; `Track?Name` → `Track_Name`; `Track/Name` → `Track_Name`.

### AS-DOC-TXT-022 — A trailing dot is removed
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-SafeFileName › strips a trailing dot

A dot at the end of the name is removed.

Example: `Track Name.` → `Track Name`.

### AS-DOC-TXT-023 — A trailing space is removed
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-SafeFileName › strips a trailing space

A space at the end of the name is removed.

Example: `Track Name ` → `Track Name`.

### AS-DOC-TXT-024 — A reserved device name gets an underscore suffix
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-SafeFileName › suffixes every reserved device name case-insensitively

The Windows reserved device names `CON`, `PRN`, `AUX`, `NUL`, `COM1`–`COM9`, `LPT1`–`LPT9` get `_` at the end. The check ignores case. The original case is kept.

Example: `CON` → `CON_`; `Nul` → `Nul_`; `lpt3` → `lpt3_`.

### AS-DOC-TXT-025 — A reserved name with an extension keeps the extension
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-SafeFileName › suffixes a reserved device name that has an extension, keeping the extension

When the part before the first dot is a reserved name, the `_` goes before the first dot. The rest stays.

Example: `CON.flac` → `CON_.flac`; `nul.txt` → `nul_.txt`; `COM1.tar.gz` → `COM1_.tar.gz`.

### AS-DOC-TXT-026 — A reserved name inside a longer name is not reserved
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-SafeFileName › does not treat a reserved name as reserved when it is only part of the name

Only a whole base name counts as reserved. A name that only contains a reserved word is not changed.

Example: `CONcert`, `CONcert.flac`, `01 CON.flac`, `COM10`, `.CON` → unchanged.

### AS-DOC-TXT-027 — Every change is recorded as a substitution
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-SafeFileName › records multiple substitutions for combined issues; › replaces each Windows-invalid character with an underscore

The result lists one substitution message per change and says "changed". A name with several problems gets several messages.

Example: `Track: Name?.` → `Track_ Name_`, more than one substitution. `CON.flac` → message `reserved device name 'CON' suffixed with '_'`.

### AS-DOC-TXT-028 — Substitution messages can name the context
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-SafeFileName › prefixes substitution messages with the given context

When the caller gives a context, each message starts with `<context>: `.

Example: name `A/B`, context `track file name` → `track file name: invalid character '/' replaced with '_'`.

### AS-DOC-TXT-029 — An empty name is not an error
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-SafeFileName › handles an empty string without throwing

The app accepts an empty name without an error. The tests do not show the result value.

Example: `''` → no error.

## Loose companion file names

### AS-DOC-TXT-030 — A loose companion file name must start with a letter
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Test-ReshelfLooseCompanionFileName › returns true for a name starting with an ASCII letter; › returns true for a name starting with a non-ASCII (Cyrillic) letter; MANIFESTO.md › 4.5 Companion / Extra Materials

A companion file placed directly in the release folder (loose) is valid when its name starts with a letter. Any script counts as a letter. Reason (MANIFESTO §4.5): alphabetical sort in a file explorer then puts the tracks (`01 …`) first.

Example: `Cover.jpg` → valid; `Обложка.jpg` → valid.

### AS-DOC-TXT-031 — A name that starts with a digit or a symbol is not a valid loose name
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Test-ReshelfLooseCompanionFileName › returns false for a name starting with a digit; › … with a symbol; › … for an empty string

A name that starts with a digit or a symbol is not valid as a loose name. An empty name is not valid.

Example: `01 back.jpg` → not valid; `(scan).png` → not valid; `''` → not valid.

### AS-DOC-TXT-032 — A loose name that starts with a letter is kept
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfLooseCompanionFileName › leaves a name that already starts with a letter unchanged; › does not prefix a name starting with a non-ASCII letter

When the companion name already starts with a letter (ASCII or not), the app keeps it and reports "not prefixed".

Example: `folder.jpg` (kind `cover`) → `folder.jpg`; `Обложка.jpg` (kind `cover`) → `Обложка.jpg`.

### AS-DOC-TXT-033 — A digit-starting loose name gets a kind word in front
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfLooseCompanionFileName › prefixes a digit-starting name with the kind word for each known kind

When the name starts with a digit, the app puts a word for the companion kind and a space in front:

| Kind | Word |
|---|---|
| `cover` | `Cover` |
| `booklet` | `Booklet` |
| `photo` | `Photo` |
| `lyrics` | `Lyrics` |
| `other` | `Extra` |

Example: `01 back.jpg`, kind `cover` → `Cover 01 back.jpg`; kind `other` → `Extra 01 back.jpg`.

### AS-DOC-TXT-034 — A symbol-starting loose name also gets the kind word
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfLooseCompanionFileName › prefixes a symbol-starting name

A name that starts with a symbol gets the kind word too.

Example: `(scan).png`, kind `cover` → `Cover (scan).png`.

### AS-DOC-TXT-035 — The companion name is made safe before the letter check
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › Get-ReshelfLooseCompanionFileName › sanitizes invalid filename characters before checking the letter rule

The app first replaces invalid characters (AS-DOC-TXT-021). Then it checks the letter rule.

Example: `photo?.jpg`, kind `photo` → `photo_.jpg`, not prefixed.

## Truncated name segments

### AS-DOC-TXT-036 — A name segment that fits is not changed
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfTruncatedSegment › leaves the segment unchanged when it already fits

A name segment is built from a prefix, a body and a suffix. When the whole segment fits the length limit, the app keeps it and reports "not truncated".

Example: prefix `2010 `, body `A Short Album`, suffix `''`, limit 250 → `2010 A Short Album`.

### AS-DOC-TXT-037 — Only the body is shortened
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfTruncatedSegment › truncates only the body, keeping the prefix and suffix intact

When the segment is too long, the app shortens only the body. The prefix and the suffix stay complete. The result has exactly the limit length.

Example: prefix `01 `, body 100 × `A`, suffix `.flac`, limit 30 → 30 characters, starts with `01 `, ends with `.flac`, truncated = true.

### AS-DOC-TXT-038 — At least one body character stays
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfTruncatedSegment › keeps at least one body character when the budget is smaller than prefix+suffix

When the limit is smaller than prefix plus suffix, the app still keeps at least one body character. The result is then longer than the limit.

Example: prefix `01 `, body `Some Title`, suffix `.flac`, limit 5 → matches `01 *.flac` (for example `01 S.flac`, 9 characters), truncated = true.

### AS-DOC-TXT-039 — Truncation does not split a character pair
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfTruncatedSegment › does not split a UTF-16 surrogate pair when the cut would land inside one

When the cut falls inside a UTF-16 surrogate pair (for example an emoji), the app does not keep half of the pair. The last character is never a lone high surrogate.

Example: body `Track 😀 Title`, limit = position between the two halves of `😀` → the result ends before `😀`.

## Cue sheet timestamps

### AS-DOC-TXT-040 — A cue timestamp is minutes, seconds and frames
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfCueTimestampSeconds › converts MM:SS:FF (CD-audio frames, 75/sec) to total seconds; › converts a zero timestamp to zero seconds

A cue timestamp `MM:SS:FF` means minutes, seconds and CD-audio frames (75 frames per second). The app converts it to total seconds, rounded to 3 decimals in the example.

Example: `09:26:73` → 566.973 (9 × 60 + 26 + 73 / 75); `00:00:00` → 0.

### AS-DOC-TXT-041 — A cue timestamp is never read as hours:minutes:seconds
Status: Draft | Source: legacy/tests/Reshelf.Common.Tests.ps1 › ConvertTo-ReshelfCueTimestampSeconds › does not misread MM:SS:FF as HH:MM:SS

The first part is minutes, not hours.

Example: `03:12:45` → 192.6 seconds (not 3 h 12 min 45 s).

## Target folder structure (MANIFESTO §4)

### AS-DOC-TXT-042 — The library starts at its own root folder
Status: Draft | Source: MANIFESTO.md › 4.1 Root

The organized library starts at a root folder. It is a new root, separate from the old unorganized music folder. The setting for it is `targetRoot` (AS-DOC-SET-005 in [03-settings-and-secrets.md](03-settings-and-secrets.md)).

Example: `E:\Music` (from `settings-example.json`).

### AS-DOC-TXT-043 — The root holds only main-artist folders
Status: Draft | Source: MANIFESTO.md › 4.2 Level 1 — Main Artist

The root folder contains only main-artist folders. There is no genre level.

Example: `E:\Music\ZZ Top\`, `E:\Music\Talking Heads\`; not `E:\Music\Rock\ZZ Top\`.

### AS-DOC-TXT-044 — An artist folder has the main artist's name
Status: Draft | Source: MANIFESTO.md › 4.2 Level 1 — Main Artist

The artist folder name is the main artist name, with nothing else.

Example: `Imelda May`, `Metallica`, `Talking Heads`, `David Byrne`, `Cranberries`, `Dolores O'Riordan`.

### AS-DOC-TXT-045 — An artist folder holds release folders of all release types
Status: Draft | Source: MANIFESTO.md › 4.3 Level 2 — Release

Inside an artist folder are release folders: album (LP), EP, SP, single, maxi single. The album is the main unit, because singles can be found inside their albums. A single without its album is kept; the album is most likely not released yet.

Example: `ZZ Top\1999 XXX\` (album).

### AS-DOC-TXT-046 — A release folder is named "yyyy The Album Name"
Status: Draft | Source: MANIFESTO.md › 4.3 Level 2 — Release; legacy/plan/04-settings-module.md › Naming templates

A release folder name is the 4-digit year, a space and the album name. The default template is `{year} {album}`.

Example: artist `ZZ Top` → `2012 La Futura`, `2003 Mescalero`, `1999 XXX`.

### AS-DOC-TXT-047 — A track file is named "NN The Track Name.ext"
Status: Draft | Source: MANIFESTO.md › 4.4 Level 3 — Media Files (Tracks); legacy/plan/04-settings-module.md › Naming templates

A track file name is the track number, a space, the track name and the file extension. The default template is `{trackNumber} {title}`.

Example: album `1999 XXX` → `01 Poke Chop Sandwich.flac`, `02 Crucifixx A Flatt.flac`.

### AS-DOC-TXT-048 — The track name part can contain extra words
Status: Draft | Source: MANIFESTO.md › 4.4 Level 3 — Media Files (Tracks); MANIFESTO.md › 5. Metadata Rules (Filename)

After the actual name, the track name part can contain featured artists, mix or remix words, remaster and similar words.

Example: `03 Some Song (feat. Other Artist) [Remix].flac` (illustration, not from a fixture).

### AS-DOC-TXT-049 — The file number is zero-padded and keeps counting across discs
Status: Draft | Source: MANIFESTO.md › 4.4 Level 3 — Media Files (Tracks); legacy/plan/03-domain-model-and-json-schemas.md › proposal.json (field rules)

The `NN` number in the file name has a leading zero. On a multi-disc release it does not restart per disc; it continues.

Example: 2 tracks on CD 1 and 3 on CD 2 → `01 Track One.mp3`, `02 Track Two.mp3` (CD 1), `03 Track One.mp3`, `04 Track Two.mp3`, `05 Track Three.mp3` (CD 2).

### AS-DOC-TXT-050 — The number width is at least the pad-width setting, wider when needed
Status: Draft | Source: legacy/plan/04-settings-module.md › Naming templates; legacy/plan/03-domain-model-and-json-schemas.md › Edge cases; legacy/README.md › Reference: settings (`trackNumberPadWidth`)

Same rule as AS-DOC-PRP-018 in [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md) (primary) and AS-DOC-MAT-059 in [07-proposal-matching.md](07-proposal-matching.md). This entry keeps its plan and README sources.

The width of the file number per release is `max(trackNumberPadWidth, digits needed for the total track count across all discs)`. The setting is a minimum, default 2.

Example: 12 tracks → `01`…`12`; a 150-track box set → `001`…`150`.

### AS-DOC-TXT-051 — A single file with a cue sheet is split into track files
Status: Draft | Source: MANIFESTO.md › 4.4 Level 3 — Media Files (Tracks); legacy/plan/03-domain-model-and-json-schemas.md › recognition.json (Notes)

When a release is one big media file plus a `.cue` sheet (timestamps and track names), the media file is split into separate track files. The final structure has no `.cue` file. How apply splits: see [10-apply.md](10-apply.md).

Example: `album.flac` + `album.cue` with 10 tracks → `01 ….flac` … `10 ….flac`, no `album.cue` in the target.

### AS-DOC-TXT-052 — The final structure has no playlist files
Status: Draft | Source: MANIFESTO.md › 4.4 Level 3 — Media Files (Tracks); legacy/plan/03-domain-model-and-json-schemas.md › recognition.json (Notes)

Playlist files are not allowed in the target. Recognition lists them as ignored with reason `playlist-file`.

Example: `playlist.m3u` in the source → not copied.

### AS-DOC-TXT-053 — Companion material is either in a subfolder or loose
Status: Draft | Source: MANIFESTO.md › 4.5 Companion / Extra Materials; legacy/plan/03-domain-model-and-json-schemas.md › recognition.json (Notes)

Extra material (cover scans, lyrics, artist photos) has two allowed places: in a subfolder of the release folder (`nested`), or directly in the release folder next to the tracks (`loose`). Loose names follow AS-DOC-TXT-030 to AS-DOC-TXT-035.

Example: `1999 XXX\Scans\front.jpg` (nested); `1999 XXX\cover.jpg` (loose).

### AS-DOC-TXT-054 — The placement follows the source folder
Status: Draft | Source: MANIFESTO.md › 4.5 Companion / Extra Materials

The source decides the placement. Material that was in a subfolder in the source stays in a subfolder; loose material stays loose.

Example: source `Some Band/2010 Album/Scans/front.jpg` → target `…\2010 Album\Scans\front.jpg`.

### AS-DOC-TXT-055 — Genres are not used
Status: Draft | Source: MANIFESTO.md › 4.5 Companion / Extra Materials (last paragraph); MANIFESTO.md › 4.2 Level 1 — Main Artist

The app does not use genres: not in folders and not in metadata.

Example: no `Rock\` folder level; no genre in the proposed tags (the `tags` schema has no genre field).

### AS-DOC-TXT-056 — Naming templates use five placeholders
Status: Draft | Source: legacy/plan/04-settings-module.md › Naming templates; legacy/README.md › Reference: settings

The settings `namingTemplates.releaseFolder` and `namingTemplates.trackFile` are format strings with placeholders `{year}`, `{album}`, `{artist}`, `{trackNumber}`, `{title}`. The defaults match the manifesto. The user changes them by editing `settings.json` by hand.

Example: `"releaseFolder": "{year} {album}"`, `"trackFile": "{trackNumber} {title}"`.

## Metadata rules (MANIFESTO §5)

### AS-DOC-TXT-057 — Disc Number is always set and starts at 1
Status: Draft | Source: MANIFESTO.md › 5. Metadata Rules (Disc Number); legacy/plan/03-domain-model-and-json-schemas.md › proposal.json (field rules)

Every track has a Disc Number tag, also on a single-disc release. It starts at 1 and has no leading zero.

Example: single-disc `1999 XXX` → `discNumber = 1` on every track (not `01`).

### AS-DOC-TXT-058 — The Track tag restarts at 1 on each disc, without a leading zero
Status: Draft | Source: MANIFESTO.md › 5. Metadata Rules (Track); legacy/plan/03-domain-model-and-json-schemas.md › proposal.json (field rules)

The Track tag is the track's number on its own disc. It restarts at 1 for each disc. It has no leading zero. It differs from the file number (AS-DOC-TXT-049).

Example (3 discs, 2 tracks each):

| File Name | Disc Number | Track | Title |
|---|:-:|:-:|---|
| 01 First Track.flac | 1 | 1 | First Track |
| 02 Second Track.flac | 1 | 2 | Second Track |
| 03 Third Track.flac | 2 | 1 | Third Track |
| 04 Fourth Track.flac | 2 | 2 | Fourth Track |
| 05 Fifth Track.flac | 3 | 1 | Fifth Track |
| 06 Sixth Track.flac | 3 | 2 | Sixth Track |

### AS-DOC-TXT-059 — Artist and Album Artist are equal by default
Status: Draft | Source: MANIFESTO.md › 5. Metadata Rules (Artist and Album Artist); legacy/plan/03-domain-model-and-json-schemas.md › proposal.json (field rules)

Both Artist and Album Artist tags are required. By default they have exactly the same value: the artist name of the artist folder. Reason: some players read or show these two tags differently, or show only one.

Example: `ZZ Top\1999 XXX\01 Poke Chop Sandwich.flac` → `artist = ZZ Top`, `albumArtist = ZZ Top`.

### AS-DOC-TXT-060 — On a compilation the Artist tag can differ per track
Status: Draft | Source: MANIFESTO.md › 5. Metadata Rules (Compilations); legacy/plan/03-domain-model-and-json-schemas.md › proposal.json (field rules)

On a compilation (Various Artists), Album Artist still matches the artist folder name, usually `Various`. The Artist tag of each track can be the real performer that Discogs credits for that track.

Example: folder `Various\…` with tracks by `The Dubliners` and `Johnny Logan` → `albumArtist = Various`; `artist = The Dubliners` on one track, `Johnny Logan` on another.

### AS-DOC-TXT-061 — Without a Discogs track credit, the file's own Artist tag is used
Status: Draft | Source: MANIFESTO.md › 5. Metadata Rules (Compilations); legacy/plan/03-domain-model-and-json-schemas.md › proposal.json (field rules)

On a compilation, when Discogs has no per-track credit for a track, the Artist tag comes from the source file's existing Artist tag.

Example: a `Various` track with no Discogs credit and existing tag `artist = Johnny Logan` → `artist = Johnny Logan`.

### AS-DOC-TXT-062 — A split release with per-track credits also uses per-track artists
Status: Draft | Source: legacy/plan/03-domain-model-and-json-schemas.md › proposal.json (field rules)

The per-track Artist rule also covers a split release with per-track Discogs credits, also when it is not a Various Artists compilation.

Example: a split single by two bands → each track gets its own band as `artist`; `albumArtist` = the artist folder name.

### AS-DOC-TXT-063 — Every Artist value is editable
Status: Draft | Source: MANIFESTO.md › 5. Metadata Rules (Compilations)

Every proposed Artist value, from any source, can be edited in the review UI. Nothing is locked once proposed. How the UI does it: see [09-review-ui.md](09-review-ui.md).

Example: proposed `artist = The Dubliners` → the user changes it to `Dubliners, The`.

### AS-DOC-TXT-064 — A Various Artists release gets the Compilation flag
Status: Draft | Source: MANIFESTO.md › 5. Metadata Rules (Compilation flag); legacy/plan/03-domain-model-and-json-schemas.md › proposal.json (field rules)

Same rule as AS-DOC-MAT-053 in [07-proposal-matching.md](07-proposal-matching.md) (detection, primary) and AS-DOC-PRP-041 in [08-proposal-naming-and-tags.md](08-proposal-naming-and-tags.md) (effect). Writing the flag: AS-DOC-APL-040 in [10-apply.md](10-apply.md). This entry keeps its MANIFESTO and plan sources.

A release recognized as Various Artists gets a Compilation flag, written as TCMP, cpil or COMPILATION depending on the file format. Plan 03 says a release is a compilation when Discogs gives its "Various" artist, or when the recognized folder or artist name is `Various` / `Various Artists` with no Discogs match. The flag is visible and editable in `proposal.json` (`proposed.isCompilation`, `tags.isCompilation`) and in the UI.

Example: folder `Various` → `isCompilation = true`, written as TCMP in an MP3.

### AS-DOC-TXT-065 — Featured artists appear only in the title
Status: Draft | Source: MANIFESTO.md › 5. Metadata Rules (feat. artists); legacy/plan/03-domain-model-and-json-schemas.md › proposal.json (field rules)

A featured artist appears only in the track title: in the file name and in the Title tag. It is never added to Artist or Album Artist. Reason: players read `Metallica` and `Metallica feat. Justin Bieber` as two artists and split the album.

Example: `artist = Metallica`, `title = Some Song (feat. Justin Bieber)` (illustration).

### AS-DOC-TXT-066 — The Title tag is the file name without the number prefix
Status: Draft | Source: MANIFESTO.md › 5. Metadata Rules (Title)

The Title tag is the `The Track Name` part of `NN The Track Name`, without the `NN ` prefix.

Example: `01 Poke Chop Sandwich.flac` → `title = Poke Chop Sandwich`.

### AS-DOC-TXT-067 — Cover art is embedded in every file, at most 600×600 px
Status: Draft | Source: MANIFESTO.md › 5. Metadata Rules (Cover art); legacy/README.md › Reference: settings (`coverMaxDimension`)

Every media file has embedded cover art. The image is no larger than 600×600 pixels. The limit is the `coverMaxDimension` setting (longest side, default 600).

Example: Discogs cover 1200×1200 → embedded as 600×600.

### AS-DOC-TXT-068 — Year and Album tags match the release folder name
Status: Draft | Source: MANIFESTO.md › 5. Metadata Rules (Year and Album)

Year and Album tags are required. They match the release folder name `yyyy The Album Name`.

Example: album `XXX` by ZZ Top, released 1999, folder `1999 XXX` → `year = 1999`, `album = XXX`.

### AS-DOC-TXT-069 — Discogs is the source of truth for metadata and names
Status: Draft | Source: MANIFESTO.md › 5. Metadata Rules (Source of truth)

Discogs is the source of truth for all metadata above, for cover art, for release folder names and for track file names.

Example: Discogs release 123456 → album `XXX`, year 1999, track `Poke Chop Sandwich`.

## Raw tag values and filesystem names (plan 03)

### AS-DOC-TXT-070 — Album Artist keeps the raw name; the artist folder name is the safe form
Status: Draft | Source: legacy/plan/03-domain-model-and-json-schemas.md › proposal.json (field rules)

`tags.albumArtist` is the raw artist name. `proposed.artistFolderName` is the same text with invalid file name characters replaced by `_` (AS-DOC-TXT-021). They are equal except where a character was replaced.

Example: artist `AC/DC` → `albumArtist = AC/DC`, `artistFolderName = AC_DC` (illustration).

### AS-DOC-TXT-071 — The Album tag keeps the raw title; the release folder uses the safe form
Status: Draft | Source: legacy/plan/03-domain-model-and-json-schemas.md › proposal.json (field rules)

`tags.album` is the raw album title. `proposed.releaseFolderName` is `<tags.year> <safe album title>`.

Example: album `XXX`, year 1999 → `releaseFolderName = 1999 XXX`; album `What?` → `album = What?`, folder `… What_`.

### AS-DOC-TXT-072 — Sanitizing changes only file and folder names, never tags
Status: Draft | Source: legacy/plan/03-domain-model-and-json-schemas.md › proposal.json (field rules)

The app makes names safe only in the filesystem name fields: `artistFolderName`, `releaseFolderName`, `proposedFileName`. It never changes `tags.*` or `proposedTitle`.

Example: title `Track: Name?` → `proposedTitle = Track: Name?`, `tags.title = Track: Name?`, `proposedFileName = 01 Track_ Name_.flac`.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-05 | Phase 1 draft. |
