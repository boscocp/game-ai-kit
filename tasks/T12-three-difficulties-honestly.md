# T12 — Three difficulties, honestly

Size: M · Prereqs: T11 · Files: `godot/game/`, `godot/addons/ai_planning/`

## Goal

Difficulty levels -- three to start, five once the knobs prove monotonic -- and
none of them cheat.

The usual way to make a hard AI is to give it more resources, more vision or a
lower cooldown than the player has. That is a lie told to the player, and it
teaches nothing. Here difficulty is **how much the AI is allowed to think**:
the plan horizon, the search depth, and how much noise is added to its
evaluation before it chooses.

**Strength is one axis, and only one.** How well the AI plays and how human it
looks while playing are different things, and a game often wants the second
more than the first. That axis is T25's. This task builds strength alone, and
leaves the two kinds of knob separate so that a level can be *weak and
human-looking*, or *strong and inhuman*, on purpose.

## Steps

1. One knob per axis, named and documented: plan horizon in actions, search
   depth in plies, evaluation noise as a fraction.
2. Presets built from those knobs, and nothing else: three first, then five
   (very easy to very hard) if every neighbouring pair is measurably ordered.
   A level that cannot be told apart from its neighbour is not a level, and is
   cut rather than kept for the menu. If another knob appears, it is written
   down and justified in the same place.
3. AI against AI, so the levels can be measured rather than felt: run the
   match headless, N times, and report the win rate.
4. The player can take either side at any level.

## Acceptance

```bash
make test-godot
```

```bash
./scripts/godot --headless --path godot -s res://test/difficulty_matches.gd
```

That script plays each level against each other level over a fixed seed set and
asserts the ordering holds: harder beats easier more often than the reverse,
by a margin the script states as a number. A difficulty ladder that is not
monotonic is not a ladder. The human-likeness knobs T25 adds are held off
here, because they cost strength too; T25 re-asserts this ordering with them
on.

```bash
! grep -q "cheat\|bonus_resources\|extra_vision" godot/addons/ai_planning/difficulty.gd
```

That line used to read `grep -qv`, which succeeds whenever any single line of
the file does not match -- so it passed on a file full of cheats.

## Manual check

Play a game at each level. The hardest should feel like it is thinking further
ahead, not like it is being given things, and losing to it should be
explainable.
