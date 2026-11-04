# T115 — A Bayesian network: is someone there, and why does the guard think so?

Size: M · Prereqs: T112 · Files: `godot/addons/ai_bayes/`, `godot/test/ai_bayes/`, `modules/ai_bayes.json`, `python/gameaikit/bayes/`, `python/tests/`, `spec/vectors/bayes/`, `godot/game3d/infiltration/`, `godot/test/infiltration/`, `docs/techniques/`, `docs/concepts/`, `Makefile`

## Goal

**Starts only once the owner has opened the repository**, which is a step
after T112, not T112 itself (the owner, 2026-11-04).

The literature table lists Bayesian networks (AIMA ch. 13) as "not in the
kit", at tier 1. The owner asked for them on 2026-11-04. A guard is the
natural place.

`ai_perception` already estimates *where* the player is, with a particle
filter. A network answers a different question, from the evidence the
guard has: a noise, a door left open, a lamp out, a colleague not
answering. Is there an intruder at all? And which evidence moved the
belief most?

## Decisions written down first

_The decisions below are this session's proposal, written on 2026-11-04; the owner has not ratified them. The wave that takes the task confirms them, or brings them back to the owner._

- **A new addon, `ai_bayes`**, independent of every other addon
  (invariant 2). Discrete variables, conditional probability tables,
  exact inference by enumeration (AIMA fig. 13.10), read top to bottom
  like the pseudocode. Variable elimination is named on the page as the
  next step, and is not built.
- **The tables are written by hand in a data file, not learned.** They
  are not trained at game time (invariant 6).
- **The guard's state follows the belief:** above a threshold it
  searches, below it returns to its route. The infiltration's guards
  (T70) keep their perception; the network reads their evidence.
- **Shown** (invariant 13): the network with each node's probability, and
  the evidence that changed it last.
- **Twins and vectors:** Python twin, AIMA's burglary network as a vector
  worked by hand, `derive.py` with no import from the repository.

## Acceptance

```bash
make test-bayes-vectors
make test-python
make test-godot-some SUITES="test/ai_bayes test/infiltration"
python3 scripts/check_addon_deps.py
make lint-modules
make test-demo-overlays
```

## Manual check

In the infiltration demo, open a door and leave: does the guard's belief
rise, is the open door named as the reason, and does it fall again when
nothing else is found?
