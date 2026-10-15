# Review: wave/39-a-fixed-opponent-three-honest-levels

One fresh context reviewed it, in its own git worktree, at aae4409.

What it read: CLAUDE.md, T37, `docs/concepts/fighting-game-ai.md` (the
hand-written opponents, cheating, and what the kit takes), the diff, and the
fighting files around it.

What it ran: `make check`; the new suite; the levels script; the levels
again with every seed moved by 1000, 7777 and 31337; the levels with one
knob made equal at a time; a probe of lows pressed at random against each
level; a caller that swaps two states in place; three restarts; 21
mutations.

## What was reviewed

Commit aae4409: `fight_delay.gd`, `fight_opponent.gd`, `fighting.gd`,
`fighting_panel.gd`, `demo_overlays.gd`, `fight_opponent_test.gd`,
`opponent_levels.gd`, the Makefile and T37.

## Checked and true

- `make check` exited 0 (709 cases). The levels reproduce the task's
  numbers: 95, 93, 99, 99, and 42 for the planted pairing.
- The margin is not the seed's: under three other seed offsets the four
  numbers stayed between 91 and 100, the planted one between 47 and 56.
- With every level's reaction made equal (22, then 30), hard still beats
  medium 87 to 95: the levels differ in how they decide. With only reaction
  differing, 61 to 78: seeing sooner is worth something too.
- The opponent is handed exactly `reaction` frames old, a copy; the reaction
  is read once; under 15 is refused and handed nothing; a gap restarts it.
- In the lows probe no guard was decided on or after the frame of the press.
- Situations, reach, the quickest move by height (with the dancer's missing
  overhead), crouching strikes held down, and determinism by seed are right.

## Findings

### Must fix

1. **The header claimed hard "sees the same fight, as late as a person
   would".** Its reaction is 15 to medium's 22: it sees it sooner. Teaching
   text, so invariant 1's.
2. **The manual check could not pass.** Every low here lands 6 to 15 frames
   after its press, so any guard of a low is of one pressed under a quarter
   of a second ago; hard guarded 69 and 61 of them, all guesses held from
   an earlier decision.
3. **The seat kept references and copied only at hand-over**, so a caller
   that swapped two states in place showed the opponent frame 38 at frame 39.

### Should fix

4. **The training mode's seat was untested.** The overlay check takes three
   steps, under any reaction, so `seen_frame` was always -1; a scene that
   never asked the opponent, or a restart that did not reseat it, passed.
5. **Every restart opened the same way**, seed 0 -- against the header's own
   argument for chance.
6. **The late fumble and the reach rule had no test.**
7. **Execution was barely held**: "easy fumbles at least once in 200".

### Notes

8. `FightDelay.seen_frame()` was dead code.
9. The panel read the opponent's reaction, not the one the seat enforces.
10. A refused seat was invisible in the training mode.
11. The planted pairing ran for the lancer only, and reached 56 under one
    seed offset.
12. "Refused" holds for an opponent that declares under 15; one built with a
    reference to the live fight is not detectable. The guarantee is the
    seat's, and the text should say so.
13. "Hard: all (up to 9)": two situations have only four options.

### The mutations

17 of 21 killed. Survived: reach always true (M10), a late fumble that adds
no delay (M14), a scene that never asks the seat (M16), a restart that does
not reseat (M17). Killed only by the levels script: easy given medium's
knobs (M20).

## What was done about them

All thirteen, in the commit after aae4409:

1. The header says hard decides better and sees sooner, never sooner than a
   person, with the review's measurement of how much is the deciding.
2. The manual check asks for what can be held: a guarded low's "saw frame"
   is earlier than its press. The task says why.
3. The seat keeps its own copy of every frame; a test steps one state in
   place and checks it is still handed the past.
4. A test steps the training mode 40 frames and checks the opponent saw a
   frame at least its reaction old, and that a restart seats a new one.
5. Each restart seeds the opponent with how many fights have begun.
6. Tests for both: a late fumble holds nothing for 10 frames first; a mid
   out of reach becomes a step in, and in reach is the quickest mid.
7. Each level's fumble rate over 1,000 decisions is held to its execution,
   within 4 points.
8. Deleted. 9. The panel and overlay read the seat's reaction. 10. The panel
   says "refused" and why. 11. The planted pairing runs for both characters:
   42 and 37. 12. `FightDelay`'s header says the guarantee is the seat's.
   13. "all (4 to 9, by situation)".

M10, M14, M16, M17 and the in-place copy were planted again after the fixes
and each is now caught by `fight_opponent_test.gd`.
