# As-Is (from code): Lossy Tracking

Status: Draft | Version: 0.1 | Last updated: 2026-10-10

Area code: LSY. Source: `legacy/scripts/common/Reshelf.LossyTracking.psm1` only. Read directly from
code, independent of `docs/next-gen/br/as-is-from-docs/`.

### AS-CODE-LSY-001 — Ledger file location
Status: Draft | Source: legacy/scripts/common/Reshelf.LossyTracking.psm1:6 › Get-ReshelfLossyTrackingLedgerPath

The lossy-tracking ledger is a single JSON file named `lossy-tracking.json`, stored directly under the
resolved data home folder (same folder as the apply log, not a subfolder).

### AS-CODE-LSY-002 — Ledger read: missing vs invalid
Status: Draft | Source: legacy/scripts/common/Reshelf.LossyTracking.psm1:16 › Get-ReshelfLossyTrackingLedger

If the ledger file does not exist yet, reading it returns an empty array (not an error). If the file
exists but fails schema validation against the `lossy-tracking` schema, reading it throws
`"Lossy-tracking ledger at '<path>' does not match the lossy-tracking schema."`.

### AS-CODE-LSY-003 — Entry lookup by stable key
Status: Draft | Source: legacy/scripts/common/Reshelf.LossyTracking.psm1:36 › Get-ReshelfLossyTrackingEntry

Looking up an entry by `stableKey` returns the first matching row, or nothing if none matches.

### AS-CODE-LSY-004 — Re-adding an existing entry only refreshes its check timestamp and path
Status: Draft | Source: legacy/scripts/common/Reshelf.LossyTracking.psm1:51 › Add-ReshelfLossyTrackingEntry

When an entry for the given `stableKey` already exists, adding it again updates only two fields:
`lastCheckedUtc` (to now) and `targetPath` (to the newly given value) — every other field (`artist`,
`album`, `year`, `format`, `status`, `firstDetectedUtc`, `notes`) is left exactly as it was. The
target path is treated as "latest known location", not a first-sighting snapshot, because `targetRoot`
or the naming templates can change between runs and leave a stale path otherwise.

### AS-CODE-LSY-005 — New entry defaults
Status: Draft | Source: legacy/scripts/common/Reshelf.LossyTracking.psm1:51 › Add-ReshelfLossyTrackingEntry

A brand-new ledger entry (no existing row for that `stableKey`) is created with: `status` =
`pending-upgrade`, `firstDetectedUtc` = `lastCheckedUtc` = the current time (UTC,
`yyyy-MM-ddTHH:mm:ss.fffZ`), `upgradedUtc` = null, and `notes` = `''` (empty string, not null).

### AS-CODE-LSY-006 — Status enum has exactly three values
Status: Draft | Source: legacy/scripts/common/Reshelf.LossyTracking.psm1:205 › Set-ReshelfLossyTrackingStatus

A lossy-tracking entry's `status` is one of exactly: `pending-upgrade`, `upgraded`, `ignored` —
enforced by `ValidateSet` on the generic status setter, and matched by the literal default
(`pending-upgrade`) a new entry is created with.

### AS-CODE-LSY-007 — Marking an entry upgraded
Status: Draft | Source: legacy/scripts/common/Reshelf.LossyTracking.psm1:113 › Set-ReshelfLossyTrackingUpgraded

Marking an entry upgraded sets `status` = `upgraded` and `upgradedUtc` = the current time (UTC). If no
entry exists for the given `stableKey`, this is not treated as an error: a warning is written and the
unchanged ledger is returned — defensive handling, not a hard assumption that a prior
`pending-upgrade` row must exist.

### AS-CODE-LSY-008 — Updating an entry's target path
Status: Draft | Source: legacy/scripts/common/Reshelf.LossyTracking.psm1:146 › Set-ReshelfLossyTrackingTargetPath

