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
./scripts/godot --headless --path godot -s res://test/fighting/replay_determinism.gd
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
  ~~bodies are kept apart in the air as on the ground~~ -- changed after the
  owner played it: **a jump crosses over.** While either fighter is in the
  air the bodies may pass; on landing they are pushed apart from the side
  each came down on, and a fighter in the air that is not attacking turns
  to face its target. A guard is held back from the way the strike travels
  -- face to face, that is holding away -- so a kick that lands after the
  crossing is guarded the other way: the cross-up, tested. (From the second
  review: judged off the two positions, two fighters on one spot blocked
  whichever way the defender stepped.)
- **Take-off** (from the review): `takeoff` frames, 4 and 3, on the ground
  before the arc, when the jumper cannot guard and can be thrown -- so up on
  the frame a throw arrives is too late, as in the genre's pre-jump. The
  landing frames can be thrown too; only hitstun and blockstun protect from
  a throw. The arc is off the floor on every one of its frames.
- **The moves.** Each character gets four air moves, one a button -- after
  the owner found only the heavy kick came out in the air: `air_jab`,
  `air_punch`, `air_kick` and `flying_kick`, all overheads -- and
  `uppercut` (heavy punch, crouching, a mid whose box reaches 260 and 220
  up) -- the anti-air, on the one button-and-stance both
  characters had free. Any strike that reaches can hit a jumper; the
  uppercut is the one built for it. Early it counter-hits the jump-in
  (frame 12 of the test's jump); late it is counter-hit by it (frame 20).
- **One air move a jump, none once hit in the air** (from the review): a
  fighter knocked out of the air could otherwise recover and kick again in
  the same jump. Its stun still runs down while it falls.
- **The pictures**: the template's own jump, uppercut and four air attacks,
  at the same cels in both sheets; twelve strips, cut by `make
  fighter-strips`, the 30 older ones byte for byte unchanged.
- **The training mode**: W jumps; two dummy modes, "low kick" every second,
  and "anti-air (sees you now)", which uppercuts as soon as you are in the
  air within 110 units -- the one mode that reads the present, and its name
  says so. The T37 opponent does not jump, and does not use the air moves.
