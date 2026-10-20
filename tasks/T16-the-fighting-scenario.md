# T16 — The fighting scenario

Size: L · Prereqs: T8 · Files: `godot/game/fighting/`

## Goal

Two characters, frame-accurate, with a hitbox system that does not lie. No AI
yet — this is the board the next two tasks play on.

**Most of this task is not AI**, and that is said here so nobody is surprised
by it halfway through: hitboxes, hurtboxes, frame data, input buffering and
cancel windows are the work, and they are the reason a fighting game is the
last of the three to build.

## Steps

1. Frame data as data: startup, active and recovery frames per move, in a file,
   not in code. A fighting game whose frame data is scattered through its
   methods cannot be balanced or reasoned about.
2. Hitbox and hurtbox per frame, and a resolution order that is written down:
   who wins a trade, what a counter-hit is, what happens on a simultaneous hit.
3. Input buffering and a move list with cancel windows. The buffer is what makes
   a game feel fair and is the first thing a human notices missing.
4. Two characters that differ in a way an AI can exploit: one with reach, one
   with speed. If they are mirror images, the opponent model in T17 has nothing
   to learn.
5. Deterministic replay from an input log. This is not a luxury — T17 and T18
   both need to replay a human's inputs, and a non-deterministic engine makes
   learning from them impossible.

## Acceptance

```bash
make test-godot
python3 scripts/check_readability.py
```

```bash
./scripts/godot --headless --path godot -s res://test/fighting/replay_determinism.gd
```

That script replays a recorded input log twice and asserts the two runs agree
frame by frame. Determinism is the property everything after this rests on, and
it is cheap to assert and expensive to discover missing.

```bash
test -f spec/frames/characters.json
```

## Manual check

Play both characters against a dummy. Moves should come out when you ask for
them, and a trade should resolve the way the table says it does.

## Decided on the way (2026-10-14)

- **One axis.** The stage is a line and a box an interval: two characters
  on the ground, no jumps. Enough for reach against speed, trades, blocks
  and cancels, and a fraction of the work of two dimensions.
- **Whole numbers only**, in the data and the engine, and every frame a new
  immutable `FightState`: determinism by construction, not by care.
- **The data lives in `spec/frames/characters.json`**, as the acceptance
  asks, because T17 and T18 will read it from Python. The game reads a copy
  in `godot/game/fighting/`, and a test holds the two byte for byte.
- **A trade is both hits landing in full.** Each connection is judged on the
  fighters as the hitbox test found them, before either is applied; the
  attacker's move is recorded first, since the first hit applied knocks the
  other attacker out of its move.
- **Blocking is holding away while free or already blocking.** Walking
  backwards *is* holding away, so a fighter in the open walks out of range
  as it blocks; the recorded log blocks with the dancer against its wall.
- **The example is a training mode** (`make demo-fighting`): there is no AI
  yet, so `step_decision` is one frame and the overlay is each fighter's
  move, frame, phase, boxes, stun and buffer. The dummy stands, blocks or
  jabs. Invariant 13 is read as: show the resolution, since that is the
  decision being made.
- **The recorded log** (`godot/test/fighting/fight_log.json`) was scripted, not
  played by hand, so that a hit, a block, a counter-hit, a cancel and a
  trade each happen at least once; the determinism script refuses a log
  missing any of those five. It does not reach a knockout; the rules suite
  holds the knockout and the double-knockout draw.
- **The determinism check compares against a record**, not only against a
  second run in the same process, which would agree about anything fixed for
  the life of a process. `godot/test/fighting/fight_log_digests.txt` holds every
  frame's digest; `make record-replay` rewrites it after a deliberate rules
  change. It plants a changed input for each player, and a moved fighter the
  digest must show. Found by the wave 34 review.
- **Separation splits an odd overlap evenly, rounded up**, so pushing right
  and pushing left are mirror images; and **pushback against a wall is taken
  by the attacker**, as in most fighting games, so the corner is not free
  pressure. Both are in the resolution order. Found by the wave 34 review.
- **Events say why**: "counter-hits ... (caught starting up)", "is blocked
  by ... (holding away)", "cancels jab into kick".
- **No round timer** yet: a training mode does not need one. T17 decides
  whether its logged sessions do.
