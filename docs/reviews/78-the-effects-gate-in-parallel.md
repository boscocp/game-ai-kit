# Review: wave/78-the-effects-gate-in-parallel

A fresh context reviewed T72 at `5ddc1e2`: `scripts/godot_shards.py`,
which runs `botmatch_effects.gd` as N Godot processes each playing every
N-th match and writing its raw sums, then one merge that evaluates every
claim and planted case over all of them; `effect_shards.gd`, its gdUnit
suite and Python tests, and the few lines it changed in the gate. It was
not allowed to edit the worktree. It ran the runner's self-test, its
Python tests, the gdUnit suite (6 of 6), `check_readability` and
`check_modules`, and measured Godot 4.7.2's error formats and a script
error inside `_initialize`; it did not run the sharded gate.

**Verdict: merge**, two medium fixes first.

## What was reviewed

- `CLAUDE.md`'s traps (make's exit 2, SCRIPT ERROR in `-s` scripts, a
  runner that finds nothing), T72's task, and `git diff origin/main...HEAD`.
- Whether the sharded gate could go green where the serial one is red, or
  print other numbers: a shard missing, duplicated, empty, hung or killed;
  shared or stale files; the order of float sums; the split for any N.
- What is forgiven of a shard's errors, and how narrowly.
- The rebase against wave 76, which edits the same gate, by `git merge-tree`.

## Findings

1. **A hung shard hung the gate** (medium): `process.wait()` had no
   timeout, and a SCRIPT ERROR inside `_initialize` -- `quit(null)` after a
   failed write -- never quits.
2. **Bit for bit was shown once, by hand** (medium): `EffectShards.add`
   sums every key, so a future stat that is a maximum or a last value would
   merge to another number silently.
3. **The rebase** (low): the gate merges cleanly with wave 76; only docs
   and status conflict. The doc said 189 matches; the branch plays 147,
   187 with T68's.
4. **Shard logs printed reports of zeros** (low).
5. **`build/shards/effects-*` folders piled up** (low).
6. **A missing `scripts/godot` raised a traceback and exit 1**, read as a
   failed claim; **a match played by two shards passed silently** (low).

## What was done about them

All six on the branch (`9c8dc5b`), then rebased on main with T68
(`6da6133`, `513ffed`):

1. A shard or the merge still running at `--timeout` (3600 s) is killed,
   named, and exit 2; the self-test kills a real sleeper at 0.2 s.
2. `add` refuses any stat that is not an int, a float or a margins array,
   and `_add` and `add` say every stat must be a sum or a margin. A gdUnit
   case plays two real matches serially and in two shards through the
   gate's own `_play` and `_add` and compares `var_to_str`; a planted
   last-value `deaths` turned it red.
3. On the merged gate (187 matches), serial and sharded printed the same
   exact sums for all 15 pairings and the same 94-line report: serial
   2748 s, sharded 455 s, six times faster on 12 cores. The first run
   after the rebase played nothing -- T68's `MatchHealth` needed an import,
   the `class_name` trap -- and the runner exited 2; the comparison then
   said "identical" over zero lines, caught by counting them.
4. A shard prints only "shard K/N: played M matches".
5. A passing run's folder is removed; a failing one is kept and named.
6. An `OSError` starting Godot is exit 2, its output file closed; a match
   played twice is refused, with its own case.

`make check-affected BASE=origin/main` (everything, the Makefile being
changed), exit 0; the six SCRIPT ERRORs are planted `gdscript://` scripts,
as on main.
