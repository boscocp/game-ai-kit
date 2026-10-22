# Review: wave/82-guards-hear-footsteps

A fresh context reviewed T81 at `6ba142c`: the fix for the owner's report
that a guard did not hear them walking right behind it. A sound is now
delivered with how long it holds -- a footstep for its own cadence,
`noise_every`, a one-off for nothing -- and a guard hears it every step
until it ends or a louder one arrives; a glance now turns to the heard
place; a claim in `make test-infiltration` holds the time to notice. The
last commit adds the "Resuming after" section for waves 75 to 82. The
reviewer was not allowed to edit the worktree. It ran
`make test-infiltration`, `make test-infiltration-properties`, the gdUnit
suites of `infiltration` and `ai_perception` (87 cases), and the
readability, module and demo gates: all green, no SCRIPT ERROR.

**Verdict: fix before merge.**

## What was reviewed

- `CLAUDE.md` (invariants 3, 4, 6, 13), T81's task, the hearing section
  of `docs/godot/infiltration.md`.
- Whether a held sound outlives its source (a stop, prone, a takedown, a
  restart), how it meets a louder or a quieter sound, whether it is counted
  twice with T69's event lifetime, and whether it runs in game seconds.
- That the guard is given only the sound's place.
- The claim's planted case, and whether it can pass on nothing.
- The Resuming section against `git log` and the open pull requests.

## Findings

1. **A held footstep dropped quieter one-off sounds for its whole hold**
   (medium): a throw landing near a guard beside a walking player was
   lost, so the distraction failed; a takedown the same.
2. **The glance fix had no test** (medium): nothing called `_glance`.
3. **The crouched half could not fail** (low-medium): the creep reaches
   2 m, so "crouched 3 m" was always never; prone holds by data alone.
4. **The swing comment was wrong** (low): 0.45 m a step, and the floor
   was checked short of the swing.
5. **The 4.6 s diagonal case**, the owner's own, was only in the task (low).
6. **21.0 s against 20.8 s** for the search without a belief (low).
7. **One name for two things** in `level_sounds.gd` (nit).

Sound, by the reviewer's reading: a hold outlives its source by at most
one cadence; it is not counted twice; it is in game seconds; a louder
one-off replaces it; no cheating; the claim cannot pass on nothing; the
Resuming section matched the repository.

## What was done about them

All seven in `bccc0cb`, rebased on main with wave 81:

1. A sound made in a later step replaces the held one; within a step the
   louder wins. A unit test -- a 0.3 throw 0.1 s after a held 0.8
   footstep -- fails on the old rule.
2. A test: a one-off heard out of sight, the action "glance", `_act`
   heads for the heard place; it fails with the old line.
3. "Crouched at 1 m", inside the creep's radius, must be noticed and no
   sooner than standing (0.9-1.5 s against 0.5-0.9 s); 3 m and prone stay
   "never", said to hold by the event data.
4. Corrected, and the floor checked to the end of the swing (10 guards).
5. Stated in `infiltration.md`; the manual check now asks for a guard
   facing along a corridor and names the diagonal case.
6. 20.8 s, from wave 80's fixes on; corrected in the doc and the row.
7. Renamed to `made`.

Re-run: `make test-infiltration` (0 failures, every plant caught, no
hearing gap after a one-off), `make test-infiltration-properties`, 90
gdUnit cases, readability, modules, demos, freshness, tasks and status --
all green, no SCRIPT ERROR. `make check-affected` passed before the
review; the fixes stay inside infiltration, its tests, docs and tasks.
