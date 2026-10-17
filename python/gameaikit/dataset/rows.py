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

    Two measured things to know before reading these numbers:

    * **a fifth of the rows carry a sentinel, not a distance.** A unit with no
      living friends reports `Board.width`, which is 15 where real distances
      run 1 to 11. That is a category wearing a number: 19.6% of rows, and
      attackers in them win 13.9% of the time against 36.9% for the rest. A
      linear model reads 15 as "very far", which points the right way by luck.
      Capping it at the real maximum instead scores 0.885 against 0.878, a
      difference of five rows in seven hundred -- not enough to choose on, and
      enough to say out loud;
    * **`numeric_advantage` is one-sided.** It is positive on 8.4% of rows and
      reaches +2 on eleven of nearly three thousand, because the fixed policy
      attacks whatever it touches rather than waiting for the numbers. Its
      weight is almost entirely an estimate about being *out*numbered.
    """

    health_difference: int
    numeric_advantage: int
    defender_terrain: int
    reinforcement_distance: int
    attacker_won: bool

    #: Which game this fight happened in. Not a feature -- it is what lets the
    #: holdout be split by game rather than by row. Several fights from one
    #: game share a board, a set of units and a run of dice, so a row split
    #: would score the model partly on boards it had been fitted on.
    #:
    #: **It does not make the holdout unseen, and this comment used to imply
    #: that it did.** The four features are small integers, so the whole
    #: feature space is small: since T26, 3807 rows cover only 1083 distinct
    #: vectors, and 84% of holdout rows have an *exact* feature twin in the
    #: training set. Voting that twin's label scores 0.7878 over the whole
    #: holdout once the rest are answered with the commoner outcome -- against
    #: 0.8585 for the model and 0.5681 for the majority class. (Over the
    #: twinned rows alone it scored 0.848 before T26; not measured since.) The
    #: whole-holdout figure is what `report.py` publishes, because it is the
    #: one measured on the same rows as the model. A four-weight model has no
    #: room to memorise 1083 answers, so the score here is honest; a model with capacity, as in T18, would be
    #: measured by this holdout as cleverer than it is.
    game: int

    def features(self) -> list[float]:
        """The row as the numbers the model sees, in `COMBAT_FEATURES` order."""
        return [float(getattr(self, name)) for name in COMBAT_FEATURES]


@dataclasses.dataclass(frozen=True)
class Capture:
    """One node taken, and how many turns it took from the start of the game.

    Only games where the node *was* captured produce one of these, so this
    dataset is censored -- but **not in the way this comment used to claim**.
    It said the missing games were the slowest, still unfinished at the turn
    limit. Measured over 2000 games: 1392 captures, 608 wipe-outs and **zero**
    games reaching the limit, with the longest capture taking 10 turns of a
    permitted 40.

    So the missing rows are the games where one side was destroyed before
    anybody held the node, and that is a worse bias than the one that was
    documented: a wipe-out is far likelier when the sides are uneven, so the
    model never sees the games that were lopsided, and `own_units` and
    `enemy_units` are exactly the features that describe being lopsided.
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
