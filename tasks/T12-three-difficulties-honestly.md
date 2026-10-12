# T12 — Three difficulties, honestly

Size: M · Prereqs: T11 · Files: `godot/game/`, `godot/addons/ai_planning/`

## Goal

Three difficulty levels, and none of them cheat.

The usual way to make a hard AI is to give it more resources, more vision or a
lower cooldown than the player has. That is a lie told to the player, and it
teaches nothing. Here difficulty is **how much the AI is allowed to think**:
the plan horizon, the search depth, and how much noise is added to its
evaluation before it chooses.

## Steps

1. One knob per axis, named and documented: plan horizon in actions, search
   depth in plies, evaluation noise as a fraction.
2. Three presets built from those knobs, and nothing else. If a fourth knob
   appears, it is written down and justified in the same place.
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
monotonic is not a ladder.

```bash
grep -qv "cheat\|bonus_resources\|extra_vision" godot/addons/ai_planning/difficulty.gd
```

## Manual check

Play a game at each level. The hardest should feel like it is thinking further
ahead, not like it is being given things, and losing to it should be
explainable.
