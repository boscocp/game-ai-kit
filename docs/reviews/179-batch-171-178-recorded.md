# Review: wave/179-batch-171-178-recorded

PR #137. It adds `## Resuming after 2026-11-11` at the top of
`tasks/STATUS.md`, recording waves 171-178 (PRs #129-#136), and raises
`TIMEOUT_SECONDS` in `scripts/run_selftests.py` from 120 to 300 because
main's CI went red on `library_check.py --self-test`.

A fresh context reviewed head `6843dfc` on `review/179`, cut from
`origin/wave/179-batch-171-178-recorded`.

**Verdict: changes requested. No blocker; three shoulds and three nits.**
The table is right in every cell, and the timeout change does what it says.
The plant that proves a hang is caught does not depend on the constant. The
shoulds are about the record. It miscounts the reviews. It says main's CI
"went red on that alone" when the red runs stopped before most of
`make check` ran. It also drops three items that wait for the owner. The
300 s is a guess, and that should be written down as one.

## What was checked and held

- **The table** (`tasks/STATUS.md:13-22`). Each row was checked against
  `git log --oneline origin/main -12`: the wave, task, PR number and main
  sha are right for all eight (`42ae8ba` #129 T163 ... `5aa1106` #136 T121).
- **The review records**: `docs/reviews/171-*` to `178-*` all exist.
- **The six claims about what reviews found.** Each is in its record:
  - 171 finding 1: N20 refuses the tests T164 must write.
  - 178 finding 1: `append` never looks at the file.
  - 173 finding 1: 224 of 2400 holder choices returned -1, which is 9.3%.
  - 175 finding 1: the x3 delay is set only by dead grants.
  - 176 finding 2: `new()` in an instance method builds the subclass.
  - 177 findings 1-2: two runners still exit 0.
- **The decisions.** Decision 3 matches the 2026-11-10 section's
  wording. Decision 5 matches the code: `release.py:131` lists
  `"modules/"` among the files the build reads. Decisions 1, 2 and 4 are
  the owner's words, so this review cannot check them against a source.
- **The manual-check count** (`STATUS.md:51-54`). All eight PR bodies
  say `selected: everything`. The rebase conflict counts cannot be checked
  after a squash merge, so they are taken as reported.
- **The next steps** (`STATUS.md:69-72`), against each task file's
  `Prereqs:` line:
  - T158 needs T157 (done).
  - T165 needs T164 (done).
  - T166 needs T165.
  - T167 needs T162 (done).
  - T161 needs T160, T162, T158, T140, T141, T146, T148 and T121. All of
    these are done except T141 and T158, which come before it. So T161
    last is right.
- **`make lint-status lint-tasks`**: exit 0.
- **The CI diagnosis.** Four main runs failed: #132 `42968406836`, #133
  `42970926309`, #134 `42973874110` and #135 `42975262064`. In each,
  `--log-failed` shows `library_check.py TIMEOUT after 120s`, then
  `Makefile:306: lint-selftests`. No other script in `lint-selftests`
  failed in any of them.
- **The local time.** `python3 scripts/library_check.py --self-test` took
  74.7 s here (12 threads), with exit 0. That matches the PR's "75 s".
- **A planted hang is still caught.** `run_selftests.py --self-test`
  exits 0 in 2.1 s. Its hanging plant (`run_selftests.py:160-170`) runs
  with an explicit timeout of 2 s, not `TIMEOUT_SECONDS`, so raising the
  constant cannot weaken it.
- **Authorship.** The commit's author is Adalberto Pereira
  <adalbertobosco@gmail.com>. `git log origin/main..HEAD`, and the PR's
  title and body (`gh pr view 137`), contain no `Co-Authored-By`, no
  "Generated with" and no tool name.

## Findings

1. **Should.** `tasks/STATUS.md:24-30`. The section says "Five of the
   eight found something the implementer's own gates passed green", and
   then names six: T163, T164, T155, T157, T162 and T121. The other two
   reviews found things as well:
   - 174 has six shoulds, including a burst that crosses two thresholds
     and runs a whole attack between them, and eight surviving mutants.
   - 172 is an approve with three shoulds. One is that a NOTICE-only
     change rebuilt 0.1.0 unrefused.

   Fix: say "six", or "every review found something; six found a
   behaviour", and add T156's.

2. **Should.** The claim that the timeout was the only failure is not
   held by the evidence. It appears at `scripts/run_selftests.py:46-49`
   ("main went red on that alone"), in the commit message and in the PR
   body ("Fixes main's CI"). `lint-selftests` is a prerequisite of
   `check-no-engine` (`Makefile:163-165`), and `check-no-engine` is the
   first prerequisite of `check` (`Makefile:152`). Make stops at the
   first error. So in all four red runs, `make check` stopped about seven
   minutes in. These never ran on main's CI for #132-#135:
   - `test-godot` and `test-vectors`;
   - `test-demos-exit` and the rest of `check`.

   The runs for #130 and #131 were still `in_progress` on the godot job
   at review time. Those runs are from before the extra kit cases.

   With decision 2 (merge with `--admin`, never a full `make check`),
   nobody knows today whether the merged batch passes `make check`. Only
   the first gate's failure is known. Fix:
   - word the comment and STATUS as "the first failure; the gates after
     it did not run";
   - in STATUS, say that the first green `make check` on main after #136
     is still owed;
   - do not call CI fixed until PR #137's run, or the next push to main,
     is green past `lint-selftests`.

3. **Should.** `scripts/run_selftests.py:46-50`. The 300 s is a guess.
   The only CI figure is "more than 120 s", so nothing shows that 300 s
   is enough on the runner, or how much room it leaves. The limit is also
   the same for every script. Raising it for one slow self-test means a
   real hang in any of the roughly 40 others now holds the job for 300 s
   instead of 120 s.

   The self-test is slow by construction: `run_cases`
   (`library_check.py:530-541`) follows the whole page with Godot 17
   times, one after another (the untouched page plus 16 plants). That is
   about 4.4 s each. Each case has its own folder, so they could run in a
   thread pool. Another way is for a slow script to declare its own
   budget, so the shared limit can stay tight.

   As a stopgap, to turn CI green, 300 is acceptable. But the comment
   should say it was not measured on the runner, and a task should hold
   the real fix. That task should also make `run_selftests.py` print each
   script's duration, so the next limit is a measurement.

4. **Should.** `tasks/STATUS.md:56-67`. The list of what waits for the
   owner leaves out things the merged PRs hand to the owner:
   - T162's own manual check (`tasks/T162-*.md`, `## Manual check`):
     install HEAD's kit zip in an empty project, open it in the editor,
     close it, and read the last lines. Only the upstream report is
     listed.
   - T160's decision 5 (PR #132): the store's Godot range is 4.7 to the
     newest offered, and "the owner may prefer a maximum of 4.7". Also
     T160's manual check of correcting the store page, which is "still
     the owner's".

   STATUS is the next session's prompt, so these drop out of view unless
   they are listed.

5. **Nit.** `tasks/STATUS.md:57-59`. T157's manual check also says
   "Record a clip for the video's next cut (T153)"
   (`tasks/T157-*.md`). The list has only the playing part.

6. **Nit.** `tasks/STATUS.md:25-26` and `:52`.
   - "T163's N20 refused T164's own tests" is not quite right. T164 was
     not written yet. Review 171 says N20 refused the tests T164 *must
     write*.
   - The reasons given for `selected: everything` ("a new example
     manifest, a script or the Makefile") miss #131's. Its reason was a
     global addon manifest, `modules/ai_teamwork.json`.

## What was run

```
git fetch origin && git switch -c review/179 origin/wave/179-batch-171-178-recorded
make worktree-setup
git log --oneline origin/main -12; git diff origin/main...HEAD
ls docs/reviews/17*; read the findings of 171-178
gh pr view 129..137 (bodies: decisions, manual checks, affected)
grep Prereqs tasks/T141 T158 T161 T165 T166 T167; STATUS index rows
make lint-status lint-tasks                       # exit 0
gh run list --branch main --limit 12
gh run view <id> --log-failed                     # the four failed runs above
gh run view 42979952908 --json jobs               # PR #137's run, in progress at review time
python3 scripts/library_check.py --self-test      # 74.7 s, exit 0
python3 scripts/run_selftests.py --self-test      # 2.1 s, exit 0
```

`make check` was not run (the batch's rule).
