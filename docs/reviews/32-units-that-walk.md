# Review: wave/32-units-that-walk

One fresh context reviewed it, in its own git worktree, detached at 6fd37b1.
It read CLAUDE.md, T33, ADR 0014, the how-to and the diff `0bdac37..6fd37b1`.
It ran `make check` and `check_license.py`. It downloaded the Puny
Characters page and zip and compared sha256s, measured the four sheets with
Pillow, and checked `model.json` and the LoRA card against the Hugging Face
API at the pinned revisions. It ran 30 mutations against `unit_view_test`,
`art_test`, `tactical_game_test` and `main_scene_test`. It did not run the
generator or use the GPU, by instruction.

A worktree has neither `godot/addons/gdUnit4/` (installed by bootstrap) nor
`scripts/forbidden-term-hashes.txt`; both were copied in read-only.

## What was reviewed

Commit 6fd37b1:
- `godot/game/unit_view.gd`, `unit_sheet.gd`, `unit_walk.gd`, and `art.gd`
  (`SHEET_FILES`, `sheet_for`, `table_for`, `sheet_path`);
- the `walk` calls in `tactical.gd` and `main.gd`;
- the four Puny sheets and their `LICENCES.md` rows;
- the new `unit_view_test.gd`, and the changes to `art_test.gd` and
  `tactical_game_test.gd`;
- `tools/artgen/`, the how-to and ADR 0014.

## Checked and true

- `make check` passed: 616 gdUnit cases, 250 Python tests, every vector,
  property and overlay run.
- The page gives the Puny Characters licence as CC0 1.0, with "No need to
  give me credit". The zip's sha256 matches `LICENCES.md`. All four
  committed PNGs are byte-identical to `{Warrior,Soldier}-{Red,Blue}.png` in
  the zip.
- Every sheet is 24 by 8 frames of 32 px.
  - Rows 0, 2, 4 and 6 face the reader, right, away and left.
  - Columns 0-1 are idle, 2-3 step, and 4 onwards attack, so the walk
    `0,2,0,3` is a sound reading.
  - The drawn frames stay inside the square (5,3,22,22). The attack frames
    go further, and are never drawn.
- klein base at `a3b4f484` is Apache-2.0, and its transformer and VAE
  hashes match. Its text encoder has the same sha256 as klein's, so
  borrowing it is sound.
- The LoRA at `cb8bffe5` is Apache-2.0 and its hash matches. The
  unsuffixed file is the 3000-step one. The card's quote, its CC BY 4.0
  credit and its row order are as stated, and `WALK_PROMPT` is the card's
  sentence word for word.

## Findings

Of 30 mutations, 21 were killed and 9 survived.

### Must fix

- **The legends showed a different picture from the board.**
  - Both legends still drew the Tiny Battle silhouette for the shield and
    the soldier. A reader could not find the shield the legend named.
  - The committed sheet also hid a T31 user's own generated
    `shield.png`, against Art's promise that their picture is drawn.
- **A plain `make artgen` broke for anyone set up the documented way.**
  - The walk entries needed `klein-walk`, which bootstrap does not fetch,
    and loading it raised.
  - The record of what made the pictures was written only at the end, so
    a failure lost the record for pictures already made.
  - The how-to's "every picture" and "30 pictures" were no longer true.

### Should fix

- `R` (new game) kept the old game's facings and, where a destination
  matched, its walks: ids repeat across games.
- The skirmish board's walks were untested: M14 and M15 survived.
- Behaviours the ADR states were held by no test:
  - M7: figures bob too;
  - M16: the walk uses the march rate;
  - M17: blue faces right by default;
  - M24: the sheet cache ignores the folder;
  - M29: the generated table's left and right rows are swapped;
  - M20 and M21: Puny's left and right rows swapped, and the figure square
    the whole frame.
- The ADR said the game judges a generated sheet by `fits`, but the game
  never called `fits`.
- "8 GB saved" by borrowing the text encoder was false for anyone without
  klein: the fetch took klein's 7.75 GB transformer too.
- The timings disagreed: 23-42 s in one place, 23-48 s in another.

### Notes

- "Clockwise" in `unit_sheet.gd` is counter-clockwise on screen.
- The LoRA card does not say the middle frame is the standing one.
- `unit_view.gd`'s header and its 16-pixel comment predate T33.
- `tactical.gd` had a fallback to (0,0) that could never produce a walk.
- `UnitView.clock` is set directly by the tests, though the ADR says only
  `advance` moves it.
