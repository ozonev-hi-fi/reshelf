# As-is (from code): Text and naming

Status: Draft | Version: 0.1 | Last updated: 2026-10-10

### AS-CODE-TXT-001 — Normalized-text pipeline order
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:40 › ConvertTo-ReshelfNormalizedText

Text normalization for matching runs in this exact order: trim leading/trailing whitespace, then apply Unicode NFKC normalization (compatibility decomposition + canonical composition — folds things like full-width Latin letters/digits, e.g. "ＢＢ", down to their ordinary ASCII-equivalent form), then lowercase using invariant culture (not the current locale).

### AS-CODE-TXT-002 — Normalized text keeps only letters, digits, and single spaces
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:40 › ConvertTo-ReshelfNormalizedText

After lowercasing, every character that is not a Unicode letter (`\p{L}`) or decimal digit (`\p{Nd}`) or whitespace is deleted outright (not replaced with a space or placeholder). Any run of remaining whitespace is then collapsed to a single regular space, and the result is trimmed again.

Example: `"The Wall (Remastered)!"` → `"the wall remastered"` (the parentheses and `!` are removed with nothing left in their place; no double space appears because the original space before `(` is preserved).

### AS-CODE-TXT-003 — Homoglyph normalization only fires on a specific pattern
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:81 › ConvertTo-ReshelfHomoglyphNormalizedText

Confusable-character replacement only happens when the text contains at least one genuine Latin letter (A-Z/a-z) AND at least one mapped confusable character AND zero letters that are neither Latin nor in the confusable map. Any text that is purely non-Latin (e.g. a real Cyrillic or Greek artist name) or that mixes in an unmapped foreign letter is returned completely untouched (`Changed = $false`) — this is a narrow, safety-first check, not general transliteration.

Example (illustration): `"Inсubus"` (with Cyrillic U+0441 in place of Latin "c") → `"Incubus"`, `Changed = $true`.

### AS-CODE-TXT-004 — Confusable map is a small fixed whitelist, not general transliteration
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:81 › ConvertTo-ReshelfHomoglyphNormalizedText

The lookalike map covers exactly 38 code points: 10 Cyrillic lowercase letters, 13 Cyrillic uppercase letters, 14 Greek uppercase letters, and only 1 Greek lowercase letter (omicron `ο`→`o` — the only Greek lowercase letter considered a true visual duplicate of a Latin letter in common fonts). Any Cyrillic/Greek letter not in this explicit list is left as-is (and, per AS-CODE-TXT-003, its presence blocks the whole replacement for that string).

### AS-CODE-TXT-005 — Japanese-script detection ranges
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:121 › Test-ReshelfHasJapaneseScript

Text is considered to contain Japanese script if it contains any Hiragana, Katakana, CJK Unified Ideographs (kanji), or half-width Katakana (Unicode range `ｦ`-`ﾟ`, U+FF66-FF9F) character. CJK ideographs alone could in principle also be plain Chinese text, but this function makes no such distinction — any kanji counts as "Japanese" here.

### AS-CODE-TXT-006 — Empty/whitespace text is never "romanized"
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:137 › Test-ReshelfIsRomanizedText

A null, empty, or whitespace-only string always returns false.

### AS-CODE-TXT-007 — Any Japanese-script text is never "romanized"
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:137 › Test-ReshelfIsRomanizedText

If the text contains any Japanese script (per AS-CODE-TXT-005), the function returns false, even if the same string also contains Latin letters mixed in.

### AS-CODE-TXT-008 — "Romanized" actually means "has a letter and isn't Japanese"
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:137 › Test-ReshelfIsRomanizedText

Otherwise, the function returns true as soon as the text contains at least one Unicode letter of ANY script — it does not specifically check for Latin/ASCII characters. (See also AS-CODE-DEF-TXT-001 below.)

### AS-CODE-TXT-009 — Bilingual join: early-outs that keep the original text
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:151 › Join-ReshelfBilingualName

`Join-ReshelfBilingualName` returns `Original` unchanged, without looking at `Romanized` at all, if `Original` already contains an `=` character anywhere, or if `Original` contains no Japanese script (per AS-CODE-TXT-005) — i.e. the join only ever applies to Japanese-script text that isn't already in a combined form.

### AS-CODE-TXT-010 — Bilingual join requires a usable romanized value
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:151 › Join-ReshelfBilingualName

