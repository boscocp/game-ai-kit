"""How a fight is decided, which is the thing the model has to learn.

This is written as a little simulation rather than as a formula, and that is
the whole point of the exercise. If the chance of winning were a logistic
function of the features, a logistic regression would recover the coefficients
exactly and the lesson would be circular -- the model would have "learned" the
line somebody wrote three files away.

So a fight here is rounds of dice: two sides trade damage, terrain reduces what
the attacker gets through, a numeric advantage adds to it, and a unit that was
a few cells away can arrive partway through. The relationship between the
features and the outcome is real, noisy and **not** the shape of the model that
will be fitted to it. What the weights then say is an approximation somebody
can be wrong about, which is the only kind worth printing.

When not to use it: as the game's combat. The game has none yet; T10 brings
one, and it will be in GDScript where the player can watch it.
"""

from __future__ import annotations

import random

#: The damage die both sides roll, before any bonus.
WEAKEST_BLOW = 1
HARDEST_BLOW = 4

#: What one unit of terrain cost above open ground is worth to the defender,
#: as damage it returns rather than damage it avoids. Cover that hits back is
#: easier to read off a board than cover that quietly scales a probability.
TERRAIN_WORTH = 1

#: What being outnumbered by one unit is worth, to whichever side has the
#: numbers.
NUMBERS_WORTH = 1


def resolve(attacker_health: int, defender_health: int, numeric_advantage: int,
            defender_terrain: int, reinforcement_distance: int,
            rng: random.Random) -> bool:
    """Fight it out, and answer whether the attacker won.

    Rounds alternate, the attacker swinging first -- which is what starting the
    fight buys.

    There is no round limit and no loop guard, because there is nothing to
    guard against: every blow is at least `WEAKEST_BLOW`, which is one, and
    both healths are finite, so each round puts somebody strictly closer to
    zero. An earlier version stopped after six rounds and called the result a
    loss for the attacker, which read as "the attacker breaks off" and was
    really "we ran out of patience" -- a rule in the data that nothing in the
    game would have matched.
    """
    attacker_left = attacker_health
    defender_left = defender_health
    round_number = 1

    while True:
        defender_left -= _attacker_blow(numeric_advantage, reinforcement_distance,
                                        round_number, rng)
        if defender_left <= 0:
            return True
        attacker_left -= _defender_blow(numeric_advantage, defender_terrain, rng)
        if attacker_left <= 0:
            return False
        round_number += 1


def _attacker_blow(numeric_advantage: int, reinforcement_distance: int,
                   round_number: int, rng: random.Random) -> int:
    """What the attacker gets through this round.

    The reinforcement is the part that makes `reinforcement_distance`
    informative at all: a friendly unit that was three cells away is swinging
    from round four. Nothing about the feature matters except this rule, which
    is why the rule is one line and is named.
    """
    blow = rng.randint(WEAKEST_BLOW, HARDEST_BLOW)
    if numeric_advantage > 0:
        blow += numeric_advantage * NUMBERS_WORTH
    if round_number > reinforcement_distance:
        blow += NUMBERS_WORTH
    return blow


def _defender_blow(numeric_advantage: int, defender_terrain: int,
                   rng: random.Random) -> int:
    """What the defender returns this round, cover included."""
    blow = rng.randint(WEAKEST_BLOW, HARDEST_BLOW)
    if numeric_advantage < 0:
        blow += -numeric_advantage * NUMBERS_WORTH
    return blow + (defender_terrain - 1) * TERRAIN_WORTH
