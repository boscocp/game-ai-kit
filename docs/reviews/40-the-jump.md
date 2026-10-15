# Review: wave/40-the-jump

Two passes by one fresh context, each in its own git worktree: the first at
d58da6d, the second at 1cf8fe3 -- which answered the first and added the
two things the owner asked for after playing it, an air move on every
attack button and cross-ups.

What it read: CLAUDE.md, T38, the spec README, the wave 37 and 39 records,
and both diffs.

What it ran: `make check` both times (729, then 737 cases); the jump suite;
the replay; `make fighter-strips` against the committed strips (36, then
42, every byte the same); the LICENCES rows against the strips and
`sprites.json` (0 mismatches); the old rule against the new geometry over
every ground move, stance and pairing; 3,000 random fights each against its
mirror with the players swapped; 26 mutations, then 18.

## What was reviewed

d58da6d and 1cf8fe3: the frame data and its copy, `fight_data.gd`,
`fighter_state.gd`, `fight_input.gd`, `fight_boxes.gd`, `fight_rules.gd`,
`fight_jump.gd`, `fight_view.gd`, `fighter_sprites.gd`, `fighting.gd`,
`fighting_panel.gd`, `fight_opponent.gd`, `sprites.json`, twelve strips and
their LICENCES rows, the jump suite, the fighting and sprite suites, the log
and its digests, the spec README and T38.

## Checked and true

- Every high starts above the highest crouch (92) and at or below the
  shortest standing height (118); every other ground strike reaches the
  lowest crouch (71). So the geometry gives the old pass-over rule in every
  pairing and phase, not only in the log: the 655 old digests, with the new
  fields stripped, are unchanged.
- The rules are symmetric: 0 of 3,000 fuzzed fights diverged from their
  mirror.
- Take-off is on the ground, throwable and unguarded; landing is
  throwable; the arc is off the floor on every flight frame; one air move a
  jump and none once hit; a cornered fighter cannot be crossed.
- The T37 opponent never presses up nor picks an air move; the uppercut is
  never its quickest mid; the levels are unchanged.

## Findings

### First pass (d58da6d)

Must fix: none.

Should fix:

1. A mid missing a jumper was announced as "a low misses a fighter in the
   air".
2. Landing frames could not be thrown -- landing was a stun, and every stun
   was throw-proof.
3. No take-off frames: up pressed on the frame a throw arrived escaped it.
4. A fighter hit in the air recovered and kicked again in the same jump;
   and a jump had two flying kicks.
5. Tests that passed on broken geometry: the air box ignoring the jumper's
   height, crouching in the air, a high above every standing head.
6. The view's new geometry was untested.

Notes: the jump's frame number was one off its height; `fight_rules.gd`
was 407 lines; the legend still said "orange bar" and "paler: hitstun or
blockstun"; landing allowed a crouch.

### Second pass (1cf8fe3)

Must fix: none.

Should fix:

1. The commit said `fight_rules.gd` was back under 400 lines; it was 409.
2. A fighter landing in hitstun lost a frame: the landing frame did not
   count the stun down.
3. On one spot, every standing guard blocked whichever way it was held:
   the guard was judged off the two positions after the defender's step.
4. Untested: guarding and crouching while taking off, crouching while
   landing, the tie-break on one spot, the take-off picture; the log has
   no cross-over.

Notes: a hit during take-off left `jump_direction` set, and `air_spent`
stayed set on the ground; three prose lines over the width; the validator
allowed a jump of height 0; the T37 opponent sees landing as neutral.

### The mutations

First pass: 26, 18 killed by the suites and 1 by the replay only. Survived:
crouching in the air, the air box ignoring height, the sprite and the box
on screen ignoring height, landing throw-proof, and two equivalent ones.
Second pass: 17, 14 killed (3 by the replay only). Survived: the tie-break
reversed, guarding while taking off, crouching while taking off or landing,
the take-off picture.

## What was done about them

First pass, in 1cf8fe3: take-off frames (4 and 3) on the ground, throwable
and unguarded; landing throwable, only hitstun and blockstun protect; one
air move a jump and none once hit; the arc fixed so a jump of N frames is N
frames up; a miss named by the move's own height; `fight_jump.gd` split
out; tests for each, and for the air box, the box on screen and a high over
a standing head; the legend corrected.

Second pass, in the commit after 1cf8fe3:

1. `misses_vertically` moved to `FightBoxes`; `fight_rules.gd` is 400
   lines, at the limit, and the commit says so.
2. A fighter landing in stun counts it down on the landing frame, tested.
3. **A guard is held back from the way the strike travels**
   (`FightInput.holds_back_from`), not away from where the attacker stands:
   the same before and after the defender's own step, and on one spot.
   Face to face it is holding away; the recorded fight's events are
   unchanged.
4. Tests for each survivor; each was planted again and is now caught. The
   log still has no cross-over: the jump suite holds it, and the log's
   last fighter is cornered.

Notes: a hit during take-off clears the jump's direction; landing clears
`air_spent`; a jump must leave the floor; the lines are rewrapped. The
opponent not punishing a landing is T37's, and is left as it is.
