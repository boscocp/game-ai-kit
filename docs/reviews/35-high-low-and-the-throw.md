# Review: wave/35-high-low-and-the-throw

One fresh context reviewed it, in its own git worktree, at b9157e5.

What it read: CLAUDE.md, T16, T34, the wave 34 review, and the diff.

What it ran:
- `make check`, and each T34 acceptance command;
- a mirror test: 400 seeded random fights of 3,000 frames across all four
  pairings, using every new input, each compared frame by frame with the
  same fight swapped and mirrored;
- a trace of the log against its description, and a fit probe for the panel
  text with the fallback font at size 15;
- 30 mutations.

A worktree has neither `godot/addons/gdUnit4/` nor
`scripts/forbidden-term-hashes.txt`; both were copied in read-only.

## What was reviewed

Commit b9157e5:
- `godot/game/fighting/` and `spec/frames/`;
- `fighting_test.gd`, `replay_determinism.gd`, `fight_log.json` and its
  digests;
- the `demo-fighting` target, T34 to T38, and the STATUS and T17 edits.

## Checked and true

- `make check` and every acceptance command exited 0; 40 fighting tests,
  629 replayed frames with no problem, seven examples' overlays.
- `FightRules` follows the ten steps of `resolution`: every new rule in the
  data is in the code, and nothing the code does is missing from the data.
- The guard read from the defender's held input always equals
  `defender.crouching` whenever the defender can block -- in blockstun, free,
  and at a wall.
- A crouching move keeps its stance once down is let go; a press with down
  and no crouching move gives the standing one, and the fighter stands.
- Throws behave as written: a throw on a fighter starting a move is a plain
  throw; a strike on a throw's frame lands and cannot be blocked; a clash
  ends both moves, leaves no stun, and is mirror-exact at either wall.
- **The mirror holds**: 0 mismatches over the 400 fights, which between them
  threw 68 times, beat 21 throws with a strike, clashed once, put 6 lows and
  5 overheads through the wrong guard, traded 268 times and cancelled 57.
- The log does what its description says on every frame it names, and the
  test comments' frame arithmetic is right.

## Findings

### Must fix

None.

### Should fix

1. **The strike-beats-throw event ran off the panel**: 697 px in a 580 px
   label that did not wrap.
2. **Throws into stun were tested at one stun, in blockstun only.** `stun > 1`
   and "skip only blockstun" both survived -- the second would allow a hit
   to be followed by a throw nobody could answer.
3. **The clash's "both moves end, both pushed apart" had no test**: no
   pushback, moves left running, and one fighter pushed all survived.
4. **A cancel into a crouching move had no test**, and the data depends on it
   (the jab into the low kick, the low kicks into the sweep).
5. **Frame-data validation had gaps**: a misspelled height ("Low") was
   accepted and would crash a lookup later; "a throw is done standing" could
   be dropped; nothing stopped a button having only a crouching move, which
   standing would do nothing.
6. **The dummy's new modes were untested**: "guard crouching" without down,
   and "throw" pressing a jab, both survived.
7. **T34's row did not say its manual check is still a person's.**

### Notes

- A throw catches a fighter on the frame its stun reaches 0, as a strike
  would; and inside a blockstring it is frame advantage that keeps a throw
  answerable, not the stun rule, which the comment claimed.
- `crouching` stayed set for one frame on a fighter hit out of a crouching
  move.
- A press made standing comes out crouched if down is held by the time it
  leaves the buffer: what the resolution says, not what T34's step said.
- `"hits"` in the replay's list was satisfied by "counter-hits".
- The "mid" entry in `_a_height` was dead; one validation line ran to 135
  characters.
- T38's row and its goal disagreed on when the jump was asked for.

### The mutations

19 of 30 killed, one of the 11 survivors equivalent (the guard read from
`defender.crouching` instead of the input). Survivors: N6 and N7 (throw into
stun), N10, N11 and N12 (clash), N19 (cancel ignores down), N22 and N25
(validation), N26 and N27 (dummy).

## What was done about them

- **The panel** wraps, and the events are shorter: "(a low through a
  standing guard)", "(strike beats throw)".
- **Tests**, each run against its mutation and seen to kill it:
  - throws into stun, both kinds, at the boundary -- 2 left at the start of
    the frame is protected, 1 is not (N6, N7);
  - the clash on its own frame: both moves over, both pushes taken, at a
    wall and in the open (N10, N11, N12);
  - a cancel with down held taking the low kick, and without it nothing
    (N19);
  - planted frame data for a misspelled height, a crouching throw, and a
    button with no standing move (N22, N25, and the new rule);
  - the dummy's crouching guard and throw (N26, N27).
- **Validation**: `FightData` refuses a button with no standing move.
- **The notes**: `crouching` is cleared by a hit; the comment on throws and
  stun says what the rule buys and what frame advantage buys; T34's step 2
  says "when the move comes out"; the replay looks for " hits p"; the dead
  entry is gone and the long line split; T38's two sentences agree.
- **Left, on purpose:** the new `EXERCISED` entries have no planted log
  lacking them, as the old ones have none -- the list is read by a person,
  invariant 4's open half.
