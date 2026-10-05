# Brief — Phase 3: merge into the to-be BR

Roadmap phase: 3 | Output: `docs/next-gen/br/to-be.md` (or a folder), status Agreed

## Goal

Produce one to-be BR: the merged as-is behavior plus the next-gen delta.

## Read first

- [../README.md](../README.md): the doc rules.
- The phase 1 and phase 2 outputs in `docs/next-gen/br/`.
- The delta docs `01`–`11` and the decision log in [../inbox/raw-notes.md](../inbox/raw-notes.md).

## Steps

1. Compare the two as-is BRs area by area. Make a table: agree / only in docs / only in code / conflict.
2. For each conflict, read the code, tests and docs needed to understand it. If it is still unclear, ask the user. Use the `grilling` skill and ask in rounds.
3. Decide every suspected defect with the user: keep, fix, or drop.
4. Apply the delta. Each next-gen requirement replaces or extends the matching as-is behavior. Every to-be requirement links to its sources (AS-DOC / AS-CODE / NG IDs).
5. Resolve the "Open points" that the delta docs left for the merge (for example NG-LIB-003, the open points of NG-APP and NG-PLT).
6. Ask the user to review. Set the status to `Agreed` only after they agree.
7. Update the roadmap status and the changelogs. Commit.

## Done when

- No open conflict and no undecided suspected defect is left.
- Every NG requirement appears in the to-be BR.
- The user has marked it Agreed.
