# T39 — High punches pass over a crouch

Size: S · Prereqs: T34 · Files: `spec/frames/`, `godot/game/fighting/`, `godot/test/`

## Goal

The owner played T34 and found a standing punch landing on a crouching
fighter. In most fighting games it does not: a standing punch is aimed at the
head, and a fighter who crouches is not there. Kicks reach lower and still
land, as the owner said.

The owner then added: a kick that only goes up high should not land on a
crouch either. The heights now follow where the limb goes in the picture.

So a fifth height, **high**: a high move's hitbox does not find a crouching
fighter at all -- not a block, a whiff. Standing guard stops it like a mid.
That gives crouching something it lacked in T34: besides guarding lows, it
ducks highs, and a person who reads a jab coming can duck it and punish.

## Steps

1. `high` in the frame data's heights, and every standing punch of both
   characters made high. The dancer's spinning kick, at head height in its
   cels, becomes a high `roundhouse`. The two light kicks, drawn at head
   height too, are recut as side kicks to the waist and stay mid. The
   lancer's axe kick, which comes down from above, stays an overhead.
2. The resolution order says, and `FightRules` does: in step 4, a high
   hitbox does not find a crouching fighter.
3. The training mode draws a high hitbox at head height, so a crouching
   fighter is seen to be under it.
4. The recorded log still causes every resolution it must: its trade, which
   was a straight against a crouching sweep, becomes a snap kick.

## Acceptance

```bash
make test-godot
./scripts/godot --headless --path godot -s res://test/fighting/replay_determinism.gd
```

## Manual check

Crouch against the dummy's jab and the dancer's roundhouse: both should
pass over you. The side kicks and the axe kick should still land.

## Decided on the way (2026-10-15)

- **Hitstun is taken standing.** A fighter reeling from a hit cannot crouch
  until the stun is over, so a combo cannot be ducked halfway -- the dancer's
  jab into its straight lands both. Blockstun keeps the guard held, crouching
  or not. Found by the wave 37 review; it is in step 2 of the resolution.
- **A pass-over is an event**: "p1's jab passes over p2 (a high misses a
  crouch)", on each frame the boxes meet, so the panel shows why nothing
  connected. The recorded log must cause one.
- **A hitbox is drawn at the height it hits on its target**, not on the
  fighter swinging: the lancer stands taller than the dancer, and its high
  was drawn above her head.
