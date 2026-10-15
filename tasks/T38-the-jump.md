# T38 — The jump

Size: M · Prereqs: T34 · Files: `spec/frames/`, `godot/game/fighting/`, `godot/test/`

## Goal

A second axis, asked for by the owner while T34 was being built. T16 kept the stage a
line on purpose, and a jump is what that left out: a fighter in the air, an
arc whose height is a whole number on every frame, attacks done in the air,
and the anti-air that answers them.

It earns its place by adding a corner to T34's triangle rather than a feature:
a jump goes over a low and out of a throw, and loses to a strike aimed up.
That is one more habit T17 can learn a player has.

## Steps

1. Up as a direction; a jump's arc as frame data -- rise, hang and fall in
   whole frames and whole units -- straight up, forwards or back, committed
   once it leaves the ground.
2. A fighter in the air cannot be thrown and cannot block, and a jump-in
   attack hits as an overhead.
3. Boxes become rectangles: an interval along the stage and one up from the
   floor. A low passes under a fighter in the air.
4. An anti-air move per character that beats a jump-in if it is early.
5. The recorded log exercises a jump over a low, a jump-in hitting, and an
   anti-air.

## Acceptance

```bash
make test-godot
./scripts/godot --headless --path godot -s res://test/replay_determinism.gd
```

## Manual check

Jump over the dummy's low kick, jump in on it, and get knocked out of the air
by its anti-air.
