# T43 — A fighting ladder

Size: M · Prereqs: T37, T18, T40 · Files: `godot/game/fighting/`, `godot/test/`

## Goal

Picked by the owner from T42's fun review. The fighting example is a
training room: a dummy, three levels and two ghosts, and nothing that says
"next opponent" or "you finished". Every opponent already exists, so this is
a menu and a score, not new AI.

A ladder, in order: easy, medium, hard, the owner's ghost, the clone. Best
of three rounds each; lose a match and that rung is played again; win the
last and the game says so. Training mode stays as it is, one key away.

## Steps

1. A `FightLadder` that holds the rungs and the score, apart from the scene,
   so a test can climb it without a window.
2. Rounds: the fight already ends in a winner; the ladder counts them, best
   of three, and moves on or retries.
3. The decision overlay stays (invariant 13): the panel still shows what the
   opponent saw and drew, on every rung.
4. The ghosts and the clone read files that may be missing (the owner's
   recordings are not committed everywhere). A missing one is skipped with a
   line on screen saying why, never a crash.

## Acceptance

```bash
make test-godot
make test-demo-overlays
```

with a suite climbing the ladder headless -- every rung reached, a lost
match retried, a missing ghost skipped -- named here when written.

## Manual check

The owner climbs the ladder once and says whether wanting the next rung is
there.
