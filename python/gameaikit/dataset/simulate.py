"""Play games with the fixed policy, and write down what happened.

One row per fight and one row per captured node, which are the two questions
T5 asks a model: *will this attack work* and *how long will this take*.

The rows come out of played games rather than out of a loop over feature
values, and the difference matters. In a game the features arrive correlated --
a unit standing in cover near the node is usually the one with friends nearby
-- and a model fitted to independently drawn features would be fitted to a
world nobody plays.

Everything takes an explicit `random.Random`, and nothing here touches the
module-level `random`. A dataset you cannot reproduce exactly is a dataset you
cannot debug, and the seed is the only thing standing between the two.
"""

from __future__ import annotations

import random

from . import combat
from .board import CHEAPEST_GROUND, DEAREST_GROUND, Board, Unit, distance
from .policy import adjacent_enemy, walk
from .rows import Capture, Combat

WIDTH = 15
HEIGHT = 11

#: Units per side. Enough that a unit can have friends nearby, few enough that
#: a game is over in a readable number of turns.
FEWEST_UNITS = 2
MOST_UNITS = 4

WEAKEST_UNIT = 8
STRONGEST_UNIT = 18

#: Turns a faction must hold the node alone before it counts as captured.
HOLD_NEEDED = 3

#: The bound on the turn loop. It is not a game rule and it has never been
#: reached: measured over 2000 games the longest capture took 10 turns, and no
#: game at all ended by running out of turns -- they end by capture or by one
#: side being destroyed. It stays because the loop needs a bound; it is not the
#: reason any capture row is missing. See the censoring note in `rows.Capture`.
TURN_LIMIT = 40

#: How far "nearby" is, when counting who is close enough to matter to a fight.
#: A rule of the fight, so it is read from the rules file the game reads.
NEARBY = combat.RULES["nearby_radius"]


def collect(games: int, seed: int) -> tuple[list[Combat], list[Capture]]:
    """Play `games` games from one seed, and return every row they produced."""
    rng = random.Random(seed)
    combats: list[Combat] = []
    captures: list[Capture] = []
    for game in range(games):
        board = _random_board(rng)
        capture = _play(board, game, combats, rng)
        if capture is not None:
            captures.append(capture)
    return combats, captures


def _play(board: Board, game: int, combats: list[Combat],
          rng: random.Random) -> Capture | None:
    """One game, to a capture, a wipe-out or the turn limit."""
    opening = {faction: opening_features(board, faction) for faction in (0, 1)}
    held = {0: 0, 1: 0}

    for turn in range(1, TURN_LIMIT + 1):
        for faction in (0, 1):
            _take_faction_turn(board, faction, game, combats, rng)
            if not board.living(1 - faction):
                return None
        holder = _who_holds_the_node(board)
        _count_the_hold(held, holder)
        if holder is not None and held[holder] >= HOLD_NEEDED:
            return _capture_row(opening[holder], turn, game)
    return None


def _take_faction_turn(board: Board, faction: int, game: int,
                       combats: list[Combat], rng: random.Random) -> None:
    """Every living unit of a faction moves, then fights if it can."""
    # No "is it still alive" guard, and that is measured rather than assumed.
    # Within one faction's turn the only unit that can die is the one acting --
    # a fight kills either the attacker or a defender of the *other* side -- so
    # a unit in this snapshot is always still alive by the time it is reached.
    # The guard that used to be here fired 0 times in 500 games, and deleting
    # it changed not one row.
    for unit in sorted(board.living(faction), key=lambda one: one.unit_id):
        if adjacent_enemy(board, unit) is None:
            walk(board, unit, board.node)
        enemy = adjacent_enemy(board, unit)
        if enemy is not None:
            _fight(board, unit, enemy, game, combats, rng)


def _fight(board: Board, attacker: Unit, defender: Unit, game: int,
           combats: list[Combat], rng: random.Random) -> None:
    """Resolve one fight and write down the row it produced.

    The loser dies. Wounding the loser instead would mean the same two units
    fight again next turn from a slightly different place, which fills the
    dataset with rows that are nearly copies of each other -- and a holdout
    split cannot tell a near-copy from an unseen situation.
    """
    seen = fight_features(board, attacker, defender)
    outcome = combat.fight(
        attacker.health, defender.health, seen["numeric_advantage"],
        seen["defender_terrain"], seen["reinforcement_distance"],
        lambda: rng.randint(combat.WEAKEST_BLOW, combat.HARDEST_BLOW),
    )
    won = outcome.attacker_won
    # Written out field by field rather than splatted in. `Combat(**seen)` was
    # the one place where renaming a feature would have been accepted in
    # silence, in a file whose whole output is those names.
    combats.append(Combat(
        health_difference=seen["health_difference"],
        numeric_advantage=seen["numeric_advantage"],
        defender_terrain=seen["defender_terrain"],
        reinforcement_distance=seen["reinforcement_distance"],
        attacker_won=won,
        game=game,
    ))
    # The winner keeps what it has left, as it does on the tactical board
    # (T26): ADR 0008 says the dataset is the game's fights, not a kinder
    # version where the winner walks away untouched.
    attacker.health = outcome.attacker_left
    defender.health = outcome.defender_left


