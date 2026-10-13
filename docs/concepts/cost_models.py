#!/usr/bin/env python3
"""Does Dijkstra ever improve a cell it has already seen? It depends on the board.

The measurement behind the table in `search.md`. A Dijkstra with a binary heap
keyed at insertion -- the textbook upgrade over the kit's linear scan -- run on
random boards under two rules for what a step costs:

  * the kit's rule, where a cost belongs to the cell **entered**, so every
    route into a cell pays the same last step;
  * a cost per **edge**, depending on where the step comes from as well.

It counts how often a cell already seen gets a cheaper offer, and how often a
stale copy comes off the heap. Under the first rule both are zero, and the
argument in `search.md` says why; under the second they are not.

This is a model in Python, not the GDScript addon: it measures the claim about
cost rules, and the addon's own counters are in its tests.

    python3 docs/concepts/cost_models.py
"""

from __future__ import annotations

import heapq
import random

BOARDS = 300
SEED = 7
BLOCKED = -1


def neighbours(cell: tuple[int, int], width: int, height: int) -> list[tuple[int, int]]:
    """The four cardinal cells that are on the board."""
    column, row = cell
    candidates = [(column + 1, row), (column - 1, row), (column, row + 1), (column, row - 1)]
    return [(x, y) for x, y in candidates if 0 <= x < width and 0 <= y < height]


def dijkstra(board: dict, width: int, height: int, step_cost) -> tuple[int, int]:
    """Improvements and stale pops, searching corner to corner with a heap."""
    start, goal = (0, 0), (width - 1, height - 1)
    g = {start: 0}
    heap = [(0, start)]
    finished = set()
    improvements = stale = 0
    while heap:
        _, current = heapq.heappop(heap)
        if current in finished:
            stale += 1
            continue
        finished.add(current)
        if current == goal:
            break
        for step in neighbours(current, width, height):
            if board[step] == BLOCKED:
                continue
            through_here = g[current] + step_cost(current, step)
            if step in g and through_here < g[step]:
                improvements += 1
            if step not in g or through_here < g[step]:
                g[step] = through_here
                heapq.heappush(heap, (through_here, step))
    return improvements, stale


def random_board(rng: random.Random) -> tuple[dict, dict, int, int]:
    """Cell costs from 1 to 5 with some walls, and an independent cost per edge."""
    width, height = rng.randint(4, 12), rng.randint(4, 12)
    board = {(x, y): BLOCKED if rng.random() < 0.15 else rng.randint(1, 5)
             for x in range(width) for y in range(height)}
    board[(0, 0)] = board[(width - 1, height - 1)] = 1
    edges = {(cell, step): rng.randint(1, 5)
             for cell in board for step in neighbours(cell, width, height)}
    return board, edges, width, height


def main() -> None:
    """Both cost rules over the same boards, so the only difference is the rule."""
    rng = random.Random(SEED)
    per_cell = [0, 0]
    per_edge = [0, 0]
    for _ in range(BOARDS):
        board, edges, width, height = random_board(rng)
        for totals, step_cost in (
            (per_cell, lambda _came_from, step: board[step]),
            (per_edge, lambda came_from, step: edges[(came_from, step)]),
        ):
            improvements, stale = dijkstra(board, width, height, step_cost)
            totals[0] += improvements
            totals[1] += stale
    print(f"{BOARDS} boards, seed {SEED}")
    print(f"cost of the cell entered: {per_cell[0]} improvements, {per_cell[1]} stale pops")
    print(f"cost of the edge:         {per_edge[0]} improvements, {per_edge[1]} stale pops")


if __name__ == "__main__":
    main()
