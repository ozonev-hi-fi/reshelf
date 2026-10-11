# library-mapper: overview

## Why this exists

Running the legacy Reshelf app on a real library doesn't produce a perfectly
organized result: legacy has known recognition bugs, and manual review during
organizing can also miss things (a wrong Discogs match gets approved, a year
or title has a typo). Separately, next-gen's own matching-algorithm area (MAT,
area 07 — see `docs/next-gen/br/as-is-from-code/07-proposal-matching.md`) has
not been merged yet (`docs/next-gen/br/as-is-merged/README.md` lists it "Not
started").

If you have an older, rougher copy of your library from *before* it was run
through legacy — not an exact mirror, just a rough earlier backup — comparing
it against the organized result gives you real "before → after" examples.
These are useful for two separate things:

1. **Test cases for release recognition.** A "before" folder that was messy
   enough to need manual help, paired with its correct "after" release, is
   exactly the kind of real-world case next-gen's matching logic should be
   checked against.
2. **Catching approved mistakes.** The "after" state isn't automatically
   correct just because a human reviewed it — re-verifying it against real
   Discogs data can surface a wrong match, a typo, or a wrong year that slipped
   through.

## The two pieces, and why they're split this way

| Step | Who does it | Why |
|---|---|---|
| Walk a library root, read tags/cover art/companion files, write a structured map | **A script** (`New-ReshelfLibraryMap.ps1`) | Deterministic, mechanical, reusable by any contributor against their own library |
| Match "before" releases to "after" releases, judge which matches are trustworthy, re-verify against Discogs | **A Claude session**, following `03-matching-and-verification-procedure.md` | Legacy's own matching already has bugs — a second automated script making the same kind of judgment calls isn't trusted to be more reliable. This step needs live judgment, not a fixed algorithm run blind. |

Nothing from this tool ever commits a contributor's actual collection data.
The script writes its output under `local/` at the repo root (gitignored); the
match-report a Claude session produces also lives there.

## Generic labels, not storage types

Whatever two physical places your "before" and "after" states live (an old
backup drive, a cloud copy, two folders on the same disk — it doesn't matter),
refer to them in this tool, its config, and any generated output only as
`before` and `after` (the `-Label` parameter is free text, but this is the
documented convention). Nothing about a contributor's actual storage setup
should ever need to appear in a committed file.

## Where to go next

- Generating a map for your own library: [`02-generating-a-map.md`](02-generating-a-map.md)
- What's inside a generated map: [`01-map-schema-reference.md`](01-map-schema-reference.md)
- Running an actual before/after matching session: [`03-matching-and-verification-procedure.md`](03-matching-and-verification-procedure.md)
