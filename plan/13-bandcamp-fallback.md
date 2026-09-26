# Step 13 — Bandcamp Fallback (feature request, research needed)

## Status: research needed, not started

This step is **not implemented**. It is a feature request raised during
[12](12-build-order-and-milestones.md) milestone 3's real-data UI review, and
must be researched before any code is written — the questions below need
answers first, some of which may mean this isn't feasible at all, or not for
free.

## Purpose / scope

[06](06-edit-proposal-module.md) only ever queries Discogs. Several real
releases from the milestone 3 sample are not on Discogs at all, but are
findable on Bandcamp:

- `Axion - Cybernetic Enhancements Activated` —
  https://retrowavetouchrecords.bandcamp.com/track/axion-cybernetic-enhancements-activated-2
- `Straplocked & Ray Gun Hero - Stalemate` —
  https://burningowlrecords.bandcamp.com/album/stalemate
- `Wuneny - whatever singularity` —
  https://moonleedistribution.bandcamp.com/album/vuneny-whatever-singularity
  (noted during review: this page's own metadata is too sparse/inconsistent
  to actually help with file naming/tagging — a Bandcamp hit isn't
  automatically a *useful* hit; see Research questions below)

The idea: when a release is `discogsMatch.status: "not-found"`, also try
Bandcamp before giving up, following the same trust order Discogs has
(§ "Casing" in [06](06-edit-proposal-module.md)) — an encyclopedia's own
text/casing wins over a locally-derived fallback name.

## Research questions (answer before writing any code)

1. **Is there a public search API at all?** Bandcamp has no documented public
   search/metadata API equivalent to Discogs's `/database/search`. Confirm
   whether one exists (even undocumented/internal) before assuming scraping
   is the only option.
2. **If no API: is scraping allowed?** Read Bandcamp's Terms of Service and
   `robots.txt` for the exact hosts involved (artist subdomains like
   `retrowavetouchrecords.bandcamp.com`, not just `bandcamp.com` itself).
   A tool built for personal, non-commercial, low-volume use is not the same
   question as "is this allowed at all" — get a real answer, don't assume.
3. **Is per-page structured data available and stable?** A Bandcamp album/
   track page embeds a `data-tralbum` JSON blob and/or JSON-LD in its HTML —
   confirm both exist reliably across pages (label-hosted vs. artist-hosted
   subdomains, older vs. newer page templates) and what fields they actually
   carry (title, artist, release date, tracklist, cover image URL). This
   would avoid true HTML scraping/parsing in favor of reading one embedded
   JSON blob — check whether that distinction matters for question 2's ToS
   answer.
4. **Search mechanism**: with no API, how would Reshelf even *find* the
   Bandcamp page for a given artist/album in the first place (Discogs's own
   `/database/search` has no Bandcamp equivalent)? A general web search
   (which engine, what ToS/cost) is presumably the only option — confirm
   what's free and usable from a script.
5. **Is it free?** Confirm no paid tier is required for whatever mechanism
   question 4 lands on, at the request volume this tool actually needs
   (personal collection size, not bulk).
6. **Rate limits**: whatever mechanism is chosen, what limits apply, and does
   [02](02-discogs-account-and-api-access.md)'s cache/throttle design
   (`Invoke-DiscogsRequest`) generalize to it or does Bandcamp need its own?
7. **Data quality, case by case**: even once fetchable, is a Bandcamp page's
   data actually *usable* for naming/tagging (manifesto §5) or just a
   confirmation the release exists? The Wuneny case above suggests sometimes
   it's the latter — the research should produce a candid answer per real
   sample case, not just "found it" (see the three example URLs above).

## Decisions & rationale

- **Not started without answers to the above**: unlike every other step in
  this plan, this one could turn out to be infeasible (ToS) or not worth it
  (data quality) — writing code before the research would risk building
  against a source that can't legally or usefully be used long-term.
- **Same trust order as Discogs, if built**: Bandcamp would sit alongside
  Discogs as an encyclopedia source, with the same casing priority — never a
  second heuristic bolted onto the fallback (Title Case) path.

## Definition of done (for this step, once un-blocked)

- All seven research questions above have real answers, written down here.
- Only then: a design for the actual search/fetch mechanism, cache/throttle
  strategy, and how a Bandcamp match's data folds into
  `discogsMatch`/a new `bandcampMatch` field in `proposal.json`
  ([03](03-domain-model-and-json-schemas.md)).
