# T90 — A particle filter tracks the unseen player

Size: M · Prereqs: T69, T70 · Files: `godot/addons/ai_perception/`, `godot/test/ai_perception/`, `python/gameaikit/perception/`, `spec/vectors/perception/`, `python/tests/`, `godot/game3d/infiltration/`, `godot/test/infiltration/`, `docs/techniques/ai_perception.md`, `docs/techniques/ai_perception.pt-BR.md`, `docs/concepts/`, `Makefile`

## Goal

The owner, 2026-10-26, answering T73's question 1: every entry of part A
("todos"), the recommended three first -- MCTS, the director, **the
particle filter**. This is the third.

It teaches AIMA's chapter 14 (probabilistic reasoning over time: a
transition model, a sensor model, filtering; approximate inference in
section 14.5.3) on a problem the kit already has. T69's `BeliefMap`
spreads the guards' belief blindly along the graph and zeroes what a guard
sees [Isla 2013; McIntosh 2015, as its header cites]; it has no sensor
model. A particle filter moves hypotheses by the player's possible motion
and weighs them by what each guard perceived -- including what it did
*not* see and did *not* hear -- then resamples. Particle filters are the
sequential Monte Carlo technique robotics made standard [Thrun 2002].

## Decisions written down first (the owner confirms in review)

- **In `ai_perception`, beside `BeliefMap`**, as `ParticleBelief` over the
  same graph (a neighbour list, no level in it), answering the same
  questions -- where to search next, how certain -- so the guards can use
  either. Not a new addon: it is perception, and the guards already depend
  on `ai_perception`.
- **The models, fixed numbers** in the addon's knobs, written down:
  - transition: a particle keeps its heading with a fixed probability,
    else turns to a random neighbour, else stays -- a person walks on,
    unlike the grid's even spread;
  - sensor: a particle in a cell a guard sees, when the guard sees no one,
    has weight 0; a particle a guard *would* hear (T69's `PathHearing`, by
    path distance), when it heard nothing, is weighed down by a fixed
    factor; a sighting or a report collapses the cloud to the node.
  - resampling: systematic, every step; if every weight is 0, reseed
    evenly over the unseen nodes, and say so (as `BeliefMap.reseeded`).
- **Invariant 6**: nothing is fitted; every probability is a constant.
- **A shared generator for the twin**: Godot's and Python's generators
  differ, so `ai_perception` carries its own small seeded generator, the
  same algorithm as T86's, written in both languages. Invariant 2 forbids
  importing T86's; a copy of a dozen lines is the cost, said in its header.
  (Moving one generator into `ai_core` is the alternative; ADR 0021 keeps
  `ai_core` to the grid and the pathfinder port, so it is the owner's.)
- **The claim measured again**: T73 asked whether it "finds you sooner".
  With the infiltration level's scripted player and seeded runs, grid
  belief against particles: time from losing sight to the first guard
  seeing the player again, over the hand-made levels and 20 generated ones.
  Written down as measured, whichever way it goes.

## Steps

1. Read `belief_map.gd`, its Python twin (`python/gameaikit/perception/belief.py`),
   `PathHearing`, and how the guards use the belief
   (`godot/game3d/infiltration/guard_search.gd`).
2. Python first: `ParticleBelief` with the models above; vectors in
   `spec/vectors/perception/` (a graph, a seed, a list of what was seen
   and heard each step; the particle cells and weights out).
3. The GDScript twin, held to the vectors; gdUnit cases for the reseed and
   the collapse.
4. In the infiltration level: key 1 cycles none / grid belief / particles
   (today it toggles the belief); the guards' search reads whichever is on.
5. The measurement above, `make test-infiltration-tracking`, its table in
   the infiltration page; the `ai_perception` technique page in both
   languages gains the particle filter.

## Acceptance

```bash
python3 -m unittest discover -s python/tests -t python -p "test_perception*.py"
make test-perception-vectors
make test-infiltration-tracking
make test-godot-some SUITES="test/ai_perception test/infiltration"
python3 scripts/check_translations_docs.py
python3 scripts/check_no_training.py --skip-retrain
make lint-modules
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

In `make demo-infiltration`, break line of sight and hide, with the
thinking view on (H) and particles chosen (1): does the cloud follow where
you could have gone, thin where a guard looks, and drift away from where a
guard listened and heard nothing? Is the guard's next search point inside
it?

How invariant 13 is met: the particles drawn as dots on the floor, sized
by weight, every step; the cells a guard's sight just emptied flash; the
search point the guard chose from the cloud marked -- the belief the
decision is taken on, before the guard moves.

References, opened on 2026-10-26: AIMA 4th ed., contents (ch. 14; 14.5.3
Approximate inference in DBNs -- the contents do not name particle
filtering, so the section is cited by its title)
<https://aima.cs.berkeley.edu/contents.html>; Thrun, S. "Particle Filters in
Robotics." UAI 2002, the abstract <https://arxiv.org/abs/1301.0607>.