Updates only the `targetPath` field of an existing entry. Same "entry not found → warn, no-op, return
unchanged ledger" handling as AS-CODE-LSY-007.

### AS-CODE-LSY-009 — Marking an entry ignored touches only its status
Status: Draft | Source: legacy/scripts/common/Reshelf.LossyTracking.psm1:177 › Set-ReshelfLossyTrackingIgnored

Marking an entry ignored sets `status` = `ignored` and does not touch `upgradedUtc` (unlike
`Set-ReshelfLossyTrackingStatus`'s general handling — see AS-CODE-LSY-010 — this dedicated setter
leaves it as-is). Same "entry not found → warn, no-op" handling as AS-CODE-LSY-007.

### AS-CODE-LSY-010 — Generic status setter manages upgradedUtc automatically
Status: Draft | Source: legacy/scripts/common/Reshelf.LossyTracking.psm1:205 › Set-ReshelfLossyTrackingStatus

Setting status to `upgraded` via the generic setter sets `upgradedUtc` to the current time only if it
is not already set (re-saving an already-upgraded entry, e.g. for a notes-only edit, does not bump the
timestamp forward again). Setting status to anything other than `upgraded` always clears `upgradedUtc`
back to null, including moving an entry back from `upgraded` to `pending-upgrade` or `ignored`.

### AS-CODE-LSY-011 — Notes: omitted vs explicitly cleared are distinct
Status: Draft | Source: legacy/scripts/common/Reshelf.LossyTracking.psm1:205 › Set-ReshelfLossyTrackingStatus

The `Notes` parameter distinguishes "not supplied at all" (existing notes left untouched) from
"explicitly passed as an empty string" (notes cleared), using `$PSBoundParameters.ContainsKey('Notes')`
rather than relying on the string parameter's own default — a plain `[string]$Notes` parameter cannot
otherwise tell those two cases apart, since PowerShell binds an unsupplied string parameter to `''`
just like an explicit empty-string argument would.

### AS-CODE-LSY-012 — Removing an entry deletes the row permanently, unlike "ignored"
Status: Draft | Source: legacy/scripts/common/Reshelf.LossyTracking.psm1:254 › Remove-ReshelfLossyTrackingEntry

Removing an entry drops its row from the ledger entirely, distinct from marking it `ignored` (which
keeps the row, just flagged as deliberately not-upgrading). Removal is for a mistaken entry, a
duplicate, or one the user no longer wants tracked at all. Same "entry not found → warn, no-op" handling
as AS-CODE-LSY-007.

### AS-CODE-LSY-013 — Every mutation rewrites the whole ledger file
Status: Draft | Source: legacy/scripts/common/Reshelf.LossyTracking.psm1:51 › Add-ReshelfLossyTrackingEntry (and all setters/remove)

Every add/update/remove operation writes the entire ledger array back to disk as one JSON file (schema
`lossy-tracking`, depth 10) — there is no row-level or partial persistence; a mutation always
round-trips the full in-memory ledger.

### AS-CODE-LSY-014 — "Stable key not found" is never a thrown error in any mutator
Status: Draft | Source: legacy/scripts/common/Reshelf.LossyTracking.psm1:113,146,177,205,254

Across all five mutating functions (`Set-ReshelfLossyTrackingUpgraded`, `Set-ReshelfLossyTrackingTargetPath`,
`Set-ReshelfLossyTrackingIgnored`, `Set-ReshelfLossyTrackingStatus`, `Remove-ReshelfLossyTrackingEntry`),
a `stableKey` with no matching ledger entry is handled identically: a `Write-Warning` is emitted and the
unchanged ledger is returned, never a thrown exception. Only `Add-ReshelfLossyTrackingEntry` creates a
row when one is missing (AS-CODE-LSY-005); every other function treats "nothing to do" as a soft,
non-fatal outcome.

## Changelog

| Version | Date | Changes |
|---|---|---|
| 0.1 | 2026-10-10 | Phase 2 draft from code. |
