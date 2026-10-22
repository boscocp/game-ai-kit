"""Write the flood vectors in this directory (`flood-*.json`).

Imports nothing from the repository, so the answers come from neither
implementation the vectors hold -- `CostFlood` in `ai_search` and
`gameaikit.search.flood` -- but from a third copy of the rule, here:
every cell reached from the start at a cost of `limit` or less, a cell's
cost paid on entering it, -1 a wall.

    python3 spec/vectors/search/derive_flood.py spec/vectors/search
"""
import json, pathlib, sys

STEPS = ((0, -1), (1, 0), (0, 1), (-1, 0))


def flood(costs, start, limit):
    best = {tuple(start): 0}
    waiting = [tuple(start)]
    while waiting:
        waiting.sort(key=lambda cell: (best[cell], cell[1], cell[0]))
        x, y = waiting.pop(0)
        for dx, dy in STEPS:
            nx, ny = x + dx, y + dy
            if not (0 <= ny < len(costs) and 0 <= nx < len(costs[0])) or costs[ny][nx] == -1:
                continue
            cost = best[(x, y)] + costs[ny][nx]
            if cost <= limit and cost < best.get((nx, ny), cost + 1):
                best[(nx, ny)] = cost
                waiting.append((nx, ny))
    return sorted([[x, y, c] for (x, y), c in best.items()], key=lambda e: (e[1], e[0]))


def vector(name, why, costs, start, limit):
    return {"name": name, "why": why, "kind": "flood", "costs": costs, "from": start, "limit": limit,
            "expect": {"reached": flood(costs, start, limit)}}


def vectors():
    wall = [[1, -1, 1], [1, -1, 1], [1, 1, 1]]
    return [
        vector("flood-goes-round-a-wall",
               "A sound round a wall: the cell beside the source on the far side is six away, not two.",
               wall, [0, 0], 10),
        vector("flood-stops-at-its-limit",
               "The same wall with a limit of four: the far side is past it and is not reached at all.",
               wall, [0, 0], 4),
        vector("flood-pays-for-rough-ground",
               "A cell that costs three to enter: the way through it and the way round cost the same.",
               [[1, 3, 1], [1, 1, 1]], [0, 0], 5),
        vector("flood-shut-in",
               "Walls on every side: only the start is reached, at no cost.",
               [[-1, -1, -1], [-1, 1, -1], [-1, -1, -1]], [1, 1], 9),
    ]


if __name__ == "__main__":
    folder = pathlib.Path(sys.argv[1])
    for each in vectors():
        (folder / f"{each['name']}.json").write_text(json.dumps(each, indent=1) + "\n")
