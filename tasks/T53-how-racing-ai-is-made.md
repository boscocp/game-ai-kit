# T53 — How racing AI is made

Size: S · Prereqs: none · Files: `docs/concepts/`, `tasks/`

## Goal

T36's pattern, for racing: before a 3D car with real physics gets a driver,
read how others have built one. A survey from both sides -- research (the
simulated car racing competitions on TORCS, Gran Turismo's learned driver,
racing-line optimisation) and shipped games (fixed drivers on a racing line,
the drivers that copy a player, and how difficulty is set -- including
rubber-banding, which T23 refuses and should be able to say why with
sources) -- ending by rewriting T54 in its light.

Every reference is opened before it is cited, as T36 did; what could only
be read as an abstract is said to be so; what could not be checked is
listed and not used.

It comes before both racing demos, as T36 came before the fighting
opponents: it rewrites T23 (the 2D racer, still todo) as well as T54.

## Steps

1. The academic side: what the competitions measured, which controllers
   placed, and what the learned drivers needed to train (and whether tier 1
   could).
2. The shipped side: racing lines, braking points, overtaking, drivers that
   learn from a player, and how difficulty is set.
3. How a racing AI cheats, and how a player can tell.
4. What T23 and T54 take from each, and what it leaves: the player toggling 1-3
   techniques the survey found worth it.

## Acceptance

```bash
test -f docs/concepts/racing-ai.md
python3 scripts/check_links.py
python3 scripts/check_doc_freshness.py
python3 scripts/check_tiers.py
```

## Manual check

Every reference opens and says what the page says it says.

## Decided on the way (2026-10-18, wave 54)

- **The page is `docs/concepts/racing-ai.md`.** 30 references, each
  opened. Those read only in part -- an abstract, the first part of a
  chapter, or a web page read through a summarising fetch -- say so, and
  the web pages are paraphrased, not quoted.
- **T23 takes**: pure pursuit's lookahead, the grip margin, and the
  steering wander as its three knobs; a speed profile from curvature and
  grip, computed backwards from the tightest corners; and a braking point
  where full braking no longer makes the next corner.
- **T54 takes**: PID control of speed and line, the heat line for
  overtaking, and grip measured rather than given (the kit's own choice;
  T54 says when, and how it sits with invariant 6).
- **Rubber-banding**: refused, with the arguments for and against on the
  page. Besides adjusting the cars, some shipped games use skill that moves
  with the player's position (Pure; Melder recommends it), and a slow
  biorhythm in skill (Game AI Pro). T23 refuses both, with a check on the
  knob values the controller actually used.
- **Left**: learned drivers, cloning a player, and optimising the racing
  line.
