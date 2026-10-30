"""Every cell a grid reaches from a start within a cost, and what it costs.

The tier-1 half of `godot/addons/ai_search/cost_flood.gd`, read the same
way: take the cheapest cell off the frontier, give each neighbour not seen
before its cost so far, and queue it only if that is within the limit. A
cell's cost is paid on entering it, so the start costs nothing; -1 is a wall.
"""

from __future__ import annotations

from gameaikit.techniques import technique

BLOCKED = -1

#: North, east, south, west: `GakGridGraph.DIRECTIONS`' order.
DIRECTIONS = ((0, -1), (1, 0), (0, 1), (-1, 0))


@technique("cost-flood", "Dijkstra to every cell within a cost: how far a sound travels")
def within(costs: list[list[int]], start: tuple[int, int], limit: int) -> dict[tuple[int, int], int]:
    """Every cell reached from `start` at a cost of `limit` or less: cell -> cost.

    `costs` is row-major, `costs[y][x]`. Empty when the start is off the board.
    """
    if not _on_board(costs, start) or limit < 0:
        return {}
    cost_so_far = {start: 0}
    frontier = [start]
    reached = {}
    while frontier:
        current = min(frontier, key=lambda cell: cost_so_far[cell])
        frontier.remove(current)
        reached[current] = cost_so_far[current]
        for step in _neighbours(costs, current):
            if step in cost_so_far:
                continue
            through_here = cost_so_far[current] + costs[step[1]][step[0]]
            if through_here <= limit:
                cost_so_far[step] = through_here
                frontier.append(step)
    return reached


def _on_board(costs: list[list[int]], cell: tuple[int, int]) -> bool:
    return 0 <= cell[1] < len(costs) and 0 <= cell[0] < len(costs[0])


def _neighbours(costs: list[list[int]], cell: tuple[int, int]) -> list[tuple[int, int]]:
    found = []
    for dx, dy in DIRECTIONS:
        step = (cell[0] + dx, cell[1] + dy)
        if _on_board(costs, step) and costs[step[1]][step[0]] != BLOCKED:
            found.append(step)
    return found