- The T33 `Files:` line left out `tactical.gd`, `main.gd` and the tests.
- Player-visible and judged acceptable, for the manual check:
  - a red unit greys as it starts walking;
  - enter starts every blue walk at once;
  - a quick second skirmish step snaps a mid-cell unit to its last
    destination;
  - a unit can be clicked at its destination before it arrives.
- `generate.py measure` ignores an entry's model.
- Under M23, `main_scene_test`'s wall test also failed, with no causal link
  found. Possibly timing-sensitive.

### The mutations

| # | Mutation | Result |
|---|---|---|
| M1 | `show_state` never drops a walk | killed |
| M2 | `show_state` drops only dead walkers | killed |
| M3 | `frame_of` ignores facing | killed |
| M4 | `advance` never records facing | killed |
| M5 | `table_for` swapped | killed |
| M6 | no bob | killed |
| M7 | figures bob too | survived |
| M8 | spent figures march | killed |
| M9 | `fits` skips divisibility | killed |
| M10 | `fits` skips figure-in-frame | killed |
| M11 | `fits` skips rows | killed |
| M12 | tactical blue does not walk | killed |
| M13 | tactical red does not walk | killed |
| M14 | skirmish red does not walk | survived |
| M15 | skirmish blue does not walk | survived |
| M16 | walking frame uses `MARCH_RATE` | survived |
| M17 | default facing always right | survived |
| M18 | default facing swapped | killed |
| M19 | Puny walk = idle columns | killed |
| M20 | Puny left/right rows swapped | survived |
| M21 | Puny figure square = whole frame | survived |
| M22 | walk point never leaves a cell | killed |
| M23 | walk one cell longer | killed |
| M24 | sheet cache ignores `Art.generated` | survived |
| M25 | units at rest bob | killed |
| M26 | tactical blue walk starts at first step | killed |
| M27 | tactical red walk starts at first step | killed |
| M28 | finished walks never let go | killed |
| M29 | generated table left/right swapped | survived |
| M30 | `sheet_path` ignores faction | killed |

## What was done about them

- **The legends** draw `UnitView.legend_picture`, the frame the board draws
  a figure standing in, so they match the board. **A person's own still
  picture** of a kind with no sheet of theirs is drawn instead of the pack's
  figure.
- **`make artgen`** leaves out entries that name their own model unless
  they are named, and says so. It writes the record after each model's
  group. A model that lists its `kinds` refuses every other kind:
  `--model klein-walk` on a sprite now exits 2 before loading anything,
  which was run. One sheet was regenerated with the fixed generator, in
  57 s. The how-to says what a plain run makes.
- **A new game** calls `UnitView.reset`, which forgets walks and facings.
- **`Art.sheet_for`** checks every sheet with `fits` and falls back to the
  still picture.
- **The borrowed encoder** is fetched alone, with only its own hashes, and
  `model.json` no longer claims a saving.
- **Timings**: one range everywhere, 23-57 s over the nine sheets measured
  between T31 and T33, the first of a run the slowest.
- **The notes**: the comments on rotation, the standing frame, the header,
  the 16-pixel line and the clock are corrected; the dead fallback is gone;
  the `Files:` line is complete.
- **New tests**, each planted against its mutation, all red with the
  mutation in and green without:
  - M7, M14, M15, M16, M17, M21, M24 and M29;
  - and four for the fixes: no reset on a new game, `fits` unused, a
    person's still picture ignored, and a legend showing the still picture.

  M21 is now held against the picture itself: every drawn frame's pixels
  lie inside the figure square, and fill at least three quarters of it one
  way.
- **Left, on purpose:**
  - M20 (Puny's left and right rows swapped) is not tested. The two rows are
    mirror images, the soldier's bar one pixel, so only a guess about which way a face
    points could tell them apart. The reviewer checked them by eye.
  - Removing the `sheet_if_it_fits` call from `sheet_for` would survive: no
    committed sheet is the wrong size, and the call's own logic is tested.
  - The player-visible notes go to the manual check.
  - `measure` ignoring an entry's model is harmless while no probe is a
    walking sheet.

The fixes were not reviewed by a second fresh context.
