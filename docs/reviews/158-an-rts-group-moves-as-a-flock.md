# Review: wave/158-an-rts-group-moves-as-a-flock

T151 lets a group's move order in the RTS walk as T150's flock. **G**
switches it on. The core gains a port, `GakRtsCrowd`, whose base class is
the old walk. The game fills the port with `RtsFlock`. T19's wall-gap jam
is put back as the planted case of `make test-rts-flock`.

A fresh context reviewed PR #116 at head d9a143d. **Verdict: approve
after the two shoulds; no blocker. The four nits were done too.** The PR
is stacked on #112 (T150), which was still open, so nothing was merged
from main.

## What was reviewed

- The PR title and body, the task file and its decisions.
- `GakRtsCrowd` and the two places the core calls it: `RtsWorld.step` and
  `RtsOrders._walk`. Also the claim that the base crowd keeps the old
  digest.
- `RtsFlock`: which units count as a group, the neighbours from the
  world's spatial hash, the staggered decisions, the heading taken from
  the cell's arrow, the wall check, and the watched unit's forces.
- The game's wiring: the G key, restart, the overlay, the legend and the
  drawing, and the `--record` path.
- The planted case, `rts_flock_gap.gd`, and `rts_flock_test.gd`.
- The docs, the catalogue and the translations.

## Findings

1. **Should.** The game keeps one `RtsFlock` across restarts, and
   `restart()` only set `world.crowd = flock`. A new world's ids start
   again from 1, so its first ticks read the old world's `_was` and
   `_forces`. Probe: a flock run 100 ticks on one world, then 120 on a
   fresh one, ends on a different digest from a fresh world with a fresh
   flock.
2. **Should.** Pressing G is not recorded. A match played with
   `--record` and the flock on was kept anyway, and its recording, played
   back with the base crowd, cannot reproduce it.
3. **Nit.** `watched_counted` stays stale for up to `DECIDE_EVERY - 1`
   ticks after the selection changes.
4. **Nit.** `_watched_in_a_flock` picked any selected unit on a move
   order, not one that is actually flocking.
5. **Nit.** Two edited comments in `rts_world.gd` ran to 125 and 119
   characters.
6. **Nit.** `rts_flock_gap.gd`'s `SEED` changes nothing. The armies stand
   on a fixed grid, and seeds 7, 42 and 151 give the same result.

## What was done about them

1. `RtsFlock.reset()` forgets every unit it has seen: `_was`, `_forces`,
   `_vehicles` and the watched unit's lists. `restart()` calls it before
   handing the flock to the new world, and a flock switched off resets
   too. A new test runs a flock on one world, then on a second one. It
   checks the second run matches a fresh flock's digest when reset, and
   differs without the reset, so the test sees the case it guards.
2. The game now keeps `flock_used`, set by G and at restart when the
   flock is already on. A match in which the flock walked is not kept,
   and the header's recording line says why, in en and pt-BR. Recording
   the presses was the other option. It was left out: it would need a
   second kind of entry in the core's recording format, for a match that
   only the clock's measurement reads.
3. `watched_counted` is cleared when `watched` changes and filled again
   at that unit's next decision.
4. `RtsFlock.is_flocking(id)` is now the test `_watched_in_a_flock` uses.
5. Both comments rewrapped.
6. The gate's header says it is one fixed scene, and gives the margin:
   19 jammed against none. `SEED`'s comment says it moves nothing. A
   jittered start was not added.
