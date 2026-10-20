# Frame data: the fighting scenario

<!-- doc-meta
half_life: structure
verified_on: 2026-10-16
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: a field in characters.json is renamed, or the resolution order in it changes
teaches: none
-->

> Every number a fight is resolved by, as data (T16). The Godot game reads a
> byte-for-byte copy, `godot/game/fighting/characters.json`, and a test
> holds the two equal; T17 and T18 read this one from Python.

`characters.json` holds:

- the stage, the input buffer's length, the pushback and the counter-hit
  bonus;
- `resolution`: the order a frame is resolved in, step by step, which
  `godot/game/fighting/fight_rules.gd` follows line for line -- who wins a
  trade (both: both hits land), what a counter-hit is (a hit on a move still
  in its startup), what blocks (holding away while free or already
  blocking, with the guard the move's height asks for), and what a throw
  does (beats any guard, loses to a strike, breaks against another throw,
  never catches a fighter in stun) (T34);
- two characters that differ in a way an opponent can exploit: the
  **lancer** reaches further and starts slower, the **dancer** is quick and
  short.

Per character: `health`, `walk_speed`, `body` (half its width), `tall` and
`crouching_tall` (how high its hurtbox reaches, standing and crouching), and
its `jump` (T38): `takeoff` frames still on the ground -- it cannot guard
and can be thrown -- then `rise` frames up to `height`, `hang` frames
there, `fall` frames down -- whole units on every frame, by integer
division -- `speed`
units a frame along the stage, fixed when up is pressed, and `landing`
frames when it touches down, when it can be thrown. In the air it cannot
guard and cannot be thrown, and it has one air move a jump -- none once it
has been hit in the air. Bodies push each other only on the ground, so a
jump can cross over to the other side.

And its `backdash` (T40), the evade, on a button of its own: `frames` long
from the press -- it can act again on the next one -- `travel` frames of it
going `speed` units a frame away from the way it faces, and on its first
`invulnerable` frames nothing finds it, strike or throw. After those, until
it is over, it cannot guard and can be thrown, and a strike that catches it
is a hit. It stays on the ground; into a wall it goes nowhere, protected all
the same. The numbers follow two shipped backdashes, cited in
`tasks/T40-an-evade-and-harder-levels.md`: invulnerable for about the first
quarter, 20 to 24 frames in all.

Per move: the `button` that does it -- light or heavy punch, light or heavy
kick, or throw -- and its `stance`, standing, crouching or air (holding down
picks the crouching move for a button, and a button with none does its
standing one; in the air only an air move comes out, and it hits as an
overhead); its `height`, which guard stops it: `high` is stopped standing
and is aimed above every crouch, so it passes over one (T39), `mid` either,
`low` only crouching, `overhead` only standing, `throw` neither; its `rise`,
how far above its owner's feet its hitbox reaches, bottom and top -- below
the feet for a kick from the air -- so that a box is two intervals and a hit
needs both to meet; `startup`, `active` and `recovery` frames, counted from 1;
`damage`, `hitstun` and `blockstun`; a `hitbox` as the near and far edge in
front of the body, out only on active frames; `hurtbox_reach`, how far in
front the fighter can be hit from its first active frame to its last
recovery frame; and a `cancel_window` with the moves it `cancels_into`, open
only once the move has connected. Every number is a whole number and none is
negative: a fraction of a frame would round differently somewhere, and a
replay would drift. `FightData` refuses a file that breaks any of this, or
names a button or a cancel target that does not exist.

A change here changes how the recorded fight in `godot/test/fighting/fight_log.json`
plays out, and so its digests: run `make record-replay`, and read the diff.
