"""How a fight is decided, which is the thing the model has to learn.

This is written as a little simulation rather than as a formula, and that is
the whole point of the exercise. If the chance of winning were a logistic
function of the features, a logistic regression would recover the coefficients
exactly and the lesson would be circular -- the model would have "learned" the
line somebody wrote three files away.

So a fight here is rounds of dice: two sides trade damage, the defender's
terrain adds to the damage it returns, a numeric advantage adds to the blows of
whichever side holds it, and a unit that was a few cells away can arrive
partway through. The relationship between the features and the outcome is
real, noisy and **not** the shape of the model that will be fitted to it. What
the weights then say is an approximation somebody can be wrong about, which is
the only kind worth printing.

Since T26 this is also the game's combat. The numbers are read from
`spec/combat/rules.json`, which the tactical board reads too (ADR 0007), and
`fight` is a pure function of the dice it is handed: the two languages draw
their rolls from different generators, so what they share is "the same rolls,
the same fight", held by the vectors in `spec/vectors/combat/`.

When not to use it: a fight that should leave both sides wounded. Here the
loser always dies, which is what keeps the dataset free of near-copies.
"""

from __future__ import annotations

import json
import pathlib
import random
from collections.abc import Callable
from dataclasses import dataclass

#: The shared rules, one file for both languages.
RULES_PATH = pathlib.Path(__file__).resolve().parents[3] / "spec" / "combat" / "rules.json"
RULES = json.loads(RULES_PATH.read_text())

#: The damage die both sides roll, before any bonus.
WEAKEST_BLOW = RULES["die"]["lowest"]
HARDEST_BLOW = RULES["die"]["highest"]

#: What one unit of terrain cost above open ground is worth to the defender,
#: as damage it returns rather than damage it avoids. Cover that hits back is
#: easier to read off a board than cover that quietly scales a probability.
TERRAIN_WORTH = RULES["terrain_worth"]

#: What being outnumbered by one unit is worth, to whichever side has the
#: numbers.
NUMBERS_WORTH = RULES["numbers_worth"]

#: What being strong against the other side's type is worth, added to every
#: blow -- the counter table moving the dice rather than deciding the fight.
COUNTER_WORTH = RULES["counter_worth"]


@dataclass(frozen=True)
class Outcome:
    """Who won, and what each side had left. The loser has nothing left."""

    attacker_won: bool
    attacker_left: int
    defender_left: int


def fight(attacker_health: int, defender_health: int, numeric_advantage: int,
          defender_terrain: int, reinforcement_distance: int,
          roll: Callable[[], int], counter: int = 0,
          defender_hits_back: bool = True) -> Outcome:
    """Fight it out with the dice `roll` hands over, one call per blow.

    Rounds alternate, the attacker swinging first -- which is what starting the
    fight buys. `counter` is +1 when the attacker's type is strong against the
    defender's, -1 the other way round, 0 otherwise. A defender that cannot
    attack -- a workshop, a watchtower -- returns nothing.

    There is no round limit and no loop guard, because there is nothing to
    guard against: every attacker blow is at least `WEAKEST_BLOW`, which is
    one, and both healths are finite, so each round puts somebody strictly
    closer to zero. An earlier version stopped after six rounds and called the
    result a loss for the attacker, which read as "the attacker breaks off" and
    was really "we ran out of patience".
    """
    attacker_left = attacker_health
    defender_left = defender_health
    round_number = 1
    while True:
        defender_left -= _attacker_blow(numeric_advantage, reinforcement_distance,
                                        round_number, counter, roll)
        if defender_left <= 0:
            return Outcome(True, attacker_left, 0)
        if defender_hits_back:
            attacker_left -= _defender_blow(numeric_advantage, defender_terrain, counter, roll)
        if attacker_left <= 0:
            return Outcome(False, 0, defender_left)
        round_number += 1


def resolve(attacker_health: int, defender_health: int, numeric_advantage: int,
            defender_terrain: int, reinforcement_distance: int,
            rng: random.Random, counter: int = 0) -> bool:
    """Whether the attacker won, with this generator rolling the dice."""
    return fight(attacker_health, defender_health, numeric_advantage,
                 defender_terrain, reinforcement_distance,
                 lambda: rng.randint(WEAKEST_BLOW, HARDEST_BLOW), counter).attacker_won


def _attacker_blow(numeric_advantage: int, reinforcement_distance: int,
                   round_number: int, counter: int, roll: Callable[[], int]) -> int:
    """What the attacker gets through this round.

    The reinforcement is the part that makes `reinforcement_distance`
    informative at all: a friendly unit that was three cells away is swinging
    from round four. Nothing about the feature matters except this rule, which
    is why the rule is one line and is named.
    """
    blow = roll()
    if numeric_advantage > 0:
        blow += numeric_advantage * NUMBERS_WORTH
    if round_number > reinforcement_distance:
        blow += NUMBERS_WORTH
    if counter > 0:
        blow += COUNTER_WORTH
    return blow


def _defender_blow(numeric_advantage: int, defender_terrain: int, counter: int,
                   roll: Callable[[], int]) -> int:
    """What the defender returns this round, cover included."""
    blow = roll()
    if numeric_advantage < 0:
        blow += -numeric_advantage * NUMBERS_WORTH
    if counter < 0:
        blow += COUNTER_WORTH
    return blow + (defender_terrain - 1) * TERRAIN_WORTH
