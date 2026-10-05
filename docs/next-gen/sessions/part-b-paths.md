# Brief — Docs part B: paths twist

Roadmap phase: B | Output: [11-paths-and-devices.md](../11-paths-and-devices.md) filled in, commit 2

## Goal

Turn the "Paths twist" ideas into requirements, and resolve every `→ Part B` open point in the other docs.

## Read first

1. [../README.md](../README.md): the doc rules. Follow them.
2. [../inbox/raw-notes.md](../inbox/raw-notes.md): the "Paths twist" section, and the decision log D1–D48. The log holds the directions agreed so far, for example the dependency rule (D38) and the statuses (D43).
3. [../11-paths-and-devices.md](../11-paths-and-devices.md): the list of open points.
4. The facts on legacy path handling, in "Today vs next-gen" of [07](../07-library-and-quality.md) and [10](../10-platform-and-dependencies.md).

## Steps

1. Grill the user on the paths model. Use the `grilling` skill. Topics:
   - the default source folder vs a source given per run;
   - one library with alternative paths (`D:\` vs `E:\`) vs device identity (a hardware or volume ID mapped to the current drive letter);
   - temp vs target, including target == temp;
   - read-only rules: source and target are never written; apply writes only to temp;
   - how Overwrite and Keep both (NG-LIB-009) run under these rules;
   - relative paths in the lossy tracker and the library index, resolved against target first, then temp;
   - converting legacy absolute lossy paths on import;
   - what happens when a location disappears in the middle of an operation.
2. Write the agreed requirements as `NG-PTH-NNN` in `11-paths-and-devices.md`.
3. Add new decisions to the decision log as `D49`, `D50`, and so on.
4. Resolve every `→ Part B` marker in the other docs. Update or add requirements, and remove the open point.
5. Update the headers, changelogs, the index in `README.md`, and the phase B status in `00-roadmap.md`.
6. Commit on `develop` (commit 2).

## Done when

- `11-paths-and-devices.md` is no longer a stub.
- Searching for `Part B` finds only historical changelog rows.
- The user has confirmed the decisions.
