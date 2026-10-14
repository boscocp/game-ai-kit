# Review: wave/34-the-fighting-scenario

One fresh context reviewed it, in its own git worktree, detached at bae2dbc.

What it read: CLAUDE.md, T16, `spec/frames/` and the diff.

What it ran:
- `make check`, and each T16 acceptance command;
- a mirror test: 200 seeded random fights of 3,000 frames, across all four
  pairings, plus the recorded log, with the players swapped and the
  positions and inputs mirrored;
- an odd-overlap probe, and a trace of the log's events;
- 35 mutations.

A worktree has neither `godot/addons/gdUnit4/` nor
`scripts/forbidden-term-hashes.txt`; both were copied in read-only.

## What was reviewed

Commit bae2dbc:
- `godot/game/fighting/`;
- `spec/frames/`;
- `fighting_test.gd`, `replay_determinism.gd` and `fight_log.json`;
- the overlay entry, the `demo-fighting` and `test-replay` targets, and the
  T16 and STATUS edits.

## Checked and true

- `make check` and every acceptance command exited 0, and the spec file and
  the game's copy are identical.
- **The rules follow the written order, step by step.**
  - The buffer lasts exactly `buffer_frames` frames.
  - Hitstun of N takes N frames.
  - A trade can involve neither a block nor a counter-hit.
- **The mirror holds in play**, on every frame of all 200 fights and the
  log, including 9 knockouts. The one exception is the odd overlap below.
- **No rule reads a clock, `Input` or a random source.** Only the scene
  reads keys, into its log, and the scene's log replays to what it showed.
- **The log produces the resolutions claimed**, at the frames claimed, bar
  one: the cancel was at 313, not 311.
- **The panel fits**, by arithmetic only, since headless renders nothing.

## Findings

Of 35 mutations, 17 were killed and 18 survived.

### Must fix

- **The determinism gate was blind to player two and to anything that
  differs between processes.**
  - It compared two runs in one process. A digest leaving player two out
    (M30) stayed green.
  - The planted change touched only player one.
  - Anything fixed for the life of a process -- a seed, the process id
    (M33) -- passed by construction. That is exactly what T17 and T18 will
    meet when they replay human logs from Python.
- **Half the resolution order had no test that would notice it breaking**:
  - the buffer one frame longer or shorter (M1, M2);
  - the cancel window closing early, and `cancels_into` ignored (M4, M5);
  - pushback reversed (M15);
  - a double knockout not a draw (M17);
  - blocking in blockstun removed, or in hitstun allowed (M10, M11);
  - the counter-hit's extra hitstun dropped (M14);
  - turning while in a move (M8);
  - the separation passes and the wall branch (M6, M7, M31, M34);
  - box overlap made strict (M20).

### Should fix

- **Separation favoured a side.** The right-hand fighter took the odd unit,
  so a push to the right moved the pair 3 a frame, and the mirrored push to
  the left 2. The data says "equally".
- **The frame data was checked less than the README said.**
  - Not checked: the hitboxes, cancel windows, stage, buffer, pushback and
    counter-hit numbers; `cancels_into` naming real moves; the button
    being present; negative values. Negative damage heals.
  - The startup/active bound had no planted case (M21).
  - The scene never read `refusal`.
- **The overlay check was satisfied by a clock**: `frame` changes every
  step, so frozen fighters would pass.
- **The log's description was off by a frame** for the cancel, the cancel
  was not among the exercised events, and the log reaches no knockout.

### Notes

- Pushback against a wall did nothing, which most fighting games avoid by
  pushing the attacker.
- There is no round timer.
- Counter-hit damage truncates, which only differs from Python for
  negative numbers.
- The overlay said what resolved, not why.
- A variable named `log` shadows the built-in `log()`.
- Invariants 3 and 4 hold, bar the gaps above.

### The mutations

