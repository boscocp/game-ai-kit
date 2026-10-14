# 0008 — The simulated combat is dice, not a formula

Status: accepted · 2026-10-13 (decided in T5, written down in T7)

## Context

The learning lesson needs data: fights, and whether the attacker won. The
quickest simulator writes the chance of winning as a function of the
features -- and the obvious function is a logistic one.

Then a logistic regression fitted to that data recovers the coefficients
somebody wrote three files away, to the decimal. It looks like a perfect
model, and it has learned nothing: the lesson is circular.

## Decision

A fight in `python/gameaikit/dataset/combat.py` is rounds of dice. Both sides
trade damage, the defender's terrain adds to the damage it returns, a
numeric advantage adds to the blows of whichever side holds it, and a friend a
few cells away can arrive partway through. The relationship between the
features and the outcome is real, noisy, and **not** the shape of the model
fitted to it.

## Alternatives considered

- **A logistic formula with noise added.** Rejected: still circular, with a
  blur on it.
- **Recorded games from real play.** The honest source, and not available: the
  game has had no combat to record (T26 brings one; T10 deferred it to
  keep this rule).

## Consequences

- The model is wrong sometimes -- right about 88% of held-back fights -- and
  every weight has the sign the dice imply. Both are what make it worth
  printing.
- The score has to be read against something. Against "the attacker always
  loses" it looks better than it is; against a lookup table of training fights
  (82%), honestly. `weights.txt` publishes both.
- The simulator is not the game's combat and must not become it: when T26
  writes combat in GDScript, the dataset is regenerated from that, or the
  model is fitted to rules the player never sees.
