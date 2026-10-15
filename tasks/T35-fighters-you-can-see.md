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
2. Every downloaded file listed with its source, licence and sha256, as T9's
   are, and `make check`'s licence gate holding them.
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
