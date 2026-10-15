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

## Decided on the way (2026-10-15)

- **A box is two intervals, and the "high passes over a crouch" rule is
  gone.** Each character has a `tall` and a `crouching_tall`, each move a
  `rise` above its owner's feet; a hit needs both intervals to meet. A high
  passes over a crouch because every high starts above every crouch -- a
  test holds that -- and a low passes under a jump for the same reason. The
  recorded fight played out frame for frame and event for event as before.
- **The arc** is `rise`, `hang` and `fall` frames to a `height`, by integer
  division, with `speed` along the stage fixed at take-off and `landing`
  frames on touching down; it goes on whatever happens, so a fighter hit in
  the air still comes down where its jump was taking it. No cross-ups:
  bodies are kept apart in the air as on the ground.
- **The moves.** Each character gets `flying_kick` (heavy kick, in the air,
  an overhead) and `uppercut` (heavy punch, crouching, a mid whose box
  reaches 260 and 220 up) -- the anti-air, on the one button-and-stance both
  characters had free. Any strike that reaches can hit a jumper; the
  uppercut is the one built for it. Early it counter-hits the jump-in
  (frame 12 of the test's jump); late it is counter-hit by it (frame 20).
- **The pictures**: the template's own jump, uppercut and flying kick, at the
  same cels in both sheets; six strips, cut by `make fighter-strips`, the 30
  older ones byte for byte unchanged.
- **The training mode**: W jumps; two dummy modes, "low kick" every second,
  and "anti-air (sees you now)", which uppercuts as soon as you are in the
  air within 110 units -- the one mode that reads the present, and its name
  says so. The T37 opponent does not jump, and does not use the air move.
