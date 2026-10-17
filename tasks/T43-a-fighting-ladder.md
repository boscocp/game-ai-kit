# T43 — A fighting ladder

Size: M · Prereqs: T37, T18 · Files: `godot/game/fighting/`, `godot/test/`, `Makefile`

## Goal

Picked by the owner from T42's fun review. The fighting example is a
training room: a dummy, three levels, two ghosts and a clone, and nothing
that says "next opponent" or "you finished". Every opponent already exists,
so this is a menu and a score, not new AI.

A ladder, weakest first by what has been measured: easy, medium, the clone,
"ghost: nearest", hard. Against medium the clone wins 49 of 100, "ghost:
exact" 60 and "ghost: nearest" 66 (`data/cloning/win_rates.json`); hard
beats the frozen ghost 150 or more times in 200 (T40). So the ladder ends on
hard, not on a recording -- otherwise it gets easier at the top. "ghost:
exact" is left out: one ghost is enough, and nearest is the stronger.

Best of three rounds each; lose a match and that rung is played again; win
the last and the game says so. Training mode stays as it is, one key away.

## Steps

1. A `FightLadder` that holds the rungs and the score, apart from the scene,
   so a test can climb it without a window.
2. Rounds: the fight already ends in a winner. Two rules the game does not
   have yet, because a ladder needs every round to end:
   - **a clock**: 99 seconds, the limit `opponent_levels.gd` already plays
     to; at time, more health left wins, and equal health is a draw;
   - **a draw** -- a double KO (`fight_rules.gd`'s `DRAW`) or equal health
     at time -- is replayed, and counts for nobody.
3. The decision overlay stays (invariant 13): the panel still shows what the
   opponent saw and drew, on every rung.
4. The clone and the ghost read `clone_weights.json` and the owner's
   recordings, both tracked. If either cannot be read, that rung is
   skipped with a line on screen saying so. Today a clone that cannot load
   only guards, and without the clock a round against it would never end.
5. `make demo-fighting`'s help line names the ladder key.

## Acceptance

```bash
test -f godot/test/fight_ladder_test.gd
make test-godot
make test-demo-overlays
```

`fight_ladder_test.gd` climbs the ladder headless and must hold: every rung
is reached in order; a lost match is played again; a draw is replayed and
counts for nobody; the clock ends a round against an opponent that only
guards; an unreadable clone file skips its rung.

## Manual check

The owner climbs the ladder once and says whether wanting the next rung is
there.
