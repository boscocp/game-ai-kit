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

- The model is wrong sometimes -- right about 86% of held-back fights since
  T26 (88% before) -- and every weight has the sign the dice imply. Both are what make it worth
  printing.
- The score has to be read against something. Against "the attacker always
  loses" it looks better than it is; against a lookup table of training fights
  (79% since T26, 82% before), honestly. `weights.txt` publishes both.
- The simulator is not the game's combat and must not become it: when T26
  writes combat in GDScript, the dataset is regenerated from that, or the
  model is fitted to rules the player never sees.

## Amended in T26 (2026-10-17)

The game now has the combat this ADR waited for, and the consequence above
was kept: the fight is one rule in `spec/combat/rules.json`, read by the
dataset (`gameaikit.dataset.combat`) and by the tactical board
(`TacticalCombat`), held to each other by `spec/vectors/combat/`. Two things
changed in the data because the game does them: the winner keeps the health
it has left instead of walking away whole, and the counter table adds to the
blows of the side that is strong against the other -- which the dataset's
untyped units never trigger, so its rows cannot see it. The model was
retrained on that data: 85.9% of held-back fights, against 56.8% for the
majority answer and 78.8% for the lookup table.

