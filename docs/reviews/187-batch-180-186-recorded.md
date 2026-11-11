# Review: wave/187-batch-180-186-recorded

PR #145. It adds `## Resuming after 2026-11-11, T141 alone, batch
181-184, then T169 and T117` at the top of `tasks/STATUS.md`, recording
waves 180-186 (PRs #138-#144). Only that file changes.

A fresh context reviewed the branch's first head against its sources.

**Verdict: correct, with one inconsistency, one dropped item, one
optional addition and a nit. No blocker.**

## What was reviewed

- **The table.** All seven rows against `git log origin/main`: wave,
  task, PR and main sha, in merge order (`ba490d0` #138 ... `6f89e9b`
  #144).
- **What each review caught.** Each claim is in its record: 180 (the lint
  missed `--script`, `${GODOT}`, a wrapping variable), 183 (the `$`
  anchor, 17 of 33 lines), 181 (a malformed difficulty file accepted
  through a SCRIPT ERROR), 182 (the bridge falling mid-day, the walk
  cost unheld), 186 (the at-least-one-iteration and overrun rules).
- **The statuses.** T165 `wip`; T141, T158, T167, T168, T169, T117
  `done`.
- **The prereqs in "Next"**, against each task file's `Prereqs:` line:
  T127, T124, T125, T161 and T89 hold as written.
- **The manual checks** listed for T165, T158, T117, T168 and T167 match
  each task file's `## Manual check`; T141 and T169 have none.
- **The CI claim.** `gh run list --branch main` showed #138-#144
  `in_progress` and #137 a success.

## Findings

1. **"Then T166 (needs T165, done)"** contradicted the section itself and
   T165's row, both `wip`.
2. **Dropped from the previous section's waiting list:** the two
   exit-leak manual checks, and T162's question of reporting the engine's
   use-after-free upstream; T157's clip and boss-model details too.
3. **Optional:** the follow-ups the reviews named (T169's import gap,
   T168's process group, T167's known false positive and `preload`, T117's
   changed measurement decision) appeared only in rows.
4. **Nit:** "every one found something ... green" is strong for review
   185, whose verdict was two nits and a note.

The reviewer also noted that #138's CI run had been `in_progress` for about
1h30: the next session should look for a hung job, not only a queued one.

## What was done about them

1. "Next" now says T165 is built and merged but `wip` until the owner's
   manual check, that T166 can start on the merged code, and that whether
   to wait is the owner's call.
2. The waiting list carries the two exit-leak checks, the upstream
   question, and T157's clip and boss model.
3. A paragraph "Follow-ups the reviews named, not opened as tasks" lists
   them.
4. The sentence now says "all but 185".

And "Next" says to look for a hung CI job on main.
