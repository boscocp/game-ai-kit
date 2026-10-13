"""What one row of the dataset is, in each of the two shapes.

Two models are fitted in T5 and they are asked different questions, so they
need different rows: a combat is a yes-or-no about one fight, and a capture is
a number of turns. Both live here rather than beside their models, because the
simulator writes them and the training reads them, and a field renamed in one
place and not the other is the kind of defect that shows up as a weight.

The order of `FEATURES` is the order of the weight vector, and that order is
what `weights.json` publishes for the GDScript side to read back in T6. It is
written down once, here.
"""

from __future__ import annotations

import dataclasses

#: The combat features, in weight order.
COMBAT_FEATURES = (
    "health_difference",
    "numeric_advantage",
    "defender_terrain",
    "reinforcement_distance",
)

#: The capture features, in weight order.
CAPTURE_FEATURES = (
    "distance_to_node",
    "own_units",
    "enemy_units",
    "terrain_on_the_way",
)


@dataclasses.dataclass(frozen=True)
class Combat:
    """One fight, and whether the side that started it won.

    `reinforcement_distance` is how far the attacker's nearest other unit was
    when the fight began. It matters because a fight here lasts several rounds
    and that unit can arrive partway through -- a feature that is informative
    only because of a rule somebody chose, which is worth knowing before
    reading anything into its weight.
    """

    health_difference: int
    numeric_advantage: int
    defender_terrain: int
    reinforcement_distance: int
    attacker_won: bool

    #: Which game this fight happened in. Not a feature -- it is what lets the
    #: holdout be split by game rather than by row. Several fights from one
    #: game share a board, a set of units and a run of dice, so a split that
    #: put some of them in training and the rest in the holdout would be
    #: scoring the model on situations it had already half seen.
    game: int

    def features(self) -> list[float]:
        """The row as the numbers the model sees, in `COMBAT_FEATURES` order."""
        return [float(getattr(self, name)) for name in COMBAT_FEATURES]


@dataclasses.dataclass(frozen=True)
class Capture:
    """One node taken, and how many turns it took from the start of the game.

    Only games where the node *was* captured produce one of these, which makes
    this dataset censored: the slowest captures are the ones that never
    finished inside the turn limit and so are not here. The number a model fits
    to it is therefore a little optimistic, and that is a property of the data
    rather than of the fitting -- see the note in `training/report.py`.
    """

    distance_to_node: int
    own_units: int
    enemy_units: int
    terrain_on_the_way: float
    turns_taken: int

    #: Which game this was. One row per game here, so it matters less than it
    #: does for a fight -- it is carried so both datasets split the same way.
    game: int

    def features(self) -> list[float]:
        """The row as the numbers the model sees, in `CAPTURE_FEATURES` order."""
        return [float(getattr(self, name)) for name in CAPTURE_FEATURES]
