# Manual UI verification checklist

This is the one piece of plan/11 that cannot be automated: the editing UI (step 07) uses the
File System Access API, which needs a real browser and a real folder picker. Run this checklist
in Chrome at least once, per plan/11's Definition of Done.

## How to start

From the repo root:

```
pwsh scripts/Tagger.ps1 ui start
```

Open the printed local URL in Chrome. Point the folder picker at a session's data folder
(`<repo>\.data\sessions\<sessionId>` by default, or `$env:TAGGER_HOME\sessions\<sessionId>` if
that's set) that already has a `proposal.json` — run `recognize` then `propose` against a sample
source first if you don't have one yet.

## Checklist

- [ ] Open a session folder via the picker. Expected: the proposal loads and releases are listed.
- [ ] Edit a proposed release or track name. Expected: the edit is reflected immediately in the UI.
- [ ] Change the selected cover-art candidate. Expected: the new candidate becomes the chosen one.
- [ ] Resolve an ambiguous Discogs match by picking a candidate. Expected: `humanReview.required`
      clears for that release once resolved.
- [ ] Approve a release. Expected: the release is marked approved/reviewed.
- [ ] Save, reload the page, confirm all edits persisted. Expected: re-opening the same folder shows
      the same edits, read back from `proposal.json`.
- [ ] Confirm `proposal.backup.json` holds the pre-save version. Expected: the backup file exists
      next to `proposal.json` and contains the values from before the save.
- [ ] Revoke folder permission mid-session (via the browser's site/permissions UI) and confirm the
      app shows a retry prompt instead of a silent failure. Expected: a visible error/retry, not a
      silently stuck or broken UI.

## Last run

- Date:
- Browser/version:
- Result: pass / fail (note any failing step)
