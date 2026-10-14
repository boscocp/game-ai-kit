# Review: wave/30-art-that-is-not-a-coloured-square

One fresh context reviewed it, in its own git worktree, detached at the
feature commit. It read the task, the diff and the docs, ran `make check` warm
and again with `.godot/` deleted, compared all thirty pictures with the packs
byte for byte, probed the licence rule on throwaway repositories, and ran 42
mutations of the GDScript and the art files and 13 of `check_license.py`.

## What was reviewed

Commit 8ee9f10 on this branch:
- `godot/assets/`: thirty CC0 pictures from four Kenney packs, their `.import`
  sidecars, and `LICENCES.md`;
- `godot/game/art.gd`, the one table of paths, and the views that now draw
  from it: `BoardView`'s atlas, `UnitView`, `CheckersView`, `TicTacToeView`,
  the legends, and trees as a tile of their own on the tactical and stealth
  boards;
- the art rule in `scripts/check_license.py` (L11-L14) and its planted cases;
- `make import`, ADR 0012 and `docs/godot/importing-art.md`.

## Findings

Of the 42 engine-side mutations, 13 were killed and 29 survived, 8 of them
visual only. All 13 mutations of the licence rule were killed: its holes were
the cases it never planted.

### Must fix

- **T31's plan did not work, and the gate would then have credited generated
  art to Kenney.** ADR 0012 said a person's generated pictures go "to the same
  paths, gitignored". Git cannot ignore a path it tracks. Copying one picture
  over another left `check_license.py` at 0, with the row still saying Tiny
  Battle, CC0.
- **Nothing tested which picture a unit is drawn with**, which is the point
  of T9. Drawing every unit as the soldier, or drawing no picture at all,
  left every suite green.
- **"Every kind has a file of its own" was not held.** Only the five
  buildable kinds were compared, on red only, and file names were never
  checked for uniqueness. The bolt tower mapped to the watchtower's file, the
  workshop to the soldier's, and the blue shield's file replaced by the blue
  runner's, all survived.
- **The licence rule accepted any licence**, a row with a cell missing (it
  read the pack's file name as the licence), a path listed twice, a table
  inside a fenced block or a comment, and an orphan `.import`. `art.gd` said
  the gate refuses a non-CC0 file. It did not.
- **A picture that fails to import poisons its committed sidecar.** `--import`
  exits 0, prints `ERROR`, and rewrites the `.import` to `valid=false`, and
  putting the right picture back does not recover. `make import` hid all of
  it by discarding the output.

### Should fix

- No test tied an atlas column to its file: swapping `rough.png` and
  `wall.png` survived, since all seven tiles were still different.
- Trees drawn as trees were untested on both boards that draw them.
- The checkers and noughts-and-crosses choices were untested: every man red,
  no crown, the O drawn as an X, and five file swaps all survived.
- The tactical legend's unit lines were untested, and its `types.has` filter
  quietly dropped a kind with no art.
- Two numbers were wrong: "88 KB" (the pictures are 24 KB), and "16 and 64
  pixels" (the cross is 100).
- The art self-test was 53 lines with untyped parameters, committed in
  planted repositories (a machine that signs commits would break it), and
  hard-coded `PATH`.
- Under `make -j`, Godot targets that did not depend on `import` could run
  while it rewrote `.godot/`.

### Notes

- The silhouette test proves little on this pack: Tiny Battle draws every
  unit on a filled plate, and runner and wader differ in 13 of 256 pixels.
  "Five silhouettes" rests on the manual check.
- The checkers legend drew the crown white where the board tints it dark.
- The checkers board is still flat colour, and the two tactical sides differ
  by colour only.
- Checked and true: byte for byte against the packs, the 1.7 s import, all
  four packs' licence files, and that a fresh checkout needs the import.

## What was done about them

- **Every row in `LICENCES.md` carries the file's sha256**, and the gate
  compares it with git's index (L17). Overwriting a CC0 file and staging it
  now fails. ADR 0012 and `LICENCES.md` say T31 writes to a gitignored folder
  of its own, which `Art` will prefer, and say why the first plan could not
  work.
- **The licence rule reads its table by header**, with the cells counted, the
  licence held to an allowlist (CC0 1.0), and fenced blocks and comments
  stripped. A duplicate row (L15) and an orphan sidecar (L16) are findings.
  Each new rule has its planted case, and a picture edited on disk but not
  staged passes, because the index is what a commit takes.
- **`UnitView.pictures()`** is the data `_draw` draws, and a test holds that
  every unit gets its side's picture of its kind. `CheckersView.pictures_of`
  and `TicTacToeView.picture_of` do the same for a king's crown and the X and
  O.
- **`art_test`**: file names unique; every pair of kinds on each side apart
  in at least 4% of their pixels, a floor set just below the 5% measured,
  and said to be a floor; each atlas column is the file named for it; red and
  white men differ; the cross, the nought and the crown are three shapes, and
  the crown is not a man's.
- **Trees, water, the bridge and rock** are asserted on the tactical board,
  and trees on the stealth board. The tactical legend has one line per kind,
  from the rules, with its picture and its words.
- **`make import`** fails on any `ERROR` and on any sidecar marked
  `valid=false`, and says how to recover. Every target that runs the engine
  depends on it. The poisoning is written up in `importing-art.md`.
- **Smaller:** the numbers corrected; the legend takes an optional tint and
  the crown uses it; the self-test split into typed helpers that stage
  without committing and keep the caller's `PATH`; the ADR names the flat
  checkers board and the colour-only sides.
- **Re-run:** the 18 engine survivors that were not visual were planted
  again, and the new tests caught 17. The crown replaced by a man survived,
  so the crown is now compared with both men, and that one went red too.
  Twelve mutations of the new licence rules, including four that survived the
  first version of the new cases, all go red.
- **Left, on purpose:** the visual mutations (bilinear scaling, no nearest
  filter, the draw call itself, the sprite scale, the selection frame, the
  legend's pictures for ground and sides). Headless, nothing is drawn. The
  manual check is where they live.

The fixes were not reviewed by a second fresh context.
