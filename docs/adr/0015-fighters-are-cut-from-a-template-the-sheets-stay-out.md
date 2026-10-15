# 0015 — Fighters are cut from a template, and the sheets stay out

Status: accepted · 2026-10-15 (decided in T35)

## Context

Until T35 the fighting scenario drew each fighter as a coloured block. The
owner played it and wanted fighters: a figure with its own animation for every
move, from openly licensed sprites found online (packs first, the generator
second, as T9 and T33 did).

A fighting game wants more of a character than any pack T9 or T33 used: a
stance, a walk, a crouch, two guards, a hit, a fall, and a different
animation for each of eight moves -- light and heavy punch and kick, a low
jab, a low kick, a sweep and a throw. Most free fighter packs have a punch, a
kick and a hurt; a crouch or a guard is rare, and a sweep rarer.

## What was looked at (2026-10-15)

- **Fighting character template Mustermann 2**, by Puffolotti, OpenGameArt,
  CC0: <https://opengameart.org/node/97941>. 997 cels of a karate fighter in
  two costumes, rendered with a fixed camera -- stance, walk, crouch, guards,
  punches, kicks, sweeps, grabs, hits, falls and jumps. **Taken.**
- **Base for fighting or beat'em up**, by CapitanRasputin: has a grab and a
  throw, but is CC-BY 3.0 and its itch.io page forbids redistributing the
  files on their own. Left.
- **Universal Prototype for scrolling beat 'em up**, Puffolotti, CC0: 3,150
  cels, but few crouching ones; its author writes that he hopes to add more.
  Left.
- **Action hero**, Printer Not Found, CC0: a crouch, two jabs and a kick, no
  guard and no sweep. Left.
- **Samurai [Animated]**, **SumoHulk Brawler**, **Brawler 'Vigilante' SMS**:
  CC0, each without a crouch, a guard or a kick. Left.

## Decision

**Commit the cuts, never the sheets.** The owner's rule. Each sheet is about
1.7 MB, and the two fighters draw about 150 cels between them. What is
committed:

- **30 strips** under `godot/assets/fighters/<character>/`, one per animation
  or move: the listed cels side by side, whole cells of the sheet's grid, 637
  KB in all.
- **The table** that says which cels, `godot/game/fighting/sprites.json`: for
  each sheet its URL and sha256, and for each character its sheet, where the
  feet are in a cel, the scale it is drawn at, and its cels by animation and,
  for a move, by phase.
- **The cut**, `tools/fighters/crop.gd`, which checks each downloaded sheet's
  sha256 against the table before cutting anything. `make fighter-sheets`
  downloads into `build/` (gitignored); `make fighter-strips` cuts.

So the sheets are referenced -- URL, sha256, date -- for anyone who wants to
download them and check the cut, and the repository holds only what is drawn.
This departs from ADR 0012's "each file is the pack's own, byte for byte" for
these files only, and `LICENCES.md` says so on each row: a strip's row names
the sheet and the cels it holds, and its sha256 is the strip's.

**Whole cells, not the figure's bounding box.** Each sheet is an exact grid --
35 cels across, 29 down, 229 by 238 pixels in one costume and 236 by 237 in
the other, every one of the 997 inside its cell (measured; a few touch an
edge, and in cel 823, the lancer's sweep, the render itself cuts the toe off
at the cell's edge -- the next cell's first columns are empty). Rendered with a
fixed camera, a whole cell keeps the feet where they were, so every cel lines
up with every other and no per-cel offset needs writing down.

**One template, two fighters.** The lancer is the orange costume drawn at full
size, the dancer the blue one at 80% -- the size follows the reach the frame
data gives each. Their moves are different cels: the lancer's heavy punch is a
lunging punch and his heavy kick an axe kick; the dancer's are a short
straight and a spinning kick. The stance, walk, crouch, guards, hit and fall
are the same cels in two costumes.

**The frame data leads; the picture follows.** `FighterSprites.pose` picks a
cel from the fight alone. A move's cels are listed by phase, and each phase's
cels are spread over that phase's frames, so a move shows its `active`
cels on its active frames and on no others -- whether or not the hitbox has
already connected, which ends the box and not the motion. A test walks every
frame of every move and holds that, and that every listed cel is shown. A
replay draws the same pictures as the fight, because the choice reads only
the fight's state: the move and its frame, the stun, the crouch, the frame
number, and whether the fighter's own input walked it this frame -- not who
moved it, and not how often the screen was redrawn.

**The boxes stay on top.** The sprite is what the move looks like; the boxes
are what it does. They will not match the limbs exactly -- a lunge in a
render steps forward, and the body in the frame data does not -- and the
training mode draws them over the figure so the difference is visible rather
than hidden.

**No strips, blocks.** A character is drawn from pictures only when every
strip it needs is on disk, and otherwise as the block it was. A test plants a
missing strip and holds that.

## Consequences

- The pictures are renders of a 3D model. This template's page says nothing
  about the model's own licence; a commenter asked for the model, and it
  was not released. On the same author's Universal Prototype page
  (<https://opengameart.org/content/universal-prototype-for-scrolling-beat-em-up-0>),
  he wrote on 2020-07-15: "I don't have the licenses to release the 3d
  models i used", and, answering a question about it, "Yes, it is in the
  license of DazStudio, wich, i remind, is free." That is all the sources
  say. What the CC0 dedication covers is the images, and only images are
  committed. If that dedication were ever withdrawn, the table and the cut
  make the fighters replaceable by changing one file.
- **The fighters' strips do not go through `Art`'s path table** the way
  every other picture does: `Art.fighter_strip` builds their paths, and the
  names live in `sprites.json`, not in `art.gd`. They are still loaded
  through `Art.texture`, so a person's own strip under `generated/` at the
  same path is drawn instead (T31).
- Choosing other cels is an edit to `sprites.json` and a `make
  fighter-strips`, then `LICENCES.md`'s rows; the licence gate fails until the
  rows' sha256s match.
- The sheets carry jumps. T38 will want them, and they are a table entry
  away.