def fight_features(board: Board, attacker: Unit, defender: Unit) -> dict[str, int]:
    """The four numbers a model gets to see about a fight, before it happens.

    Public, and named, because this is where the dataset is actually made. It
    was private and no test built a board and looked at a row, so a review
    could flip the sign of `numeric_advantage`, read `defender_terrain` from
    the attacker's cell, or measure the reinforcement from the wrong unit, and
    the whole suite stayed green while the data changed underneath it.
    """
    return {
        "health_difference": attacker.health - defender.health,
        "numeric_advantage": (
            _friends_near(board, attacker, defender.cell())
            - _friends_near(board, defender, attacker.cell())
        ),
        "defender_terrain": board.cost_at(defender.cell()),
        "reinforcement_distance": _nearest_friend(board, attacker),
    }


def _friends_near(board: Board, unit: Unit, cell: tuple[int, int]) -> int:
    """How many of this unit's other units are within `NEARBY` of a cell."""
    return sum(
        1 for other in board.living(unit.faction)
        if other is not unit and distance(other.cell(), cell) <= NEARBY
    )


def _nearest_friend(board: Board, unit: Unit) -> int:
    """How far this unit's closest other unit is, or the board's width when
    it is the last one standing -- a number no reinforcement can arrive from."""
    distances = [
        distance(unit.cell(), other.cell())
        for other in board.living(unit.faction) if other is not unit
    ]
    return min(distances) if distances else WIDTH


def _who_holds_the_node(board: Board) -> int | None:
    """The faction standing alone on the node, or None."""
    standing = board.unit_at(board.node)
    return standing.faction if standing is not None else None


def _count_the_hold(held: dict[int, int], holder: int | None) -> None:
    """Advance the holder's count and reset everyone else's."""
    for faction in held:
        held[faction] = held[faction] + 1 if faction == holder else 0


def opening_features(board: Board, faction: int) -> dict[str, float]:
    """What a faction's position looked like before anybody moved.

    Public for the same reason as `fight_features`: it is half of the second
    dataset, and nothing used to pin which side of the game it described.
    """
    own = board.living(faction)
    nearest = min(own, key=lambda unit: distance(unit.cell(), board.node))
    return {
        "distance_to_node": distance(nearest.cell(), board.node),
        "own_units": len(own),
        "enemy_units": len(board.living(1 - faction)),
        "terrain_on_the_way": _terrain_between(board, nearest.cell(), board.node),
    }


def _capture_row(opening: dict[str, float], turn: int, game: int) -> Capture:
    """The opening position of whoever took the node, and when they took it.

    The *capturing* faction's opening position. Handing it the other side's was
    green across the whole suite until a test pinned it, and the rows it
    produced looked perfectly reasonable.
    """
    return Capture(
        distance_to_node=int(opening["distance_to_node"]),
        own_units=int(opening["own_units"]),
        enemy_units=int(opening["enemy_units"]),
        terrain_on_the_way=opening["terrain_on_the_way"],
        turns_taken=turn,
        game=game,
    )


def _terrain_between(board: Board, start: tuple[int, int],
                     target: tuple[int, int]) -> float:
    """Mean terrain cost along one Manhattan path from `start` to `target`.

    Along the x axis and then along the y axis: one path, not the cheapest.
    This is a summary of the ground in between, and working out the cheapest
    route here would quietly put a pathfinder inside a feature -- which makes a
    model look clever and a dataset impossible to rebuild from its description.
    """
    x, y = start
    costs = []
    while x != target[0]:
        x += _toward(x, target[0])
        costs.append(board.cost_at((x, y)))
    while y != target[1]:
        y += _toward(y, target[1])
        costs.append(board.cost_at((x, y)))
    return sum(costs) / len(costs) if costs else float(CHEAPEST_GROUND)


def _toward(here: int, there: int) -> int:
    """One step along an axis, as -1 or 1."""
    return 1 if there > here else -1


def _random_board(rng: random.Random) -> Board:
    """A board, two sides on opposite edges, and a node in the middle."""
    costs = [
        [rng.randint(CHEAPEST_GROUND, DEAREST_GROUND) for _ in range(WIDTH)]
        for _ in range(HEIGHT)
    ]
    node = (WIDTH // 2, HEIGHT // 2)
    units: list[Unit] = []
    for faction in (0, 1):
        for cell in _starting_cells(rng, faction, node):
            units.append(Unit(
                unit_id=len(units), faction=faction, x=cell[0], y=cell[1],
                health=rng.randint(WEAKEST_UNIT, STRONGEST_UNIT),
            ))
    return Board(WIDTH, HEIGHT, costs, units, node)


def _starting_cells(rng: random.Random, faction: int,
                    node: tuple[int, int]) -> list[tuple[int, int]]:
    """Where one side starts: anywhere on its own half, off the node itself.

    Anywhere, rather than on the edge column. Lining both sides up on the edges
    made every game the same length -- the node was always five to eight cells
    away and so was always taken on turn six or seven, and a regression fitted
    to turns had almost nothing to be right or wrong about.
    """
    half = range(0, node[0]) if faction == 0 else range(node[0] + 1, WIDTH)
    cells = [(x, y) for x in half for y in range(HEIGHT)]
    return rng.sample(cells, rng.randint(FEWEST_UNITS, MOST_UNITS))
