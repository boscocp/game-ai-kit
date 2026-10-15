# Review: wave/37-high-punches-pass-over-a-crouch

One fresh context reviewed it, in its own git worktree, at e304f93.

What it read: CLAUDE.md, T34, T39, the wave 35 review, ADR 0015 and the diff.

What it ran: `make check`; the fighting and sprite suites; the replay; a
mirror probe of 400 seeded fights of 3,000 frames over all four pairings;
probes of a fighter standing up on a high's active frame, of a high against
a crouching move, and of a combo into a high; `make fighter-strips` against
the committed strips; 13 mutations.

## What was reviewed

Commit e304f93: the frame data and its copy, `fight_data.gd`,
`fight_rules.gd`, `fight_view.gd`, `sprites.json` and the recut strips with
their `LICENCES.md` rows, `fighting_test.gd`, the log and its digests, T39,
the spec README and STATUS.

## Checked and true

- `make check` exited 0. The pass-over is in step 4, read off the
  defender's crouch on that frame: a dancer standing up on the jab's first
  active frame is hit, one standing up a frame later is passed over first.
- A straight against a sweep passes over and the sweep hits alone; a throw
  against a crouch is unchanged.
- The mirror holds: 0 mismatches, with 1,084 high hitboxes over a crouch.
- The JSON's text and the code agree; the spec copy is identical; the log
  does what its description says at every frame named.
- The new side kicks are at belt height, the roundhouse at head height;
  `LICENCES.md` matches `sprites.json` on all 30 rows; the strips reproduce
  byte for byte; the old files are gone with their import files.

## Findings

### Must fix

1. **A fighter in hitstun could duck a high by holding down.** Out of a
   move, `crouching` followed the held input, stunned or not -- so the
   dancer's jab into its straight was escaped by holding down after the jab,
   while the picture showed the victim standing in its hit pose.

### Should fix

2. **The lancer's high was drawn above a standing dancer's head**: the bar
   was placed by the swinging fighter's height (154) on a target of 118.
3. **High through a crouching guard was unreachable, and `_a_height` had no
   "high"**, so making it reachable would have crashed.
4. **No test had a high passing over a crouching move.**

### Notes

- A test comment still said "shin kick".
- A pass-over left no event, so neither the panel nor the log could show it.
- The step-4 comment was not rewrapped; T39's STATUS row was out of order.
- Nothing exercises the view's high depth: only a picture shows it.

### The mutations

8 of 13 killed. Survived: high blocked by a crouching guard (equivalent,
finding 3), no pass-over while stunned and no pass-over in hitstun (finding
1), pass-over only out of a move (finding 4), and the view's high depth
removed (note).

## What was done about them

- **Hitstun is taken standing**, written into step 2 of the resolution; a
  test has the lancer hold down from the frame after the jab, and the
  straight still lands. The two hitstun mutations are killed.
- **The hitbox is drawn at the height it hits on its target.**
- **`_a_height` has "high"**, with a comment saying the branch is not
  reached.
- **A test** has the straight pass over the sweep, which lands alone, no
  trade; the "only out of a move" mutation is killed.
- **A pass-over is an event**, on each frame the boxes meet; the log now
  ends with the lancer's jab passing over the crouching dancer, and the
  replay check requires one.
- The comment, the wrapping and the row order are fixed.
- **Left:** the view's depth table is checked by eye, in T39's manual
  check.