If `Romanized` fails the "is romanized" check (AS-CODE-TXT-006/007/008 — i.e. it's null/empty/whitespace, or itself Japanese-scripted), `Original` is returned unchanged rather than forcing a join with a missing/invalid value.

### AS-CODE-TXT-011 — Bilingual join output format is fixed
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:151 › Join-ReshelfBilingualName

When a join does happen, the result is always exactly `"<Romanized> = <Original>"` — a single space, equals sign, single space — regardless of how inconsistently Discogs itself formats the spacing around `=` in its own text (the code only checks for the presence of `=`, not any particular surrounding spacing, when deciding whether to skip the join per AS-CODE-TXT-009).

Example: Romanized `"Rokkinpo Goroshi"`, Original `"ロッキンポ殺し"` → `"Rokkinpo Goroshi = ロッキンポ殺し"`.

### AS-CODE-TXT-012 — Invisible format characters are stripped, not replaced
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:228 › Remove-ReshelfInvisibleCharacters

Every character in Unicode category `Cf` ("format" — e.g. zero-width space, zero-width joiner/non-joiner, byte-order mark) is deleted from the text entirely, with nothing put in its place.

Example: `"B​-​Sides"` (zero-width spaces around the dash) → `"B-Sides"`.

### AS-CODE-TXT-013 — Title case only touches the first letter of each word, and only if it's lowercase
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:244 › ConvertTo-ReshelfTitleCase

Only a lowercase letter (`\p{Ll}`) that is the first character of the string or immediately follows whitespace gets uppercased; every other character — including the rest of each word — is left exactly as-is. A word that already starts with an uppercase letter, a digit, or a symbol is untouched.

Example: `"mccoy tyner"` → `"Mccoy Tyner"` (not `"McCoy Tyner"` — only the very first letter of each word is touched, so an internal capital is never produced).

### AS-CODE-TXT-014 — Track-filename number extraction tries three patterns in order
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:329 › ConvertFrom-ReshelfTrackFileName

After stripping the file extension, a leading track number is extracted by trying, in order: (1) `"N - Title"` / `"N – Title"` (digits, then an optional run of whitespace, a hyphen or en-dash, optional whitespace, then the rest as title) or `"N Title"` (digits then whitespace, no dash — tried as an alternative in the same step); (2) `"[NNN] Title"` / `"(NNN) Title"`, capped at 1-3 digits specifically so a 4-digit year in parentheses (e.g. `"(1999) ..."`) is never misread as a track number. If none match, `Number` stays `$null` and the whole trimmed base name becomes `Title`.

Example: `"[01] Blind Guardian - Don't Talk To Stranger.mp3"` → Number `1`, Title `"Blind Guardian - Don't Talk To Stranger"`.

### AS-CODE-TXT-015 — An Artist/Title split is always attempted, as a non-authoritative hint
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:329 › ConvertFrom-ReshelfTrackFileName

Independently of whether a track number was found, the resulting `Title` is always also tested against `"<Artist> - <Title>"` (non-greedy match on the first `" - "`/`" – "` separator found), producing candidate `ArtistPart`/`TitlePart` values. This is only a candidate, not a decision — a single-artist title can legitimately contain a dash too (e.g. `"Song - Live"`), so the caller decides whether to trust it.

### AS-CODE-TXT-016 — Safe filenames: invalid-character set is OS defaults plus a fixed Windows set
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:372 › ConvertTo-SafeFileName

The set of characters treated as invalid in a filename is the current OS's own `[System.IO.Path]::GetInvalidFileNameChars()` combined (de-duplicated) with an explicit fixed list: `< > : " / \ | ? *`. This guarantees Windows-unsafe characters are always rejected even if the code were run on an OS whose own invalid-character set is much smaller. Each distinct invalid character found is replaced with a literal underscore `_`, and one human-readable message per distinct character is recorded (prefixed with `"<Context>: "` when a non-empty `Context` was given).

### AS-CODE-TXT-017 — Safe filenames: trailing dots and spaces are always stripped
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:372 › ConvertTo-SafeFileName

Any trailing run of `.` or space characters at the very end of the name is removed (Windows disallows a trailing dot/space in a filename), with a substitution message logged if anything was trimmed.

### AS-CODE-TXT-018 — Safe filenames: reserved device names are checked only on the stem, suffixed not replaced
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:372 › ConvertTo-SafeFileName

Only the portion of the name before the first `.` (the "stem") is checked, case-insensitively, against the fixed reserved-name list: `CON, PRN, AUX, NUL, COM1-COM9, LPT1-LPT9`. If it matches, a literal underscore is appended right after the stem, leaving everything from the first dot onward (the extension) untouched.

Example: `"CON.flac"` → `"CON_.flac"`.

### AS-CODE-TXT-019 — Safe filenames: change flag compares only to the original input
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:372 › ConvertTo-SafeFileName

`WasChanged` is `true` only if the fully processed result differs from the original `Name` parameter as given — not from any intermediate step. `Substitutions` lists every change actually applied, in the order they were applied (character replacement, then trailing dot/space trim, then reserved-name suffix).

### AS-CODE-TXT-020 — A loose companion file must start with a letter of any script
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:417 › Test-ReshelfLooseCompanionFileName

A filename "starts with a letter" check uses `\p{L}`, so any Unicode letter (including non-ASCII scripts like Cyrillic) satisfies it, not only `A-Z`.

### AS-CODE-TXT-021 — Loose companion naming sanitizes before checking
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:444 › Get-ReshelfLooseCompanionFileName

The input filename is first run through the same invalid-character/trailing-dot/reserved-name sanitation as `ConvertTo-SafeFileName` (AS-CODE-TXT-016/017/018), and only then is the "starts with a letter" check (AS-CODE-TXT-020) applied to the sanitized result.

### AS-CODE-TXT-022 — Loose companion files that don't start with a letter get a kind-specific word prefix
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:444 › Get-ReshelfLooseCompanionFileName

If the sanitized name doesn't start with a letter, it is prefixed with a literal word plus a space, chosen by `Kind`: `cover`→`"Cover"`, `booklet`→`"Booklet"`, `photo`→`"Photo"`, `lyrics`→`"Lyrics"`, anything else (including an unrecognized `Kind` value) →`"Extra"`.

### AS-CODE-TXT-023 — Truncation is a no-op when already short enough
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:468 › ConvertTo-ReshelfTruncatedSegment

If `Prefix + Body + Suffix` is already at or under `MaxLength`, the three parts are concatenated and returned unchanged, with `Truncated = $false`.

### AS-CODE-TXT-024 — Truncation only ever shortens Body, with a 1-character floor
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:468 › ConvertTo-ReshelfTruncatedSegment

`Prefix` and `Suffix` are never touched — only `Body` is shortened, to a budget of `MaxLength - Prefix.Length - Suffix.Length`. If that budget would be less than 1, it is clamped up to 1 — meaning when `Prefix`+`Suffix` alone already reach or exceed `MaxLength`, the final result can still exceed `MaxLength` by keeping at least 1 body character, rather than guaranteeing the overall length cap.

### AS-CODE-TXT-025 — Truncation never splits a UTF-16 surrogate pair
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:468 › ConvertTo-ReshelfTruncatedSegment

If the computed cut point would land inside a UTF-16 surrogate pair (e.g. an emoji or a rare CJK extension character stored as two `char` code units), the cut point is moved back by one character to avoid producing a malformed/unpaired surrogate.

### AS-CODE-TXT-026 — Truncated body has trailing whitespace trimmed
Status: Draft | Source: legacy/scripts/common/Reshelf.Common.psm1:468 › ConvertTo-ReshelfTruncatedSegment

After cutting, the truncated `Body` has trailing whitespace removed (`.TrimEnd()`, the default whitespace set — space, tab, newline, etc. — not only plain spaces) before `Suffix` is reattached.

## Suspected defects

### AS-CODE-DEF-TXT-001
`legacy/scripts/common/Reshelf.Common.psm1:137-149` (`Test-ReshelfIsRomanizedText`) — despite its name, this function does not verify the text is actually Latin/romanized. It returns true for any non-Japanese string containing at least one Unicode letter of any script, so pure Cyrillic, Greek, or Arabic text would also be classified as "romanized". This feeds directly into `Join-ReshelfBilingualName`'s decision to join (AS-CODE-TXT-010), so a non-Japanese, non-Latin `Romanized` value could incorrectly be accepted and joined as if it were a valid romanization.

### AS-CODE-DEF-TXT-002
`legacy/scripts/common/Reshelf.Common.psm1:347` (`ConvertFrom-ReshelfTrackFileName`) — the bracket/paren pattern `^[\[\(](\d{1,3})[\]\)]\s*(?:[-–]\s*)?(.+)$` matches the opening and closing delimiters independently, so a mismatched pair like `"[01).mp3"` or `"(01].mp3"` is still accepted and yields track number `01`.

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.1 | 2026-10-10 | Phase 2 draft from code. |
