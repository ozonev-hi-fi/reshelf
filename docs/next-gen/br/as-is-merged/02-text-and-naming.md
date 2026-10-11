# 02 — Text and naming (as-is, merged)

Status: Draft | Version: 0.1 | Last updated: 2026-10-11

## Scope

Area **TXT**. How the legacy app compares and cleans text (normalization,
look-alike characters, Japanese and romanized text, invisible characters,
title case), how it builds safe file and folder names, and the target folder
structure and metadata rules. Sources:
`br/as-is-from-docs/02-text-and-naming-rules.md` (`AS-DOC-TXT-001`–`072`,
read from tests, MANIFESTO and plan docs) and
`br/as-is-from-code/02-text-and-naming.md` (`AS-CODE-TXT-001`–`026`, read
only from `legacy/scripts/common/Reshelf.Common.psm1`).

The two sets don't line up 1:1. The doc side also covers MANIFESTO's target
folder structure (§4) and metadata rules (§5) and the field rules in plan 03
— narrative/business rules with no corresponding function in
`Reshelf.Common.psm1`, so `AS-DOC-TXT-040`–`072` have no `AS-CODE-TXT-*`
counterpart; that's expected, not a gap. Conversely, the code side documents
the exact confusable-character whitelist and a truncation detail
(trailing-whitespace trim) the doc side doesn't state.

**ID numbering for this area:** `AS-TXT-001`–`072` mirror `AS-DOC-TXT-001`–`072`
one for one — each keeps its doc number even where an `AS-CODE-TXT-*` item
elaborates it with the precise implementation detail, because the
elaboration is the same rule, not a second rule. `AS-TXT-073`–`074` are fresh
numbers for the two `AS-CODE-TXT-*` facts that don't attach to any doc-side
rule.

