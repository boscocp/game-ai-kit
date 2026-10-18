# T53 — How racing AI is made

Size: S · Prereqs: T23 · Files: `docs/concepts/`, `tasks/`

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

## Steps

1. The academic side: what the competitions measured, which controllers
   placed, and what the learned drivers needed to train (and whether tier 1
   could).
2. The shipped side: racing lines, braking points, overtaking, drivers that
   learn from a player, and how difficulty is set.
3. How a racing AI cheats, and how a player can tell.
4. What T54 takes from each, and what it leaves: the player toggling 1-3
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
