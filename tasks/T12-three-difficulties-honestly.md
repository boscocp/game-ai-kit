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

**The floor.** T30's rule-based blue is the weakest opponent on the
tactical board. Every difficulty level here is measured against it as well
as against the others, so "easy" still means "better than rules".

## Steps

1. One knob per axis, named and documented: plan horizon in actions, search
   depth in plies, evaluation noise as a fraction, drawn uniformly from the
   seed.
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
./scripts/godot --headless --path godot -s res://test/difficulty_knobs.gd
```

That script is the real never-cheat check, and it is an allowlist. It asserts
that every preset sets exactly the documented knobs and nothing else, and that
an AI at any level is built with the same resources, vision and command
interface as the player. A list of forbidden names misses a cheat that is
simply renamed; a list of what is allowed does not.

```bash
test -s godot/addons/ai_planning/difficulty.gd && ! sed 's/#.*//' godot/addons/ai_planning/difficulty.gd | grep -qiwE 'cheat|cheats|bonus_resources|extra_vision'
```

A cheap tripwire beside it, on one line so that it cannot pass in parts. It
began as `grep -qv`, which succeeds whenever any one line does not match and
so passed on a file full of cheats. Its first fix passed on a missing file and
failed on a comment saying the levels never cheat. Now the file must exist and
be non-empty, comments are stripped, case is ignored and whole words are
matched; this was checked on six planted files. A string literal can still
trip it, which is the cost of a tripwire.

## Manual check

Read `difficulty.gd` once in review for a cheat under a name no command
knows. That is the part of never-cheating no gate can hold.

Play a game at each level. The hardest should feel like it is thinking further
ahead, not like it is being given things, and losing to it should be
explainable.
