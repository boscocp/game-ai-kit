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
./scripts/godot --headless --path godot -s res://test/tactical/difficulty_matches.gd
```

That script plays each level against each other level over a fixed seed set and
asserts the ordering holds: harder beats easier more often than the reverse,
by a margin the script states as a number. A difficulty ladder that is not
monotonic is not a ladder. The human-likeness knobs T25 adds are held off
here, because they cost strength too; T25 re-asserts this ordering with them
on.

```bash
./scripts/godot --headless --path godot -s res://test/tactical/difficulty_knobs.gd
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

## What was done (2026-10-19, wave 55) -- done, manual check still a person's

Taken as written, on the owner's word. When it started, the planner lost
to the rules 2-18 as red, so a level built on it could not clear the floor.

- `Difficulty` (`ai_planning`): the three knobs, `KNOBS`, the presets.
- `HeuristicPlanner`: a horizon -- worlds that far out are not expanded,
  and a goal beyond it is a partial plan, never "impossible".
- `FightOdds`: a fight's odds from the rules and the die's faces, exact;
  `TacticalCombat` shares its bonuses with it rather than keeping a copy.
- `LeveledBlue`: per walker, the rules' walk, staying, or a cell to attack
  from, weighed at 1 or 2 plies with Wesnoth's aggression (0.4).
- The scene: C cycles rules, planner, learned, easy, normal, hard; S swaps
  sides, so the person can play blue.

**Every number below was played by one command**, 50 seeded games from each
seat, each game its own dice:

    ./scripts/godot --headless --path godot -s res://test/tactical/difficulty_matches.gd \
        -- --measure HORIZON,DEPTH,NOISE HORIZON,DEPTH,NOISE|rules

| first | second | first wins, of 100 |
|---|---|---|
| 1 ply | 1 ply, noise 0.5 | 70 to 29 |
| 1 ply | 1 ply, noise 1.0 | 86 to 12 |
| 1 ply, noise 0.5 | 1 ply, noise 1.0 | 64 to 34 |
| 2 plies | 1 ply | 59 to 40 |
| 2 plies | 2 plies, noise 0.5 | 55 to 44 |
| 2 plies | 2 plies, noise 1.0 | 77 to 23 |
| 1 ply | 2 plies, noise 0.5 | 58 to 42 |
| 2 plies, no plan | 2 plies, horizon 2, 4 or unlimited | 77 to 23, each |
| 1 ply | itself | 45 to 55 |
| 2 plies | itself | 45 to 53 |

Against the rules, of 50 from each seat: 1 ply 50 and 50; noise 0.5, 49
and 49; noise 1.0, 39 and 41 -- under the floor; 2 plies with noise 0.5, 47
and 46.

**What was wrong before the levels were ordered**, each found by watching a
game rather than by tuning:

1. The route to the goal went round enemy pieces, as the rules' does. Two
   sides that ringed their workshops left each other no route; every option
   was then worth 0, and from round 16 nothing moved. Now it is measured
   over the terrain: a piece in the way is a fight to weigh, not a wall.
2. Standing still was worth more than the rules' fallback walk, so the
   clean level stayed put in 73% of its decisions and noise *helped*: noise
   1.0 beat none 65 to 35 in 100. Progress is now measured towards where
   the rules would walk the piece, and the rules' walk is always weighed.
3. Ply 2 counted every answer in full and the side that could see answers
   stayed home. Wesnoth's aggression, 0.4, from the reference and not
   fitted (`docs/design/tactical-references.md` 2.1), weighs its own losses
   at 0.6.

**The plan horizon weakens**, so every level plans 0 actions ahead. That is
a finding about T11's plan (save for the forge, then a ram) on today's
board, not about planning: buying by the rules is better. It is the
owner's to weigh.

**Three levels, not five.** Nothing measured fits between normal (1 ply)
and hard (2 plies) -- 2 plies with noise 0.5 lost to 1 ply -- and below
easy, noise 1.0 is under the floor. A step past hard needs a third ply.

**After the review** the attack after a walk stopped overruling a search
that chose not to attack, and asking the rules for a walk stopped taking a
goal the walker then did not go to. Both changed the numbers: the noisy
levels of the first presets (noise 1.0 and 2.0) fell under the floor, and
the presets moved to the ones above.