**Not owned by this area:** `AS-CODE-TXT-014` and `AS-CODE-TXT-015` describe
`ConvertFrom-ReshelfTrackFileName` — code that lives in the TXT-owned module
file, but whose behavior (parsing a track number and an Artist/Title hint out
of a track's file name) is the same rule already described from docs and
tests under area REC: `AS-DOC-REC-055`–`058` in
[05-recognition.md](../as-is-from-docs/05-recognition.md). They were not
duplicated here under a TXT number; the REC merge (now done) cited them
alongside `AS-DOC-REC-055`–`059` as `AS-REC-056`–`059` in
[../as-is-merged/05-recognition.md](05-recognition.md). See the coverage
file.

## Normalized text for comparison

### AS-TXT-001 — Normalization runs trim, NFKC fold, lowercase, then strips to letters/digits/spaces
Status: Draft | Source: AS-DOC-TXT-001; AS-CODE-TXT-001, AS-CODE-TXT-002

To compare names, the app normalizes text in this exact order: trim leading/
trailing whitespace, apply Unicode NFKC normalization (folds things like
full-width Latin letters/digits to their ordinary ASCII form), lowercase
using invariant culture (not the current locale), then delete every
character that is not a Unicode letter, decimal digit or whitespace —
punctuation is removed outright, not replaced with a space. Any run of
remaining whitespace collapses to a single space, and the result is trimmed
again.

Example: `"  ZZ Top's  Best!! "` → `"zz tops best"`. `"The Wall (Remastered)!"`
→ `"the wall remastered"` (no double space, because the original space
before `(` is preserved while the parenthesis itself leaves nothing).

### AS-TXT-002 — Texts that differ only in case, punctuation or spacing are equal
Status: Draft | Source: AS-DOC-TXT-002

Two texts that differ only in case, punctuation or spacing give the same
normalized text (AS-TXT-001).

Example: `Talking Heads` and `  talking   HEADS  ` → the same value.

### AS-TXT-003 — Full-width Latin letters and digits compare equal to plain ones
Status: Draft | Source: AS-DOC-TXT-003; AS-CODE-TXT-001

The NFKC step of normalization (AS-TXT-001) folds full-width Latin letters
and digits to ordinary ASCII.

Example: `ＢＢ` (full-width) and `BB` → the same normalized text. Real case: a
track `Nitro BB Sensou` on Discogs with full-width letters.

## Look-alike (homoglyph) characters

### AS-TXT-004 — A Cyrillic look-alike letter inside otherwise-Latin text becomes Latin
Status: Draft | Source: AS-DOC-TXT-004; AS-CODE-TXT-003

Confusable-character replacement only fires when the text has at least one
genuine Latin letter, at least one mapped confusable character, and zero
letters that are neither Latin nor in the confusable map — a narrow,
safety-first check, not general transliteration. When it fires, each
confusable character is replaced by its Latin look-alike and the result
reports that the text changed. Reason given in the test: Discogs search
returns nothing for such text.

Example: `Inсubus Succubus` with U+0441 (Cyrillic `с`) → `Incubus Succubus`,
changed = true.

### AS-TXT-005 — A real Cyrillic name stays as it is
Status: Draft | Source: AS-DOC-TXT-005; AS-CODE-TXT-003

A text with no Latin letters at all has nothing for the narrow condition in
AS-TXT-004 to fire on, so it is not changed.

Example: `Кино` → `Кино`, changed = false.

### AS-TXT-006 — A Japanese title stays as it is
Status: Draft | Source: AS-DOC-TXT-006; AS-CODE-TXT-003

Japanese text is not changed by look-alike normalization (no Latin letter
present for AS-TXT-004's condition to fire on).

Example: `ロッキンポ殺し` → `ロッキンポ殺し`, changed = false.

### AS-TXT-007 — Plain ASCII text stays as it is
Status: Draft | Source: AS-DOC-TXT-007; AS-CODE-TXT-003

Plain ASCII text has no mapped confusable character, so AS-TXT-004's
condition never fires and the text is not changed.

Example: `Radiohead` → `Radiohead`, changed = false.

### AS-TXT-073 — The confusable map is a small fixed whitelist of 38 code points
Status: Draft | Source: AS-CODE-TXT-004

The look-alike map used by AS-TXT-004 covers exactly 38 code points: 10
Cyrillic lowercase letters, 13 Cyrillic uppercase letters, 14 Greek uppercase
letters, and only 1 Greek lowercase letter (omicron `ο`→`o`, the only Greek
lowercase letter considered a true visual duplicate of a Latin letter in
common fonts). It is not general transliteration: any Cyrillic/Greek letter
not in this explicit list is left as-is, and per AS-TXT-004 its presence
blocks the whole replacement for that string.

## Japanese and romanized text

### AS-TXT-008 — Text with hiragana, katakana, kanji or half-width katakana has Japanese script
Status: Draft | Source: AS-DOC-TXT-008; AS-CODE-TXT-005

A text has Japanese script when it contains at least one hiragana, katakana,
CJK Unified Ideographs (kanji), or half-width katakana (Unicode range
`ｦ`-`ﾟ`, U+FF66–FF9F) character. Mixed Japanese and Latin text counts too.
Kanji alone could in principle also be plain Chinese text, but the app makes
no such distinction — any kanji counts as Japanese here.

Example: `ひらがな`, `マキシマム ザ ホルモン`, `ロッキンポ殺し`, `Nitro BB戦争` →
Japanese script.

### AS-TXT-009 — Romanized and empty text has no Japanese script
Status: Draft | Source: AS-DOC-TXT-009; AS-CODE-TXT-005, AS-CODE-TXT-006

Text with only Latin letters, and empty or whitespace-only text, has no
Japanese script.

Example: `Rokkinpo Goroshi` → no; `''` → no.

### AS-TXT-010 — Text is "romanized" when it has a letter of any script and isn't Japanese-scripted
Status: Draft | Source: AS-DOC-TXT-010; AS-CODE-TXT-007, AS-CODE-TXT-008

A text is "romanized" when it is not empty/whitespace-only (AS-TXT-011), has
no Japanese script (AS-TXT-008/009), and contains at least one Unicode
letter — of *any* script, not specifically Latin/ASCII. Despite the name, the
check does not verify the text is actually Latin: a pure Cyrillic, Greek or
Arabic string with no Japanese script also counts as "romanized". See
`CF-TXT-001` in
[91-suspected-defects-carryforward.md](91-suspected-defects-carryforward.md)
for why this is flagged as a suspected defect.

Example: `Maximum The Hormone` → romanized; `マキシマム ザ ホルモン` → not
romanized.

### AS-TXT-011 — Text without letters, empty text and whitespace-only text are not romanized
Status: Draft | Source: AS-DOC-TXT-011; AS-CODE-TXT-006

Text with no letters at all, empty text, and whitespace-only text are not
romanized.

Example: `1999` → no; `''` → no; `'   '` → no.

## Bilingual names

### AS-TXT-012 — A Japanese-only name gets the romanized form in front
Status: Draft | Source: AS-DOC-TXT-012; AS-CODE-TXT-009, AS-CODE-TXT-011

When the original name has Japanese script, contains no `=` character
anywhere, and a usable romanized form exists (AS-TXT-015/016), the app joins
them as exactly `"<romanized> = <original>"` — one space, `=`, one space —
regardless of how Discogs itself formats spacing around `=` in its own text.
This is the Discogs convention. How Japanese releases use it: see
[08-proposal-naming-and-tags.md](../as-is-from-docs/08-proposal-naming-and-tags.md).

Example: romanized `Rokkinpo Goroshi`, original `ロッキンポ殺し` →
`Rokkinpo Goroshi = ロッキンポ殺し`.

### AS-TXT-013 — A name that already contains "=" stays as it is
Status: Draft | Source: AS-DOC-TXT-013; AS-CODE-TXT-009

When the original already contains an `=` character anywhere — not only the
exact `X = Y` shape — the app returns it unchanged and does not look at the
romanized input at all.

Example: romanized `anything`, original `Tsume Tsume Tsume / 「F」= 爪爪爪 /
「F」` → `Tsume Tsume Tsume / 「F」= 爪爪爪 / 「F」`.

### AS-TXT-014 — A name without Japanese script stays as it is
Status: Draft | Source: AS-DOC-TXT-014; AS-CODE-TXT-009

When the original has no Japanese script, the app keeps it; the join only
ever applies to Japanese-scripted text.

Example: romanized `Rokkinpo Goroshi`, original `Falling Jimmy` →
`Falling Jimmy`.

### AS-TXT-015 — Without a usable romanized form the original stays as it is
Status: Draft | Source: AS-DOC-TXT-015; AS-CODE-TXT-010

When the romanized input fails the "is romanized" check (AS-TXT-010/011 —
null, empty, whitespace-only, or itself Japanese-scripted), the app keeps the
original rather than forcing a join with a missing or invalid value.

Example: romanized `null`, original `ロッキンポ殺し` → `ロッキンポ殺し`.

### AS-TXT-016 — A "romanized" input that is itself Japanese script is not used
Status: Draft | Source: AS-DOC-TXT-016; AS-CODE-TXT-010

When the romanized input itself contains Japanese script, it fails the "is
romanized" check (AS-TXT-010), so the app keeps the original.

Example: romanized `マキシマム`, original `ロッキンポ殺し` → `ロッキンポ殺し`.

## Invisible characters

### AS-TXT-017 — Unicode format characters (zero-width spaces, BOM, ZWJ/ZWNJ) are deleted outright
Status: Draft | Source: AS-DOC-TXT-017; AS-CODE-TXT-012

The app removes every character in Unicode category `Cf` ("format") from a
text, with nothing put in its place — this includes the zero-width space
(U+200B), the byte-order mark (U+FEFF), and the zero-width joiner/non-joiner,
also in the middle of the text. Ordinary text is not changed.

Example: `B` + U+200B + `-` + U+200B + `Sides` (real Discogs case) →
`B-Sides`; `Some` + U+FEFF + `Title` → `SomeTitle`; `Ordinary Title` →
`Ordinary Title`.

## Title case

### AS-TXT-018 — Title case capitalizes a lowercase first letter of each word
Status: Draft | Source: AS-DOC-TXT-018; AS-CODE-TXT-013

Title case uppercases a letter only when it is lowercase and is either the
first character of the string or immediately follows whitespace — i.e. the
first letter of each whitespace-separated word, and only if it starts out
lowercase.

Example: `aoki takamasa` → `Aoki Takamasa`; `edbl` → `Edbl`; `mccoy tyner` →
`Mccoy Tyner` (not `McCoy Tyner` — only the very first letter of each word is
touched).

### AS-TXT-019 — Title case does not change any other letter
Status: Draft | Source: AS-DOC-TXT-019; AS-CODE-TXT-013

Every character other than a word's qualifying first letter (AS-TXT-018) is
left exactly as-is — a word that already starts with an uppercase letter, a
digit or a symbol is untouched, and interior capitalization is never
produced or removed. An empty text stays empty.

Example: `DJ Shadow` → `DJ Shadow`; `''` → `''`.

## Safe file and folder names

### AS-TXT-020 — A safe name is not changed
Status: Draft | Source: AS-DOC-TXT-020; AS-CODE-TXT-019

A name that is already valid on Windows is not changed. `WasChanged` is true
only if the fully processed result differs from the original input as given
— not from any intermediate step — so an already-safe name reports
`changed = false` with no substitutions.

Example: `Poke Chop Sandwich` → `Poke Chop Sandwich`, changed = false,
substitutions = none.

### AS-TXT-021 — Each Windows-invalid character becomes an underscore
Status: Draft | Source: AS-DOC-TXT-021; AS-CODE-TXT-016

The set of invalid characters is the current OS's own invalid-filename-character
set combined (de-duplicated) with a fixed explicit list: `< > : " / \ | ? *` —
so Windows-unsafe characters are always rejected even if run on an OS whose
own set is smaller. Each distinct invalid character found is replaced with
`_`.

Example: `Track:Name` → `Track_Name`; `Track?Name` → `Track_Name`;
`Track/Name` → `Track_Name`.

### AS-TXT-022 — A trailing run of dots is removed
Status: Draft | Source: AS-DOC-TXT-022; AS-CODE-TXT-017

Any trailing run of `.` or space characters at the very end of the name is
removed (Windows disallows a trailing dot/space in a filename) — see
AS-TXT-023 for the space case; both are the same trailing-run strip.

Example: `Track Name.` → `Track Name`.

### AS-TXT-023 — A trailing run of spaces is removed
Status: Draft | Source: AS-DOC-TXT-023; AS-CODE-TXT-017

Same trailing-run strip as AS-TXT-022, for trailing spaces.

Example: `Track Name ` → `Track Name`.

### AS-TXT-024 — A reserved device name gets an underscore suffix
Status: Draft | Source: AS-DOC-TXT-024; AS-CODE-TXT-018

Only the stem (the part before the first `.`) is checked, case-insensitively,
against the fixed reserved-name list `CON, PRN, AUX, NUL, COM1`–`COM9`,
`LPT1`–`LPT9`. If it matches, `_` is appended right after the stem. The
original case is kept.

Example: `CON` → `CON_`; `Nul` → `Nul_`; `lpt3` → `lpt3_`.

### AS-TXT-025 — A reserved name with an extension keeps the extension
Status: Draft | Source: AS-DOC-TXT-025; AS-CODE-TXT-018

Because only the stem before the first dot is checked (AS-TXT-024), the `_`
goes right after the stem and everything from the first dot onward is left
untouched.

Example: `CON.flac` → `CON_.flac`; `nul.txt` → `nul_.txt`; `COM1.tar.gz` →
`COM1_.tar.gz`.

### AS-TXT-026 — A reserved name inside a longer name is not reserved
Status: Draft | Source: AS-DOC-TXT-026; AS-CODE-TXT-018

Only a whole stem counts as reserved (exact, case-insensitive match against
the list in AS-TXT-024). A name that only contains a reserved word as part of
a longer stem is not changed.

Example: `CONcert`, `CONcert.flac`, `01 CON.flac`, `COM10`, `.CON` →
unchanged.

### AS-TXT-027 — Every change is recorded as a substitution, applied in a fixed order
Status: Draft | Source: AS-DOC-TXT-027; AS-CODE-TXT-016, AS-CODE-TXT-019

The result lists one substitution message per distinct change and reports
"changed" if anything was applied. Substitutions are applied, and listed, in
this order: character replacement (AS-TXT-021), then trailing dot/space trim
(AS-TXT-022/023), then reserved-name suffix (AS-TXT-024).

Example: `Track: Name?.` → `Track_ Name_`, more than one substitution.
`CON.flac` → message `reserved device name 'CON' suffixed with '_'`.

### AS-TXT-028 — Substitution messages can name the context
Status: Draft | Source: AS-DOC-TXT-028; AS-CODE-TXT-016

When the caller gives a context, each message starts with `<context>: `.

Example: name `A/B`, context `track file name` → `track file name: invalid
character '/' replaced with '_'`.

### AS-TXT-029 — An empty name is not an error
Status: Draft | Source: AS-DOC-TXT-029

The app accepts an empty name without an error. The tests do not show the
result value.

Example: `''` → no error.

## Loose companion file names

### AS-TXT-030 — A loose companion file name must start with a letter of any script
Status: Draft | Source: AS-DOC-TXT-030; AS-CODE-TXT-020

A companion file placed directly in the release folder (loose) is valid when
its name starts with a Unicode letter (`\p{L}`) — any script, not only
A-Z/a-z. Reason (MANIFESTO §4.5): alphabetical sort in a file explorer then
puts the tracks (`01 …`) first.

Example: `Cover.jpg` → valid; `Обложка.jpg` → valid.

### AS-TXT-031 — A name that starts with a digit or a symbol is not a valid loose name
Status: Draft | Source: AS-DOC-TXT-031; AS-CODE-TXT-020

A name that starts with a digit or a symbol is not valid as a loose name (it
fails the letter check in AS-TXT-030). An empty name is not valid.

Example: `01 back.jpg` → not valid; `(scan).png` → not valid; `''` → not
valid.

### AS-TXT-032 — A loose name that starts with a letter is kept
Status: Draft | Source: AS-DOC-TXT-032; AS-CODE-TXT-021, AS-CODE-TXT-022

When the companion name, after sanitizing (AS-TXT-035), already starts with a
letter (ASCII or not), the app keeps it and reports "not prefixed".

Example: `folder.jpg` (kind `cover`) → `folder.jpg`; `Обложка.jpg` (kind
`cover`) → `Обложка.jpg`.

### AS-TXT-033 — A digit-starting loose name gets a kind word in front
Status: Draft | Source: AS-DOC-TXT-033; AS-CODE-TXT-022

When the sanitized name does not start with a letter, the app puts a word
for the companion kind and a space in front:

| Kind | Word |
|---|---|
| `cover` | `Cover` |
| `booklet` | `Booklet` |
| `photo` | `Photo` |
| `lyrics` | `Lyrics` |
| `other` (or any unrecognized kind) | `Extra` |

Example: `01 back.jpg`, kind `cover` → `Cover 01 back.jpg`; kind `other` →
`Extra 01 back.jpg`.

### AS-TXT-034 — A symbol-starting loose name also gets the kind word
Status: Draft | Source: AS-DOC-TXT-034; AS-CODE-TXT-022

A name that starts with a symbol also fails the letter check and gets the
kind word (AS-TXT-033).

Example: `(scan).png`, kind `cover` → `Cover (scan).png`.

### AS-TXT-035 — The companion name is made safe before the letter check
Status: Draft | Source: AS-DOC-TXT-035; AS-CODE-TXT-021

The app first runs the name through the same sanitation as a safe file name
(invalid characters, trailing dot/space, reserved name — AS-TXT-021/022/023/
024). Only then does it check the letter rule (AS-TXT-030).

Example: `photo?.jpg`, kind `photo` → `photo_.jpg`, not prefixed.

## Truncated name segments

### AS-TXT-036 — A name segment that fits is not changed
Status: Draft | Source: AS-DOC-TXT-036; AS-CODE-TXT-023

A name segment is built from a prefix, a body and a suffix. When
`Prefix + Body + Suffix` already fits the length limit, the app returns the
three parts concatenated, unchanged, and reports "not truncated".

Example: prefix `2010 `, body `A Short Album`, suffix `''`, limit 250 →
`2010 A Short Album`.

### AS-TXT-037 — Only the body is shortened
Status: Draft | Source: AS-DOC-TXT-037; AS-CODE-TXT-024

When the segment is too long, only the body is shortened, to a budget of
`limit - prefix.length - suffix.length`. The prefix and the suffix stay
complete.

Example: prefix `01 `, body 100 × `A`, suffix `.flac`, limit 30 → 30
characters, starts with `01 `, ends with `.flac`, truncated = true.

### AS-TXT-038 — At least one body character stays, even past the limit
Status: Draft | Source: AS-DOC-TXT-038; AS-CODE-TXT-024

When the limit is smaller than prefix plus suffix, the budget for the body
(AS-TXT-037) is clamped up to a minimum of 1 character rather than 0 — so the
result can end up longer than the limit instead of guaranteeing the overall
length cap. See `CF-TXT-002` in
[91-suspected-defects-carryforward.md](91-suspected-defects-carryforward.md).

Example: prefix `01 `, body `Some Title`, suffix `.flac`, limit 5 → matches
`01 *.flac` (for example `01 S.flac`, 9 characters), truncated = true.

### AS-TXT-039 — Truncation does not split a UTF-16 surrogate pair
Status: Draft | Source: AS-DOC-TXT-039; AS-CODE-TXT-025

When the computed cut point would land inside a UTF-16 surrogate pair (for
example an emoji), the cut point moves back by one character so the result
never ends on a lone high surrogate.

Example: body `Track 😀 Title`, limit = position between the two halves of
`😀` → the result ends before `😀`.

### AS-TXT-074 — The truncated body has trailing whitespace trimmed before the suffix is reattached
Status: Draft | Source: AS-CODE-TXT-026

After the body is cut (AS-TXT-037/038/039), trailing whitespace is removed
from it (the default whitespace set — space, tab, newline, etc. — not only
plain spaces) before the suffix is appended.

## Cue sheet timestamps

### AS-TXT-040 — A cue timestamp is minutes, seconds and frames
Status: Draft | Source: AS-DOC-TXT-040

A cue timestamp `MM:SS:FF` means minutes, seconds and CD-audio frames (75
frames per second). The app converts it to total seconds.

Example: `09:26:73` → 566.973 (9 × 60 + 26 + 73 / 75); `00:00:00` → 0.

### AS-TXT-041 — A cue timestamp is never read as hours:minutes:seconds
Status: Draft | Source: AS-DOC-TXT-041

The first part is minutes, not hours.

Example: `03:12:45` → 192.6 seconds (not 3 h 12 min 45 s).

## Target folder structure (MANIFESTO §4)

### AS-TXT-042 — The library starts at its own root folder
Status: Draft | Source: AS-DOC-TXT-042

The organized library starts at a root folder, separate from the old
unorganized music folder. The setting for it is `targetRoot` (see
`03-settings-and-secrets.md`).

Example: `E:\Music` (from `settings-example.json`).

### AS-TXT-043 — The root holds only main-artist folders
Status: Draft | Source: AS-DOC-TXT-043

The root folder contains only main-artist folders. There is no genre level.

Example: `E:\Music\ZZ Top\`, `E:\Music\Talking Heads\`; not
`E:\Music\Rock\ZZ Top\`.

### AS-TXT-044 — An artist folder has the main artist's name
Status: Draft | Source: AS-DOC-TXT-044

The artist folder name is the main artist name, with nothing else.

Example: `Imelda May`, `Metallica`, `Talking Heads`, `David Byrne`,
`Cranberries`, `Dolores O'Riordan`.

### AS-TXT-045 — An artist folder holds release folders of all release types
Status: Draft | Source: AS-DOC-TXT-045

Inside an artist folder are release folders: album (LP), EP, SP, single,
maxi single. The album is the main unit, because singles can be found inside
their albums. A single without its album is kept; the album is most likely
not released yet.

MANIFESTO's "SP" here is a business-level category (historically, a Japanese
single release), not a separate value in the `recognizedReleaseType` schema
enum — see the resolved contradiction in
[90-contradictions-resolution.md](90-contradictions-resolution.md). The app
classifies an SP release under the `single` enum value.

Example: `ZZ Top\1999 XXX\` (album).

### AS-TXT-046 — A release folder is named "yyyy The Album Name"
Status: Draft | Source: AS-DOC-TXT-046

A release folder name is the 4-digit year, a space and the album name. The
default template is `{year} {album}`.

Example: artist `ZZ Top` → `2012 La Futura`, `2003 Mescalero`, `1999 XXX`.

### AS-TXT-047 — A track file is named "NN The Track Name.ext"
Status: Draft | Source: AS-DOC-TXT-047

A track file name is the track number, a space, the track name and the file
extension. The default template is `{trackNumber} {title}`.

Example: album `1999 XXX` → `01 Poke Chop Sandwich.flac`,
`02 Crucifixx A Flatt.flac`.

### AS-TXT-048 — The track name part can contain extra words
Status: Draft | Source: AS-DOC-TXT-048

After the actual name, the track name part can contain featured artists, mix
or remix words, remaster and similar words.

Example: `03 Some Song (feat. Other Artist) [Remix].flac` (illustration, not
from a fixture).

### AS-TXT-049 — The file number is zero-padded and keeps counting across discs
Status: Draft | Source: AS-DOC-TXT-049

The `NN` number in the file name has a leading zero. On a multi-disc release
it does not restart per disc; it continues. This differs from the `Track`
tag, which restarts per disc — see AS-TXT-058 and the wording-only
contradiction `AS-DOC-DEF-013`, re-verified and confirmed in
[90-contradictions-resolution.md](90-contradictions-resolution.md).

Example: 2 tracks on CD 1 and 3 on CD 2 → `01 Track One.mp3`,
`02 Track Two.mp3` (CD 1), `03 Track One.mp3`, `04 Track Two.mp3`,
`05 Track Three.mp3` (CD 2).

### AS-TXT-050 — The number width is at least the pad-width setting, wider when needed
Status: Draft | Source: AS-DOC-TXT-050

Same rule as `AS-DOC-PRP-018` (primary) and `AS-DOC-MAT-059` — not yet merged
into `AS-PRP-*`/`AS-MAT-*`; this entry keeps its original cross-references
until those areas are merged.

The width of the file number per release is
`max(trackNumberPadWidth, digits needed for the total track count across all
discs)`. The setting is a minimum, default 2.

Example: 12 tracks → `01`…`12`; a 150-track box set → `001`…`150`.

### AS-TXT-051 — A single file with a cue sheet is split into track files
Status: Draft | Source: AS-DOC-TXT-051

When a release is one big media file plus a `.cue` sheet, the media file is
split into separate track files. The final structure has no `.cue` file —
the source is read-only (copy mode only, see `AS-DAT-044`), so the cue file
is simply not copied rather than deleted. MANIFESTO's "the `.cue` file must
be deleted afterward" wording is re-verified and resolved in favor of this
reading; see `AS-DOC-DEF-011` in
[90-contradictions-resolution.md](90-contradictions-resolution.md). How
apply splits: see [10-apply.md](../as-is-from-docs/10-apply.md).

Example: `album.flac` + `album.cue` with 10 tracks → `01 ….flac` …
`10 ….flac`, no `album.cue` in the target.

### AS-TXT-052 — The final structure has no playlist files
Status: Draft | Source: AS-DOC-TXT-052

Playlist files are not allowed in the target. Recognition lists them as
ignored with reason `playlist-file`.

Example: `playlist.m3u` in the source → not copied.

### AS-TXT-053 — Companion material is either in a subfolder or loose
Status: Draft | Source: AS-DOC-TXT-053

Extra material (cover scans, lyrics, artist photos) has two allowed places:
in a subfolder of the release folder (`nested`), or directly in the release
folder next to the tracks (`loose`). Loose names follow AS-TXT-030 to
AS-TXT-035.

Example: `1999 XXX\Scans\front.jpg` (nested); `1999 XXX\cover.jpg` (loose).

### AS-TXT-054 — The placement follows the source folder
Status: Draft | Source: AS-DOC-TXT-054

The source decides the placement. Material that was in a subfolder in the
source stays in a subfolder; loose material stays loose.

Example: source `Some Band/2010 Album/Scans/front.jpg` → target
`…\2010 Album\Scans\front.jpg`.

### AS-TXT-055 — Genres are not used
Status: Draft | Source: AS-DOC-TXT-055

The app does not use genres: not in folders and not in metadata.

Example: no `Rock\` folder level; no genre in the proposed tags (the `tags`
schema has no genre field).

### AS-TXT-056 — Naming templates use five placeholders
Status: Draft | Source: AS-DOC-TXT-056

The settings `namingTemplates.releaseFolder` and `namingTemplates.trackFile`
are format strings with placeholders `{year}`, `{album}`, `{artist}`,
`{trackNumber}`, `{title}`. The defaults match the manifesto. The user
changes them by editing `settings.json` by hand.

Example: `"releaseFolder": "{year} {album}"`,
`"trackFile": "{trackNumber} {title}"`.

## Metadata rules (MANIFESTO §5)

### AS-TXT-057 — Disc Number is always set and starts at 1
Status: Draft | Source: AS-DOC-TXT-057

Every track has a Disc Number tag, also on a single-disc release. It starts
at 1 and has no leading zero.

Example: single-disc `1999 XXX` → `discNumber = 1` on every track (not
`01`).

### AS-TXT-058 — The Track tag restarts at 1 on each disc, without a leading zero
Status: Draft | Source: AS-DOC-TXT-058

The Track tag is the track's number on its own disc. It restarts at 1 for
each disc, with no leading zero. It differs from the file number
(AS-TXT-049).

Example (3 discs, 2 tracks each):

| File Name | Disc Number | Track | Title |
|---|:-:|:-:|---|
| 01 First Track.flac | 1 | 1 | First Track |
| 02 Second Track.flac | 1 | 2 | Second Track |
| 03 Third Track.flac | 2 | 1 | Third Track |
| 04 Fourth Track.flac | 2 | 2 | Fourth Track |
| 05 Fifth Track.flac | 3 | 1 | Fifth Track |
| 06 Sixth Track.flac | 3 | 2 | Sixth Track |

### AS-TXT-059 — Artist and Album Artist are equal by default
Status: Draft | Source: AS-DOC-TXT-059

Both Artist and Album Artist tags are required. By default they have exactly
the same value: the artist name of the artist folder. Reason: some players
read or show these two tags differently, or show only one.

Example: `ZZ Top\1999 XXX\01 Poke Chop Sandwich.flac` → `artist = ZZ Top`,
`albumArtist = ZZ Top`.

### AS-TXT-060 — On a compilation the Artist tag can differ per track
Status: Draft | Source: AS-DOC-TXT-060

On a compilation (Various Artists), Album Artist still matches the artist
folder name, usually `Various`. The Artist tag of each track can be the real
performer that Discogs credits for that track.

Example: folder `Various\…` with tracks by `The Dubliners` and `Johnny
Logan` → `albumArtist = Various`; `artist = The Dubliners` on one track,
`Johnny Logan` on another.

### AS-TXT-061 — Without a Discogs track credit, the file's own Artist tag is used
Status: Draft | Source: AS-DOC-TXT-061

On a compilation, when Discogs has no per-track credit for a track, the
Artist tag comes from the source file's existing Artist tag.

Example: a `Various` track with no Discogs credit and existing tag
`artist = Johnny Logan` → `artist = Johnny Logan`.

### AS-TXT-062 — A split release with per-track credits also uses per-track artists
Status: Draft | Source: AS-DOC-TXT-062

The per-track Artist rule also covers a split release with per-track
Discogs credits, also when it is not a Various Artists compilation.

Example: a split single by two bands → each track gets its own band as
`artist`; `albumArtist` = the artist folder name.

### AS-TXT-063 — Every Artist value is editable
Status: Draft | Source: AS-DOC-TXT-063

Every proposed Artist value, from any source, can be edited in the review
UI. Nothing is locked once proposed. How the UI does it: see
[09-review-ui.md](../as-is-from-docs/09-review-ui.md).

Example: proposed `artist = The Dubliners` → the user changes it to
`Dubliners, The`.

### AS-TXT-064 — A Various Artists release gets the Compilation flag
Status: Draft | Source: AS-DOC-TXT-064

Same rule as `AS-DOC-MAT-053` (detection, primary) and `AS-DOC-PRP-041`
(effect) — not yet merged into `AS-MAT-*`/`AS-PRP-*`; writing the flag is
`AS-DOC-APL-040`. This entry keeps its original cross-references until those
areas are merged.

A release recognized as Various Artists gets a Compilation flag, written as
TCMP, cpil or COMPILATION depending on the file format. Plan 03 says a
release is a compilation when Discogs gives its "Various" artist, or when the
recognized folder or artist name is `Various` / `Various Artists` with no
Discogs match. The flag is visible and editable in `proposal.json`
(`proposed.isCompilation`, `tags.isCompilation`) and in the UI.

Example: folder `Various` → `isCompilation = true`, written as TCMP in an
MP3.

### AS-TXT-065 — Featured artists appear only in the title
Status: Draft | Source: AS-DOC-TXT-065

A featured artist appears only in the track title: in the file name and in
the Title tag. It is never added to Artist or Album Artist. Reason: players
read `Metallica` and `Metallica feat. Justin Bieber` as two artists and
split the album.

Example: `artist = Metallica`, `title = Some Song (feat. Justin Bieber)`
(illustration).

### AS-TXT-066 — The Title tag is the file name without the number prefix
Status: Draft | Source: AS-DOC-TXT-066

The Title tag is the `The Track Name` part of `NN The Track Name`, without
the `NN ` prefix.

Example: `01 Poke Chop Sandwich.flac` → `title = Poke Chop Sandwich`.

### AS-TXT-067 — Cover art is embedded in every file, at most 600×600 px
Status: Draft | Source: AS-DOC-TXT-067

Every media file has embedded cover art. The image is no larger than
600×600 pixels. The limit is the `coverMaxDimension` setting (longest side,
default 600).

Example: Discogs cover 1200×1200 → embedded as 600×600.

### AS-TXT-068 — Year and Album tags match the release folder name
Status: Draft | Source: AS-DOC-TXT-068

Year and Album tags are required. They match the release folder name
`yyyy The Album Name`.

Example: album `XXX` by ZZ Top, released 1999, folder `1999 XXX` →
`year = 1999`, `album = XXX`.

### AS-TXT-069 — Discogs is the source of truth for metadata and names
Status: Draft | Source: AS-DOC-TXT-069

Discogs is the source of truth for all metadata above, for cover art, for
release folder names and for track file names.

Example: Discogs release 123456 → album `XXX`, year 1999, track
`Poke Chop Sandwich`.

## Raw tag values and filesystem names (plan 03)

### AS-TXT-070 — Album Artist keeps the raw name; the artist folder name is the safe form
Status: Draft | Source: AS-DOC-TXT-070

`tags.albumArtist` is the raw artist name. `proposed.artistFolderName` is the
same text with invalid file name characters replaced by `_` (AS-TXT-021).
They are equal except where a character was replaced. This is why a tag and
its folder/file name can differ — see the resolved contradiction
`AS-DOC-DEF-010` in
[90-contradictions-resolution.md](90-contradictions-resolution.md).

Example: artist `AC/DC` → `albumArtist = AC/DC`,
`artistFolderName = AC_DC` (illustration).

### AS-TXT-071 — The Album tag keeps the raw title; the release folder uses the safe form
Status: Draft | Source: AS-DOC-TXT-071

`tags.album` is the raw album title. `proposed.releaseFolderName` is
`<tags.year> <safe album title>`.

Example: album `XXX`, year 1999 → `releaseFolderName = 1999 XXX`; album
`What?` → `album = What?`, folder `… What_`.

### AS-TXT-072 — Sanitizing changes only file and folder names, never tags
Status: Draft | Source: AS-DOC-TXT-072

The app makes names safe only in the filesystem name fields:
`artistFolderName`, `releaseFolderName`, `proposedFileName`. It never changes
`tags.*` or `proposedTitle`.

Example: title `Track: Name?` → `proposedTitle = Track: Name?`,
`tags.title = Track: Name?`, `proposedFileName = 01 Track_ Name_.flac`.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-10-11 | Area TXT merged: 74 `AS-TXT-*` requirements (72 mirroring `AS-DOC-TXT-001`–`072`, 2 fresh for code-only facts), 1 new contradiction found and resolved (`AS-TXT-045`/`AS-DOC-DEF-009`, MANIFESTO "SP" vs the `recognizedReleaseType` enum), 3 phase-1 contradictions re-verified (`AS-DOC-DEF-010`, `011`, `013`), 3 suspected defects carried forward (`CF-TXT-001`–`003`). `AS-CODE-TXT-014`/`015` (track-filename parsing) noted as REC-owned, deferred to that area's merge pass. |
