# Review: wave/55-three-difficulties-honestly

One fresh context reviewed it, in the main worktree, at the wave's first
commit (9c40d7a), and again at the fix commit (01cab46). It wrote nothing in
the repository; one probe it made for finding 5 it deleted, and the tree was
clean both times.

**Verdict: merge after fixes.** No blocker. The ladder held when the
reviewer ran it, with the author's numbers. The problems were of three
kinds: a never-cheat check that never asked the question where cheating is
easiest, claims with no record behind them, and two behaviours of the
controller that undid part of what the levels were measured for.

## What was reviewed

- `CLAUDE.md`, T12, and the whole diff `main...HEAD`.
- Run: `make test-godot` (935 cases, then 938), `difficulty_knobs.gd`,
  `difficulty_matches.gd` in full (15 min 41 s, exit 0, the author's
  numbers), `check_readability.py`, `check_addon_deps.py`, the task's
  tripwire one-liner.
- Read against the rules: `FightOdds`' recursion and memo against
  `TacticalCombat.fight` and `siege`; the key packing; the horizon in
  `HeuristicPlanner`; `PlannedBlue` at horizon 0; the scene's turn flow with
  the person on blue.

## Findings

1. *major* -- the vision check only asked where to walk, never whom to
   attack, which is when the board's dice are the very fight's. A level that
   played the fight on a copy before attacking passed every gate.
2. *major* -- the allowlist read its list from `Difficulty.KNOBS`, the file it
   audits, and passed on an empty ladder; nothing stopped a level branching
   on its name.
3. *major* -- numbers in comments and STATUS (the plan's 31-9, the noise
   curve) had no record or command behind them; STATUS said "reviewed and
   merged" before either.
4. *major* -- with S, the computer playing red explained itself as blue: the
   rules' and the learned policy's sentences named the sides.
5. *minor* -- after a walk, `decide_attack` overruled a search that had
   chosen not to attack (measured: 103 times in 6 games at easy).
6. *minor* -- asking the rules for a walk took a goal the walker then did not
   go to, crowding later walkers into the fallback.
7. *minor* -- a new game the computer opened showed the last game's news.
8. *minor* -- the odds tests never checked a siege's `attacker_left`, nor a
   fight with no hit-back over several rounds.
9. *minor* -- the floor had no planted case.
10. *minor* -- the board's fingerprint left out the pieces' types and the
    combat rules.
11. *minor* -- three levels rather than five was argued, not measured.
12. *nit* -- the run time (ten minutes; it is fifteen) and the game count.
13. *nits* -- unreadable wording in the presets' comment, "once a game" for
    a process-wide cache, depth 3 silently acting as 2, two simplifications
    in ply 2 not written down.

At the second look, all thirteen were fixed, and four new ones found:
A, the level-name check is a tripwire, not an allowlist; B, STATUS linked
this record before it existed; C, nothing in `make check` held fixes 5 and
6; D, hard over normal is the thinnest step, 19 against a margin of 15.

## What was done about them

Fixed on this branch, and the fix was reviewed again before the merge.

- 1: check 3 asks the build, every walk and the attack after it, over five
  dice and four boards; a planted level that plays the fight first is caught.
- 2: the gate holds `KNOBS` and the three level names to lists of its own,
  plants an empty ladder, and counts `level.name` in `LeveledBlue` (A: it
  says it is a tripwire).
- 3: T12's record has every pairing, and `difficulty_matches.gd --measure`
  plays any two points on the knobs, or one against the rules.
- 4: the sentences say "the enemy"; scene tests play the person on blue.
- 5, 6: a "chose not to" marker, and the claims put back when a walker
  leaves the rules' cell -- each held by a test that fails when the fix is
  reverted (C).
- 7-13: as asked.

**The fixes moved the numbers.** 5 had been propping up the noisy levels:
without it they fell under the floor, so the presets moved, to easy (1 ply,
noise 0.5), normal (1 ply), hard (2 plies). And the ladder's two seats had
replayed one game's dice, which tied the pair together -- a mirror came
apart by 23 in a hundred; every game now has dice of its own. Measured
after: normal beat easy 70-29, hard beat normal 59-40, every level the rules
25 of 25 from each seat, the mirror 10 apart.

Not fixed, on purpose: D. The gate is deterministic, so it does not flake,
and the record says this step is the thinnest. If it ever fails, the next
move is more games for that pairing, not a lower bar.
