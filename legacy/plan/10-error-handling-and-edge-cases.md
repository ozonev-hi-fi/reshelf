# Step 10 — Error Handling and Edge Cases

## Purpose / scope

Resolve the manifesto's remaining §9 open questions with concrete,
simplicity-favoring defaults, since this is a personal single-user tool, not
a multi-user product. These concerns cut across
[05](05-recognition-module.md), [06](06-edit-proposal-module.md), and
[08](08-implementation-module.md) rather than belonging to one module, so
they're consolidated here and referenced from those files.

## Re-runs and duplicate detection

Driven entirely by `stableKey` ([03](03-domain-model-and-json-schemas.md)) plus
a cheap **source file-set hash** (sorted list of `filename + size` for every
audio file in the release, hashed).

| Situation | Result |
|---|---|
| `stableKey` not in target at all | `targetAction = "create-new"` |
| `stableKey` in target, file-set hash matches | `targetAction = "skip-existing-identical"` — no work, no Discogs re-query |
| `stableKey` in target, file-set hash differs, source is lossless and target is lossy | `targetAction = "update-existing"`, `lossyLossless.action = "replace-existing"` |
| `stableKey` in target, file-set hash differs, not a lossy→lossless case | `targetAction = "conflict"`, `humanReview.required = true` — never silently overwritten |
| Same release imported twice from two different sources in one session | Second occurrence resolves to whichever of the two rows above applies against the *first occurrence's proposed result*, treating it like any other existing-target comparison |

Favor safety over silent overwrite: anything that isn't a clean "new" or a
clean "lossy→lossless upgrade" always requires a human look.

## Session persistence and resume

`session.json`'s `stage` field is the single source of truth for "what to do
next":

| `stage` | Meaning | Next command |
|---|---|---|
| `recognized` | Recognition done | `Reshelf.ps1 propose -SessionId <id>` |
| `proposed` | Proposal done, awaiting review | `Reshelf.ps1 ui start`, review, then `Reshelf.ps1 session mark-reviewed -SessionId <id>` |
| `reviewed` | UI approvals saved | `Reshelf.ps1 apply -SessionId <id>` |
| `applied` | Implementation finished (a plain skip — an unresolved/rejected release — doesn't count as a failure here) | nothing — session complete |
| `partially-applied` | Implementation stopped with **at least one release actually failed** (as opposed to merely skipped) | `Reshelf.ps1 apply -SessionId <id>` again — reruns only unresolved/failed releases via `apply-log.json` |

`Reshelf.ps1 session resume <id>` reads `stage` and prints the exact next
command, so resuming a session never requires remembering where things were
left off.

Implementation itself is naturally resumable per-release: `apply-log.json`
tracks status per `stableKey`, so re-running `apply` only touches releases
that are missing or `status: "failed"` from the log.

## Ambiguous/unrecognizable folders

Never guessed. Anything a heuristic in [05](05-recognition-module.md) can't
confidently classify goes into `unrecognized[]` and is resolved only through
a human-editable `overrides.json`, optionally assisted by an AI skill that
helps populate it faster (per manifesto §8) — the skill never bypasses this
gate or edits code.

## Windows path length

- Internally, use the `\\?\` long-path prefix when calling .NET/PowerShell
  file APIs, lifting the practical ~260-char limit.
- Even so, keep human-facing names short by construction (the manifesto's own
  naming rules are already fairly compact).
- If a fully-assembled target path would still exceed ~250 characters,
  truncate the human-readable part of the folder/file name (never drop the
  structural `NN ` track-number prefix or the `yyyy ` year prefix) and record
  the truncation in `apply-log.json` so it's visible, not silent.
- External tools that may not understand `\\?\` (verify per-tool during the
  [scaffolding spike](12-build-order-and-milestones.md)) run against
  short-named files inside the staging area
  ([08](08-implementation-module.md)), with the final rename to the full name
  happening only at the atomic-commit step.

## Invalid filename characters

`ConvertTo-SafeFileName` (in `Reshelf.Common.psm1`) handles:
- Windows-invalid characters: `< > : " / \ | ? *`
- Trailing dots/spaces (silently stripped by Windows, but explicit handling
  avoids surprises).
- Reserved device names: `CON`, `PRN`, `AUX`, `NUL`, `COM1`–`COM9`, `LPT1`–`LPT9` —
  checked against the part of the name before its first dot, so `CON.flac`
  is caught too, not just a bare `CON`.

Every substitution this function makes is recorded (e.g. in
`recognitionFlags`/`proposal` notes) and surfaced in
[07-editing-ui-module.md](07-editing-ui-module.md) — never silently applied
without the user being able to see what changed from the "natural" name.

## Definition of done

- Fixture tests (see [11](11-testing-and-verification-strategy.md)) cover
  every row of the re-run/duplicate table above with a real before/after
  assertion.
- A resume test walks a session through all five `stage` values and confirms
  `session resume` prints the correct next command at each one.
- A path-length fixture (deeply nested fixture tree) and an invalid-character
  fixture (`:`, trailing dot, `CON` as a folder name) both produce correct,
  visibly-flagged output rather than a crash or silent data loss.
