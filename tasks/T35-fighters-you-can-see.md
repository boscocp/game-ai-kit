# T35 — Fighters you can see

Size: M · Prereqs: T34, T9 · Files: `godot/assets/`, `godot/game/fighting/`, `godot/game/art.gd`, `docs/adr/`

## Goal

Two coloured blocks become two fighters, each with its own animation for every
move, from openly licensed sprite sheets found on the internet. The owner's
rule: download open packs first, generate only to fill a gap (ADR 0012).

The boxes stay. Sprites are what a player looks at; the hitbox and hurtbox are
what a person learning frame data has to see, and they are drawn over the
sprite, as a training mode in any fighting game draws them.

## Steps

1. Search for side-view fighter sprite sheets under a licence this repository
   can ship -- CC0 first, CC-BY if the credit is carried -- and write what was
   found, where, under what licence, and why each was taken or left, in the
   task's notes. Two characters that look different, each with idle, walk,
   crouch, hit and enough attack frames to give every move its own.
2. **Only the cuts are committed, never the downloaded sheets** (the owner's
   rule): each committed strip listed with the sheet and cels it came from,
   its licence and its own sha256, and the sheets referenced by URL and
   sha256 so anyone can download them and repeat the cut.
3. Animation is driven by the frame data, not the other way round: the move
   and the frame of it pick the sprite frame, so a replay draws the same
   pictures and the animation can never disagree with the boxes.
4. The game still runs with no sprites on disk, drawing blocks as before.

## Acceptance

```bash
make test-godot
python3 scripts/check_license.py
```

```bash
./scripts/godot --headless --path godot -s res://test/demo_overlays.gd
```

## Manual check

Open `make demo-fighting`. Each fighter should look like a fighter, each move
should have its own animation, the boxes should sit where the limbs are, and
the frame step (P, then space) should advance the animation one frame.

## Decided on the way (2026-10-15)

- **The template is Puffolotti's Mustermann 2** (CC0): 997 cels of one karate
  fighter in two costumes, the only free set found with a crouch, guards, a
  sweep and a grab. What else was looked at, and why it was left, is in ADR
  0015.
- **A strip is whole cells.** Each sheet is an exact grid -- 35 by 29, every
  cel inside its cell -- so a whole cell keeps the feet in place and no cel
  needs an offset.
- **The lancer is drawn at full size and the dancer at 80%**, so each
  figure's reach is near the reach its frame data gives it. The boxes still
  do not match the limbs exactly, and are drawn over them to show it.
- **A move's cels are listed by phase** in `sprites.json`, and spread over
  that phase's frames: the active cels are on screen exactly while the
  hitbox is out. A test walks every frame of every move.
- **The walk is read off where the fighter stands**, so walking backwards
  plays it backwards and a replay draws the same cels.
- **Seen, once**: a short scripted fight recorded with Godot's movie maker
  showed both fighters facing each other, the axe kick over a crouching
  guard and the dancer's throw, the boxes over the figures. The manual check
  is still a person's.
