# Review: wave/184-slow-selftest

PR #140, task T168. `run_selftests.py` prints each self-test's duration
and warns when one used over half the limit. `library_check.py
--self-test` follows its 17 cases at once, one a core, and the limit goes
back from wave 179's 300 s stopgap to 120 s.

A fresh context reviewed head d1e24f5. **Verdict: no blocker.** There are
two should-fix findings: the plants did not pin the half line, and the
estimate for GitHub's runner used the wrong core layout. There are also
four nits and one optional item.

## What was reviewed

- The whole diff against the task, its decisions, the wave's changes to
  them, CLAUDE.md invariants 1, 4 and 11, and the traps about bytecode
  caches and `-s` scripts.
- **The runner's plants, by mutation.** The half-limit threshold in
  `duration()` was moved to `timeout / 4` and the self-test stayed green.
  The slow plant sat at 67% of its limit and the fast one near 0%, so
  nothing lay between a quarter and a half.
- **The parallel cases.** Each case has its own folder. What they share
  was checked: the clone (read only through git), the engine, and the
  `user://` of the reader's project name, which holds Godot's log.
  `library_check.py --self-test` passed on repeated runs.
- **The runner estimate, measured.** `taskset -c 0-3` is 4 physical
  cores. GitHub's 4 vCPU are 2 physical cores with SMT. With
  `taskset -c 0,1,6,7` (4 threads on 2 physical cores) it took 29 s.
- **Authorship.** The commit and the PR body are by Adalberto Pereira,
  with no `Co-Authored-By`, no "Generated with" and no tooling byline.

## Findings

### 1. Should-fix (confirmed): the plants did not pin the half line

With `timeout / 4` in place of `timeout / 2`, the self-test stayed green.
**Fix:** add a plant at about a third of its limit. It must print
`ok (1.x s)` with no warning. Then the `/4` and `/1` mutations must both
go red.

### 2. Should-fix (plausible): the runner estimate assumed 4 physical cores

The comment in `run_selftests.py` and the STATUS row said "23 s on 4
(GitHub's runner has 4)". That figure was 4 physical cores. The runner has
4 threads on 2 physical cores, and each thread is slower: the serial run
took 75 s here and over 120 s there. 29 s scaled by 1.6 to 2 gives 45 to
60 s. That is near the 60 s warning line and about half the 120 s kill.
**Fix:** cite the SMT layout and the estimate. Keep the manual check open
until a CI run shows the real durations.

### Nits

- `run_cases`' docstring should say that the shared `user://` log is
  written by parallel processes at once, so it is no place to debug from.
- `cores()` reads the affinity, while `godot_shards.py` uses
  `os.cpu_count()`, which ignores it. Say so in a comment, without
  refactoring `godot_shards.py`.
- The slow plant had 1 s of head-room under its limit for interpreter
  start-up. Use a 4 s limit.
- The STATUS row should name the next self-test to approach half the
  limit on the runner: `check_published.py --self-test`, 14 s and serial.
- Optional: give each self-test its own process group in `run_one`, and
  kill the group at timeout, so a timed-out parallel self-test leaves no
  grandchildren running. If that is not small, name it in STATUS.

## What was done about them

All of them were applied on the branch in one push, after a rebase on
main 8a12e7c. The rebase conflicted on `tasks/STATUS.md`, and both rows
were kept: T167 done, T168 done.

- **Finding 1.** The slow plant is now 2.5 s under a 4 s limit and must
  be named slow. A new plant runs 1.4 s under a 4 s limit and must print
  `ok (1.x s)` with no warning. Mutations: `/4` goes red on the new plant
  ("a self-test at a third of the limit is named slow"), and `/1` goes red
  on the slow one.
- **Finding 2.** Measured again here: `taskset -c 0,1,6,7` gives 29.5 s
  (cpu0 and cpu6 are siblings, as are cpu1 and cpu7). The comment in
  `run_selftests.py` and the STATUS row now cite the 6-core 12-thread
  machine, the 2-physical-core layout, and the 45-60 s estimate. The
  manual check stays open.
- **Nits.** The `run_cases` docstring says the log is written and rotated
  by every case at once, so read the finding or follow one case alone.
  `cores()` has a comment on why it does not use `os.cpu_count()`. The
  STATUS row names `check_published.py` as the next to approach half.
- **Optional item: not done, and named in the STATUS row.** A process
  group means `Popen` with `start_new_session`, a Windows fallback with no
  `killpg`, and a plant that has to wait out a zombie grandchild. That is
  not small enough to slip into this wave.

Re-run after the changes:

| check | exit |
|---|---|
| `run_selftests.py --self-test` | 0 |
| the `/4` and `/1` mutations | 1 each |
| `library_check.py --self-test` | 0 |
| `run_selftests.py` | 0 |
| `make lint-readability lint-tasks lint-status lint-self-naming` | 0 |

`__pycache__` was removed after the mutations.
