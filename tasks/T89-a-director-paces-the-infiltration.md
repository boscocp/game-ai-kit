# T89 — A director paces the infiltration level

Size: M · Prereqs: T70 · Files: `godot/game3d/infiltration/`, `godot/test/infiltration/`, `spec/director/`, `spec/vectors/director/`, `python/gameaikit/director/`, `python/tests/`, `modules/infiltration.json`, `docs/godot/`, `docs/concepts/`, `Makefile`

## Goal

The owner, 2026-10-26, answering T73's question 1: every entry of part A
("todos"), the recommended three first -- MCTS, **the director**, the
particle filter. This is the second.

A director teaches adapting the *game*, not the enemy. *Left 4 Dead*'s, in
Booth's slides [Booth 2009]: "Estimate the 'emotional intensity' of each
Survivor", "Track the max intensity of all 4 Survivors", "If intensity is
too high, remove major threats for awhile", "Otherwise, create an
interesting population of threats". Intensity rises "proportional to damage
taken", when a nearby infected dies "inversely proportional to distance",
and decays "towards zero over time" -- but not while infected are engaging
the survivor. Four phases: **Build Up** (full threats until intensity
crosses the peak threshold), **Sustain Peak** (3-5 seconds more), **Peak
Fade** (minimal threats until intensity decays out of the peak range), and
**Relax** ("30-45 seconds, or until Survivors have traveled far enough
toward the next safe room", then Build Up again).

## Decisions written down first (the owner confirms in review)

- **Home: the infiltration level** (T70), not the bot match. It has one
  person to read intensity from, guards that can be sent, and generated
  levels to show the director is not a script for one map. The bot match
  is the named alternative.
- **What raises intensity here**, each with a fixed weight in
  `spec/director/director.json`: a guard's awareness of the player rising
  (seen, heard), a guard searching within a radius (inversely to
  distance), being caught. It decays at a fixed rate, and not while a
  guard is actively chasing -- Booth's rule, translated.
- **What the director controls**: how many of the level's reserve guards
  are on patrol, and where a new patrol starts (out of the player's sight,
  as `LevelGenerator` already places guards out of the start's). It never
  moves a guard that sees the player, and never teleports one.
- **Invariant 6**: every number above is fixed and the director only
  computes the player's intensity from what happens; it fits nothing.
  This is Booth's design as stated -- a value raised by events, decaying
  over time, against thresholds -- and needs no ADR.
- **The director does not cheat on fairness**: it knows where the player
  is (a director is the game, not a guard), but no guard does through it;
  a guard sent on patrol gets a route, not the player's position. A gate
  holds that no guard's belief changes when the director acts.

## Steps

1. Read Booth's slides (the director section) again and the infiltration
   code (`infiltration_world.gd`, `guard_team.gd`, `level_generator.gd`).
2. `python/gameaikit/director/`: intensity and the four-phase machine,
   stepped on a list of timed events; vectors in `spec/vectors/director/`
   (an event list in, the intensity curve and phase changes out).
3. `Director` in `godot/game3d/infiltration/`, the same machine, held to
   the Python by the vectors; reserve guards in the level data (the two
   hand-made levels and the generator).
4. A switch, key 6 beside T70's 1-5: director on or off (off is the level
   as T70 made it). Measured over
   seeded runs of the scripted player T70's gates already use: time spent
   in each phase, how often intensity peaks, and that relax happens.
5. Pages: a `docs/concepts/` section on pacing, and the infiltration page.

## Acceptance

```bash
python3 -m unittest discover -s python/tests -t python -p "test_director*.py"
make test-director-vectors
make test-godot-some SUITES="test/infiltration"
python3 scripts/check_no_training.py --skip-retrain
python3 scripts/check_demos.py
make lint-modules
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Play the infiltration level with the director on, twice on the same seed
and once on a generated level: do you feel the quiet stretches and the
pressure, and does the curve on screen agree with what you felt? Does a
new patrol ever appear where you could see it arrive?

How invariant 13 is met: with the thinking view on (H, as T70 made it), a
strip on the HUD draws the player's intensity over the last minute with
the peak threshold, the current phase by name, and each director action as
a mark on the strip and a line on the map to where the patrol starts -- the
decision and the number it was taken on.

References, opened on 2026-10-26: Booth, M. "The AI Systems of Left 4
Dead." Valve, 2009, the "Adaptive Dramatic Pacing" slides
<https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf>;
Brewer, GAP Online 2021 ch. 7, as cited by T73.
