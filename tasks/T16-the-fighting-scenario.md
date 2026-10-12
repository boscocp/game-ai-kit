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
./scripts/godot --headless --path godot -s res://test/replay_determinism.gd
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
