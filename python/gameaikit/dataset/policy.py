"""The one policy both sides play: walk to the node, hit whatever is in reach.

It is fixed, and it is fixed on purpose. The dataset has to describe a
population of situations, and a policy that learned as it went would change the
population underneath the data -- the rows from the first hundred games would
be about a different player than the rows from the last hundred.

It is also deliberately not clever. A policy that always picked the fight it
would win would produce a dataset in which the attacker nearly always wins, and
a model fitted to it would have nothing to separate.

When not to use it: as the game's AI. This is the thing the learned policy in
T6 is supposed to beat.
"""

from __future__ import annotations

from .board import Board, Unit, distance

#: What a unit may spend walking in one turn. Terrain costs come out of this,
#: so three cells of open ground and one of rough ground cost the same.
MOVEMENT_PER_TURN = 3


def adjacent_enemy(board: Board, unit: Unit) -> Unit | None:
    """The first enemy standing next to this unit, or None.

    "First" is in `DIRECTIONS` order, which is fixed, so two runs of the same
    seed pick the same fight.
    """
    for cell in board.neighbours(unit.cell()):
        other = board.unit_at(cell)
        if other is not None and other.faction != unit.faction:
            return other
    return None


def step_toward(board: Board, unit: Unit, target: tuple[int, int]) -> tuple[int, int] | None:
    """The neighbouring cell that gets closest to `target`, or None.

    None means every way forward is occupied or none gets any closer -- a unit
    in that position stays where it is, which is a decision and not a failure.
    """
    best: tuple[int, int] | None = None
    best_distance = distance(unit.cell(), target)
    for cell in board.neighbours(unit.cell()):
        if board.unit_at(cell) is not None:
            continue
        if distance(cell, target) < best_distance:
            best = cell
            best_distance = distance(cell, target)
    return best


def walk(board: Board, unit: Unit, target: tuple[int, int]) -> None:
    """Spend this unit's movement walking towards `target`.

    It stops early for the two reasons a unit ever stops: it cannot afford the
    next cell, or there is nowhere better to stand.
    """
    movement_left = MOVEMENT_PER_TURN
    while True:
        step = step_toward(board, unit, target)
        if step is None or board.cost_at(step) > movement_left:
            return
        movement_left -= board.cost_at(step)
        unit.x, unit.y = step
