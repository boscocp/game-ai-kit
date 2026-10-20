# T34 — High, low and the throw

Size: M · Prereqs: T16 · Files: `spec/frames/`, `godot/game/fighting/`, `godot/test/`

## Goal

Give the fighting scenario the guessing game every fighting game has, before
any AI is put in it. T16 left one defence that answers everything: hold away.
An opponent model (T17) learns what a player does when it matters which way
they guess, and against "hold away" nothing they do matters.

Three things make the guess:

- **Four attack buttons**, punch and kick, light and heavy: light is quick and
  short and does little, heavy is slow and does a lot. The owner's layout, and
  the one most fighting games since the arcade use.
- **Heights.** A move hits *mid*, *low* or *overhead*. Standing guard stops mid
  and overhead; crouching guard stops mid and low. So a fighter blocking low
  can be opened by an overhead, and one blocking standing by a low.
- **The throw.** It cannot be blocked at all, so it is the answer to a fighter
  who only guards. It is beaten by a strike that lands first, and it cannot
  catch a fighter in stun, so it is a guess too.

Guard, strike, throw: each beats one and loses to another. That triangle is
what T17 will learn a player's habits inside.

## Steps

1. Input: a down direction, and five buttons -- light and heavy punch, light
   and heavy kick, throw -- in place of light, heavy and special.
2. Frame data: every move carries a `stance` (standing or crouching) and a
   `height` (mid, low, overhead, throw). Holding down when the move comes out
   -- pressed, from the buffer, or as a cancel -- picks the crouching move for
   that button; a button with none does its standing one.
3. Crouching: holding down while free crouches, and a crouching fighter does
   not walk.
4. The resolution order says, and `FightRules` does: a block needs the guard
   the height asks for; a throw is never blocked, never a counter-hit, and
   never catches a fighter in stun; two throws on one frame break each other;
   a throw and a strike on one frame, the strike wins.
5. The training mode draws a crouching fighter lower, and a hitbox at the
   height it hits; the panel names the height. The dummy can guard standing
   or crouching, and throw.
6. The recorded log is rewritten for the new inputs and made to exercise a
   low and an overhead getting through, and a throw.

## Acceptance

```bash
make test-godot
python3 scripts/check_readability.py
```

```bash
./scripts/godot --headless --path godot -s res://test/fighting/replay_determinism.gd
```

The replay check refuses a log that never causes a throw, a low hitting a
standing guard, or an overhead hitting a crouching one, as it already refuses
one with no hit, block, counter-hit, trade or cancel.

```bash
./scripts/godot --headless --path godot -s res://test/menu/demo_overlays.gd
```

## Manual check

Play both characters against the dummy in each of its guards. A sweep should
get through the standing guard and be stopped by the crouching one, an
overhead the other way round, and a throw through both. Light buttons should
feel quick and heavy ones slow.

## Decided on the way (2026-10-15)

- **The keys are an arcade panel's**: U and I punch, J and K kick, light on
  the left; S crouches; L throws. A throw has its own button rather than a
  chord, because two keys on one frame is hard on a keyboard and the log
  would have to say which frame "together" was.
- **No crouching heavy punch.** A button with no crouching move does its
  standing one, and the fighter stands to do it, so no button is dead while
  crouched. The rule is in `FightData.move_for_button`, not in each move.
- **A wrong guard is a hit, never a counter-hit.** A fighter that can guard is
  free or in blockstun, so never in a move's startup; the event says which
  height got through which guard.
- **Throws have no escape window yet.** The triangle closes without one: a
  quick strike beats a throw's startup, and a throw cannot catch a fighter in
  stun. A tech window is one more thing to guess, and T36 decides whether
  the opponent model needs it.
- **The jump is T38**, asked for by the owner while this was being built. It
  is a second axis, and it would have doubled this task.
- **The dummy's modes** are stand, guard standing, guard crouching, jab and
  throw: one guard of each height, so a person can try each answer to it.
