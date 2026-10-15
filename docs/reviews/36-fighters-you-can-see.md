# Review: wave/36-fighters-you-can-see

One fresh context reviewed it, in its own git worktree, at 3ca7820.

What it read: CLAUDE.md, ADRs 0012 and 0014, T35, the wave 35 review, and
the diff.

What it ran:
- `make check`, and each T35 acceptance command;
- the source page, fetched fresh: its licence line, its comments, and both
  sheets downloaded again and hashed;
- `make fighter-strips` from the sheets, and `crop.gd` against a corrupted
  sheet, a missing one and no argument;
- the licence gate against an unlisted and an altered strip, by simulating
  the index (the worktree's stage was refused);
- probes of the pose at every frame, the view's walk flag, and `complete`;
- 17 mutations.

## What was reviewed

Commit 3ca7820: `sprites.json`, `fighter_sprites.gd`, `fight_view.gd`,
`art.gd`, `tools/fighters/crop.gd`, the two make targets, `LICENCES.md`, the
30 strips, `fighter_sprites_test.gd`, ADR 0015, T35 and STATUS.

## Checked and true

- `make check` exited 0; the sprite suite 8 of 8, seven examples' overlays.
- The page's licence is CC0, by Puffolotti; both sheet URLs are its own
  links, and fresh downloads hash to the table's sha256s.
- Each sheet is exactly 35 by 29 cells of the sizes the table gives, 997
  non-empty in each.
- `LICENCES.md`'s 30 rows name the same sheet and cels, in order, as
  `sprites.json`; no cel is in two phases of one move.
- **The cut reproduces byte for byte**: `make fighter-strips` left `git
  status` empty.
- `crop.gd` checks the sha256 before cutting: a corrupted sheet exits 1 and
  writes nothing; a missing sheet or no argument exits 2.
- The licence gate still reports an unlisted strip (L11) and an altered one
  (L17).
- Every phase of all 16 moves has at least as many frames as cels, so
  `move_index` stays in its phase; frames before the start and past the end
  give the first and last cel. 240 drawn frames of the real scene raised no
  engine error.

## Findings

### Must fix

1. **The ADR put words in the author's mouth.** It said the template's page
   comments state that the 3D model was not licensed for release and that
   the posing tool permits images. No comment on that page says so. The
   words were from the same author's other page, the Universal Prototype,
   and had been paraphrased on top.
2. **The walk depended on how often the view was redrawn.** `_walking`
   compared with the last call to `show_fight`, and a key press redraws the
   same state -- so under the frame step a walking fighter was always drawn
   standing, which is exactly T35's manual check.

### Should fix

3. **A fighter only being pushed was drawn walking**: 198 frames of a dancer
   pushed by the lancer, pressing nothing.
4. **"Active cels exactly while the hitbox is out" was false** once a move
   connected: the hitbox ends, the active cels go on. True: active cels on
   the active frames.
5. **`complete` did not check the frame data's moves**: a move erased from
   the table left the character "complete", and `move_index` then failed
   inside `_draw` -- the half-drawn fighter the ADR said could not happen. A
   table with no `characters` logged an error on every call.
6. **The strips bypassed `Art`**: loaded with `load()`, so a person's own
   strip under `generated/` was never drawn, and the header claimed every
   picture name is in `art.gd`.
7. **The legend described colours no longer drawn**: red and blue swatches
   for the two sides, and a pale swatch at a different alpha from the
   sprite's.
8. **Tests that missed real breakage**: a `move_index` showing only each
   phase's first cel, a hit played backwards, a frozen idle and a view that
   never walks all survived.

### Notes

- A few cels touch their cell's edge; the lancer's sweep cel has its toe cut
  by the render itself.
- The dancer's walk skipped cels (four units a cel at five a frame).
- Short hitstun never showed the hit's first cel.
- `make fighter-sheets` swallowed a failed download unless it was the last.
- No gate holds that a strip holds the cels its row lists; accepted, since
  the sheets are not in the repository.
- The no-strips test tested a missing table, and printed a JSON parse error
  in a green run.
- "776 KB" was disk usage; the bytes are 637,285.
- The Universal Prototype's "crouching cels are still to come" overstated
  "I hope i can add more crouching cels".
- The page's notice, "Sprite created by Puffolotti Accident", was not
  carried.
- One header line ran to 130 characters.

### The mutations

17 tried. Killed: `move_index` ignoring phases, `<` for `<=`, the walk
flipped, `complete` ignoring a missing strip, blockstun ignored, a 10%
scale, a strip one cel too wide, the crouching guard shown standing.
Survived: only each phase's first cel (M2), the hit backwards (M6), a frozen
idle (M9), a view that never walks (M10), a table cel swapped with the count
kept (M13, accepted), and three that only a picture shows -- unmirrored,
anchor at the corner, always the sprite (M11, M12, M14) -- plus one
near-equivalent (M7).

## What was done about them

- **The ADR** now quotes the author, with the date and the page the words
  are on: "I don't have the licenses to release the 3d models i used" and
  "Yes, it is in the license of DazStudio, wich, i remind, is free." -- and
  says the template's own page says nothing about the model's licence.
- **Walking is read off the fight**: `FighterSprites.walks` -- free,
  standing, and this frame's input holding a direction. The view keeps no
  history. A pushed fighter does not walk; the frame step shows the walk.
  The cel advances every four frames at either character's speed.
- **`complete(character, data)`** requires every animation, every move the
  frame data has, and every strip the table lists; `read` returns an empty
  table for a missing or malformed file without an error.
- **Strips load through `Art.texture`**, so `generated/` overrides them; the
  ADR records that their names live in `sprites.json`, not `art.gd`.
- **The legend** names the health bars for the sides and uses the sprite's
  own pale tint.
- **Tests**, each run against its mutation and seen to kill it: every cel of
  a move is shown (M2); a hit plays first cel to last (M6); standing still
  advances with the frame (M9); walking is read off the fight, and a pushed
  or crouching fighter does not walk (M10); a missing strip and a move
  missing from the table each leave the character a block. The no-table
  test is named for what it tests.
- **The notes**: the hit holds three frames a cel; `fighter-sheets` stops on
  the first failed download; the ADR's size, edge and Universal Prototype
  wording are corrected; the notice is carried in `LICENCES.md`; the line is
  wrapped.
- **Left, on purpose:** M13 (no gate can see a swapped cel without the
  sheets), and M11, M12 and M14, which only a person looking at the screen
  can catch -- T35's manual check.
