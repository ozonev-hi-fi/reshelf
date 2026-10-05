# Brief — Phase 2: as-is BR from code

Roadmap phase: 2 | Output: `docs/next-gen/br/as-is-from-code.md` (one file, or a folder if it gets large)

## Goal

Describe the **current** behavior of the legacy app as business requirements. Read it from the source code only. This gives an independent second view, which Phase 3 compares with Phase 1.

## Rules

- **Rule D2**: describe behavior only. When code looks buggy, write it under "Suspected defects" with `file:line`.
- Do **not** read the Phase 1 output, `legacy/README.md` or the `legacy/plan/` files. Independence is the point of this phase.
- Follow the [doc rules](../README.md#doc-rules). Use the ID prefix `AS-CODE-<AREA>-NNN`.
- Use the as-is requirement format of decision D64: no `Priority`; `Source:` = `legacy/scripts/<file>:<line> › <function>`; one behavior rule per ID, with 1–3 examples. You may read the format section of `docs/next-gen/br/as-is-from-docs/README.md`, but nothing else in that folder.
- Use the same area codes and file split as Phase 1 where they fit (DAT, TXT, SET, SES, REC, DSC, MAT, PRP, REV, APL, LSY, CLI, BND, ERR). This makes the Phase 3 comparison area by area easy.

## Inputs

- `legacy/scripts/**` (modules in `legacy/scripts/common/*.psm1`, CLI `legacy/scripts/Reshelf.ps1`, UI server)
- `legacy/ui/*`
- `legacy/config/settings.default.json`

## Steps

1. Go through each module and each public function.
2. For each area, write the behavior as requirements: inputs, outputs, rules, edge cases and error handling. Add acceptance examples.
3. Record every hidden rule, threshold and magic value. Examples: rate limit, cache TTL, candidate count, ±3 s duration tolerance, the year 1900 placeholder.
4. Collect the suspected defects.
5. Update the roadmap status. Commit.

## Done when

Every exported function of every module maps to at least one requirement or one suspected defect.
