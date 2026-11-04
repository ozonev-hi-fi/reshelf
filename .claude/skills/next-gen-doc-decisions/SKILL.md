---
name: next-gen-doc-decisions
description: Decision work in Reshelf's docs/next-gen/ — running a phase 4 area session, grilling one decision with the user, recording a decision (D-number) across the docs, or closing an area with a coverage check and commit commands.
---

# Next-gen doc decisions

The **what** of each phase lives in its brief (`docs/next-gen/sessions/`) and the doc rules
(`docs/next-gen/README.md#doc-rules`). This skill is the **how**: the conversation, the ripple of
one decision through the docs, and the area close.

## 1. Conversation loop

Run this loop for every topic:

1. **Agenda.** When the user raises several points, first list them all, each restated in words.
   Then take one per message, in that order. Carry open points forward until each is closed.
2. **Check first.** Read the docs that hold the topic (legacy facts in `br/as-is-merged/`, the NG
   delta docs, the decision log) before proposing anything. Cite `file:line`. Mark each claim
   *confirmed* (seen in a file) or *guess*.
3. **Example first.** Open with one concrete example: a path, a mock-up of a UI panel, a
   before/after. The rule comes after it. When the user does not understand, rewrite it simpler
   with a smaller example.
4. **Options.** A short table, one recommendation with its reason, and a short answer format
   (e.g. "1 yes, 2 b").
5. **Echo.** When the answer adds new ideas, restate it as a checkable list and get a yes before
   recording.
6. **Record** (section 2), report what changed with links, then name the next topic.

Every code and label gets its meaning in words in the same sentence (project `CLAUDE.md`, "no bare
codes"): requirement IDs, area codes, decision numbers, and labels such as keep / fix / drop or
the MoSCoW values.

## 2. Recording a decision: the ripple

One decision touches many docs. Done = every row below checked, and a grep shows the new `D<n>`
in the decision log and in each target doc.

| # | Place | Edit |
|---|---|---|
| 1 | `docs/next-gen/inbox/raw-notes.md` | New `\| D<n> \| decision \| reason \| → \|` row in the matching topic section. The decision text ends with "Decided <date> (phase <n>, area <AREA>)." |
| 2 | same file, intro line of Part 2 | Decision range and the next free number |
| 3 | same file, header + changelog | Version and date; one changelog row per session, extended per decision |
| 4 | NG delta doc (`01`–`11`) | New or changed `NG-*` requirement (next free ID, IDs are never reused), `D<n>` added to `Source:`, header, changelog |
| 5 | `br/to-be/README.md` | NG → to-be file map (an owner row for every new NG ID), the NG total (intro and "Total:" line), the open-points table, changelog |
| 6 | the phase brief | NG count lines, changelog |
| 7 | `docs/next-gen/README.md` | Index row of every changed doc (status, version), the decision range, changelog |
| 8 | `sessions/tech-spec.md` | Only for a coding rule or a tool-research input |
| 9 | the to-be area file | `Source:` and text of the affected `TB-*` items |

A removed feature is mentioned only in its own decision entry; live text describes what exists.

## 3. Closing an area

1. Show the final to-be list as a table: ID, title, origins in words, priority, example. Add the
   lists "Suspected defects decided", "Dropped" and "Process only". Wait for an explicit yes.
2. Write `br/to-be/NN-<area>.md` in the format of `br/to-be/README.md#requirement-format`
   (EARS sentence first).
3. Coverage grep: every `AS-<AREA>-NNN`, every NG ID the file map gives this area, and every
   `CF-<AREA>-NNN` appears in the new file.
4. Set the area row to Done with the last ID; changelog.
5. Print the `git add` and `git commit` commands for the user to run. One commit = one finished
   area, including every side change made during it.

## 4. Editing practice

- Edit docs with the Edit tool: exact, reviewable, safe with `#`, quotes and tables. Read the
  target lines first.
- Use today's date in headers and changelog rows.
- Examples follow doc rule 10: public releases or invented names.