| # | Mutation | Result |
|---|---|---|
| M1 | buffer one frame longer | survived |
| M2 | buffer one frame shorter | survived |
| M3 | cancel without connecting | killed |
| M4 | cancel window closes a frame early | survived |
| M5 | `cancels_into` ignored | survived |
| M6 | first, even separation pass removed | survived |
| M7 | no keep-on-stage after pushback | survived |
| M8 | turning while in a move | survived |
| M9 | player one wins every trade | killed |
| M10 | no block during blockstun | survived |
| M11 | block during hitstun too | survived |
| M12 | counter-hit on recovery | killed |
| M13 | no counter-hit damage bonus | killed |
| M14 | no counter-hit extra hitstun | survived |
| M15 | pushback pulls the defender in | survived |
| M16 | a move connects every frame | killed |
| M17 | double knockout not a draw | survived |
| M18 | one active frame fewer | killed |
| M19 | no `hurtbox_reach` | killed |
| M20 | box overlap strict | survived |
| M21 | startup or active of 0 accepted | survived |
| M22 | fractions accepted | killed |
| M23 | `first_difference` ignores length | survived (no caller produces one) |
| M24 | comparison always agrees | killed |
| M25 | overlay without fighters | killed |
| M26 | `randi()` in walking | killed |
| M27 | holding repeats the move | killed |
| M28 | move ends a frame short | killed |
| M29 | no buffered start at a move's end | killed |
| M30 | digest omits player two | survived |
| M31 | wall-pinned fighter pushed into the wall | survived |
| M32 | `holds_away` inverted | killed |
| M33 | a per-process value in walking | survived by construction |
| M34 | odd unit to the left fighter | survived |
| M35 | negative damage in the game's copy only | killed only by the byte-for-byte test |

## What was done about them

- **Determinism.**
  - The recorded log's per-frame digests are committed in
    `godot/test/fight_log_digests.txt`. The check holds the run to them as
    well as to a second run, so a value fixed per process now shows.
  - `make record-replay` rewrites the digests after a deliberate rules
    change.
  - Planted cases: a changed input for each player, which must show on the
    next frame, and a moved fighter, which the digest must show.
  - The log must cause a hit, a block, a counter-hit, a cancel and a trade.
    Cancels are now an event.
- **The rules.**
  - An odd overlap is split evenly, rounded up, held by a mirror test.
  - Against a wall, the attacker takes the pushback.
  - Events say why: "(caught starting up)", "(holding away)".
  - Both changes are written into the resolution order.
- **A test for each unguarded rule**, twelve in all:
  - the buffer at exactly its length and one frame after;
  - the cancel window's last frame and the one after, and a move cancelling
    only into what it lists;
  - pushback in the open and against a wall;
  - the double knockout;
  - blocking in blockstun and not in hitstun;
  - the counter-hit's hitstun;
  - facing kept during a move;
  - the mirror push;
  - boxes touching at an edge;
  - the refused frame data.
- **Re-run as mutations, each now killed**: M1, M2, M4, M5, M6, M8, M10,
  M11, M14, M15, M17, M20, M21, M30 and M34, plus the new wall pushback and
  the cancel event.
- **The frame data** is checked in full: every number whole and
  non-negative, hitboxes and windows ordered, a known button, real cancel
  targets, some moves. Five planted refusals. The scene shows a refusal
  instead of failing in `_draw`.
- **The overlay** requires `phase`, and the dummy starts by jabbing, so the
  fighters change in the first steps, not only the frame.
- **The log** was re-scripted, since the wall pushback changed the fight.
  Its description gives the right frames and says it reaches no knockout.
- `log` is renamed `input_log`.
- **Left, on purpose:**
  - M23: no caller compares runs of different lengths except the recorded
    check, which reports either way.
  - No round timer: T16 is a training mode, and T17 decides.
  - No Python reader of the frame data yet: that is T17's first step.

The fixes were not reviewed by a second fresh context.
