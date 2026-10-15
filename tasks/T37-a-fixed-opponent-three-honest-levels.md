# T37 — A fixed opponent, at three honest levels

Size: M · Prereqs: T36 · Files: `godot/game/fighting/`, `godot/test/`

## Goal

An opponent for the fighting scenario that does not learn, at three
difficulties, none of which cheats. T12's rule on the fighting board: the hard
opponent is hard because it decides better, not because it sees more.

Shaped by T36's survey (`docs/concepts/fighting-game-ai.md`). Most fighting
games script their opponents (the FightingICE platform paper); one director
describes it: reactions per situation -- after a hit, a block, a whiff, a
knockdown -- with chance in them so the computer reacts more like a person
(Soulcalibur V). Street Fighter 6 groups those actions
into situational decks and sets difficulty on two axes: how many tactics a
level has, and how well it executes them. The research arena adds the third
axis and fixes it: every AI sees the fight 15 frames late, a person's
reaction time (the FightingICE platform paper).

An opponent with reflexes no person has -- a low guarded on the frame it was
pressed -- is what an under-tuned AI has, in that director's words ("inhuman
reflexes"). Whether shipped games read the controller was not established by
T36, and this task makes no claim about any game. It holds its own opponent
to the rule either way.

## Steps

1. A rule-based opponent implementing `DecisionPolicy`: reactions grouped by
   situation -- neutral, after blocking, after being hit, the other fighter
   whiffing, the other fighter crouching -- each a weighted choice over T34
   and T39's options: guard standing or crouching, strike high, mid, low or
   overhead, throw, step in or out.
2. Three knobs, written down per level:
   - **reaction**, in frames -- how old the fight it sees is. At least 15 at
     every level, the competition's number; more at the easy end.
   - **tactics** -- how many of the situations' options the level has.
   - **execution** -- how often a chosen action comes out as chosen rather
     than as a slower or wrong one.
3. A gate: the opponent reads only a `FightState` at least its reaction time
   old, by construction -- it is handed the past, not the present -- and a
   planted opponent that reads the current frame is refused.
4. The levels are ordered: over a fixed set of seeded fights, each beats the
   one below it.
5. The training mode can put it in the dummy's place, and the panel shows
   the situation it saw, the frame it saw it on, and the choice it drew.

## Acceptance

```bash
make test-godot
```

`godot/test/fight_opponent_test.gd` holds the knobs: the opponent is handed
a `FightState` exactly its reaction time old, every level's reaction is at
least 15 frames, and a planted opponent that asks for the current frame is
refused.

```bash
./scripts/godot --headless --path godot -s res://test/opponent_levels.gd
```

The levels are ordered: over 100 seeded fights of each pairing, at both
characters, each level wins at least 60 against the level below it, and the
script asserts every number -- two pairings in two mirrors -- after a planted
pairing, a level against itself, that must not reach 60. `make
test-opponent-levels` runs it, and `make check` with it.

```bash
python3 scripts/check_demos.py
```

The training mode's overlay carries the situation the opponent saw, the
frame it saw it on and the choice it drew.

## Manual check

Play each level. Easy should be beatable by mashing, hard should not, and
none should guard a low you pressed less than a quarter of a second ago.

## Decided on the way (2026-10-15)

- **Not a `DecisionPolicy`.** That interface takes a `BoardState` and returns
  a board `Move`; a fight is neither, and checkers and tic-tac-toe do not
  implement it either. `FightOpponent.choose(seen, me) -> int` has the same
  shape -- a state in, a decision out -- in the fight's own types. Widening
  `ai_core` for one game would put the fight's types in every addon's
  dependency. T17 says the same thing of its model; it meets the same wall.
- **"Handed the past" is `FightDelay`.** The game gives it the present; it
  gives the opponent a copy of the frame `reaction` frames back. It reads the
  reaction once, at seating, and refuses one under 15. Before `reaction`
  frames have passed, the opponent is handed nothing and holds nothing.
- **The levels**, in `FightOpponent.LEVELS`:

  | | reaction | tactics | execution |
  |---|---|---|---|
  | easy | 30 frames | 2 options a situation | 60% |
  | medium | 22 frames | 4 | 85% |
  | hard | 15 frames | all (up to 9) | 100% |

  A fumble is half the time 10 frames late, half the time another option.
  An option is a guard, a step, or a strike at a height -- the character's
  quickest move at it; one out of reach in the frame it saw becomes a step in.
- **Mirror fights.** `opponent_levels.gd` plays each pairing with both
  fighters the same character, both characters, so it measures the level and
  not the lancer's reach. A fight still on at 99 seconds goes to the one with
  more health. Measured on 2026-10-15: medium beats easy 95 and 99, hard
  beats medium 93 and 99 (lancer, dancer); medium against itself wins 42.
- **The training mode opens on the medium opponent**, not the jabbing dummy,
  so the first thing on screen is something deciding. M cycles through the
  scripted modes and then the three levels.
- **What the panel shows**: the level and its reaction, the situation, the
  frame it was seen on and how many frames ago, and the choice drawn -- with
  the move, "out of reach: steps in", or the fumble. `demo_overlays.gd` now
  holds the fight to two fields, `phase` and `seen_frame`, and has a planted
  overlay missing the second.
