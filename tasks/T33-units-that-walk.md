# T33 — Units that walk

Size: M · Prereqs: T31 · Files: `godot/game/unit_view.gd`, `godot/game/art.gd`, `godot/game/tactical/`, `godot/game/main.gd`, `godot/test/`, `godot/assets/`, `tools/artgen/`, `docs/adr/`

## Goal

Every piece on the tactical board is one still picture. The owner wants to
see them move -- a soldier walking to the cell it was sent to, a truck
rolling -- and to judge it **in the game**, not in a GIF.

Two halves, as in T9 and T31: the game learns to draw frames from a sheet,
and the art comes from a pack first and from the generator second.

## What was measured before this task (2026-10-14, in T31)

- **Twelve frames from a general model fail.** FLUX.2 klein drew twelve
  soldiers in random poses when asked for a sheet, and twelve near-copies
  growing noise when each frame was given the one before as reference.
- **Three frames per direction at 32 px work**, with a LoRA made for it:
  `svntax-dev/pixel_spritesheet_4walk_small_lora_v1` (Apache-2.0, revision
  `cb8bffe5`) on `black-forest-labs/FLUX.2-klein-base-4B` (revision
  `a3b4f484`), 512 px, 50 steps, guidance 4, then one colour per cell down
  ×4 to 128 px: a 4×4 sheet of 32×32 frames -- three walking frames facing
  down, left, right and up, and a pose each. 23-48 s a sheet, 8.3 GB peak.
  The owner judged the text-prompted sheet good enough to go on with.
- **From a reference picture it lost the soldier**: the Z-Image sprite as
  reference gave a red mannequin with no shield and no spear.
- The LoRA's training data is CC BY 4.0: a committed sheet made with it may
  need attribution. Check before committing one.
- It is made for figures that walk. A truck, a cannon, a boat and a ram do
  not have legs.

## Steps

1. **Look for packs first** (the owner's rule): CC0 or CC-BY sprite sheets
   with walk cycles for small units, listed file by file in `LICENCES.md`.
2. **Frames in the game.** A sheet is one picture and a frame table; `Art`
   names the sheet, and `UnitView` draws the frame for the time. The still
   picture stays the fallback when there is no sheet, so nothing breaks for a
   unit without one.
3. **Moving is visible.** A unit sent to a cell walks there along its route
   over a fraction of a second, facing the way it goes, rather than
   appearing there. The decision overlay (invariant 13) still shows where it
   is going before it goes.
4. **Machines**: a two-frame bob or a wheel turn, not a walk cycle.
5. **The generator**: a `walk` kind in the manifest, using the model and
   LoRA above, writing sheets to the gitignored folder like every other
   generated picture.

## Acceptance

```bash
make check
python3 scripts/check_license.py
```

The suite must include:
- a unit with a sheet draws a different frame at two different times, and a
  unit without one draws its still picture;
- a moving unit is drawn between cells partway through its move, and at its
  destination once the move is over;
- every sheet `Art` names is a picture whose size divides into its frame
  table.

## Manual check

The owner plays `make demo-tactical` with walking units and says whether it
reads better than still pictures. Animation is exactly what a headless run
cannot see.

## Decided on the way (2026-10-14)

- **The pack is Puny Characters** (Shade, OpenGameArt, CC0): a red and a
  blue copy of the same figure, walking in eight directions on 32-pixel
  frames. `Warrior` is the shield, `Soldier` the skirmish soldier. Ninja
  Adventure, also CC0, was looked at first: its download page could not be
  fetched by a script, and its author's repository has no red figure.
- **Figures march on the spot at rest**, as Advance Wars' do, and stand
  still once spent. The task asked only for a walk; the march is what makes
  "a different frame at two different times" true of a unit not moving.
- **The machines bob in code**, two frames while rolling and none at rest.
  No art was drawn for them.
- **Generated sheets are not committed.** The LoRA's training data is CC BY
  4.0, and the question of attribution is left open (ADR 0014).
- The skirmish board's soldiers walk too: they are figures with a sheet,
  and leaving their moves as jumps beside the tactical board's walks would
  have been two rules for one view.
