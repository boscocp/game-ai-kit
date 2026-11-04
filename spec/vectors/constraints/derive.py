"""Write the constraint vectors in this directory.

Imports nothing from the repository, so the assignments and the counts come
from neither implementation the vectors hold. It follows the README's rules
in its own shape -- domains passed down the recursion as copies, not saved
and restored -- so a mistake shared by the two twins is not shared by it:

    python3 spec/vectors/constraints/derive.py spec/vectors/constraints
"""
import json
import sys
from collections import deque


def xorshift(seed):
    state = seed & 0xFFFFFFFF or 1
    while True:
        state ^= (state << 13) & 0xFFFFFFFF
        state ^= state >> 17
        state ^= (state << 5) & 0xFFFFFFFF
        yield state


def shuffled(items, draws):
    items = list(items)
    for place in range(len(items) - 1, 0, -1):
        other = next(draws) % (place + 1)
        items[place], items[other] = items[other], items[place]
    return items


def relation(entry):
    kind = entry["relation"]
    if kind == "different":
        return lambda a, b: a != b
    if kind == "less":
        return lambda a, b: a < b
    if kind == "queens":
        return lambda a, b: a != b and abs(a - b) != entry["apart"]
    raise ValueError(kind)


def global_test(entry):
    names, kind = entry["over"], entry["relation"]
    if kind == "sum-at-most":
        return lambda done: sum(done[n] for n in names if n in done) <= entry["limit"]
    if kind == "some-equals":
        return lambda done: any(n not in done for n in names) or any(done[n] == entry["value"] for n in names)
    raise ValueError(kind)


def solve(vector):
    names = [v["name"] for v in vector["variables"]]
    arcs = []  # (constraint, target, other, test(target_value, other_value))
    for index, entry in enumerate(vector["binary"]):
        first, second = entry["between"]
        test = relation(entry)
        arcs.append((index, first, second, lambda x, y, t=test: t(x, y)))
        arcs.append((index, second, first, lambda x, y, t=test: t(y, x)))
    tests = [(set(g["over"]), global_test(g)) for g in vector["global"]]
    draws = xorshift(vector["seed"])
    order = shuffled(names, draws)
    domains = {v["name"]: shuffled(v["values"], draws) for v in vector["variables"]}
    count = {"assignments": 0, "backtracks": 0, "pruned": 0, "assigned": []}

    def into(target):
        return [a for a in arcs if a[1] == target]

    def ac3(domains, queue):
        queue = deque(queue)
        while queue:
            arc = queue.popleft()
            index, target, other, test = arc
            kept = [x for x in domains[target] if any(test(x, y) for y in domains[other])]
            if len(kept) == len(domains[target]):
                continue
            count["pruned"] += len(domains[target]) - len(kept)
            domains[target] = kept
            if not kept:
                return False
            for back in arcs:
                if back[2] == target and back[0] != index and back not in queue:
                    queue.append(back)
        return True

    def search(domains, done):
        if len(done) == len(names):
            return dict(done)
        free = [n for n in order if n not in done]
        if vector["mrv"]:
            degree = {n: sum(1 for a in arcs if a[1] == n and a[2] not in done) for n in free}
            name = min(free, key=lambda n: (len(domains[n]), -degree[n]))
        else:
            name = free[0]
        values = list(domains[name])
        if vector["lcv"]:
            def cost(x):
                return sum(1 for a in arcs if a[1] == name and a[2] not in done
                           for y in domains[a[2]] if not a[3](x, y))
            values = [x for _, _, x in sorted((cost(x), place, x) for place, x in enumerate(values))]
        for x in values:
            if any(a[2] in done and not a[3](x, done[a[2]]) for a in arcs if a[1] == name):
                continue
            trial = dict(done, **{name: x})
            if any(name in over and not test(trial) for over, test in tests):
                continue
            count["assignments"] += 1
            count["assigned"].append([name, x])
            copy = {n: list(d) for n, d in domains.items()}
            copy[name] = [x]
            queue = [(a[0], a[2], a[1], None) for a in arcs if a[1] == name and a[2] not in done]
            queue = [next(b for b in arcs if b[0] == q[0] and b[1] == q[1]) for q in queue]
            if not vector["propagate"] or ac3(copy, queue):
                found = search(copy, trial)
                if found is not None:
                    return found
        count["backtracks"] += 1
        return None

    found = None
    if not vector["propagate"] or ac3(domains, list(arcs)):
        found = search(domains, {})
    solution = None if found is None else {n: found[n] for n in names}
    return solution, count


def australia(colours):
    borders = [["WA", "NT"], ["WA", "SA"], ["NT", "SA"], ["NT", "Q"], ["SA", "Q"], ["SA", "NSW"], ["SA", "V"],
               ["Q", "NSW"], ["NSW", "V"]]
    return {"variables": [{"name": n, "values": colours} for n in ["WA", "NT", "SA", "Q", "NSW", "V", "T"]],
            "binary": [{"between": b, "relation": "different"} for b in borders], "global": []}


def queens(count):
    return {"variables": [{"name": f"Q{c}", "values": list(range(count))} for c in range(count)],
            "binary": [{"between": [f"Q{c}", f"Q{o}"], "relation": "queens", "apart": o - c}
                       for c in range(count) for o in range(c + 1, count)], "global": []}


def sudoku_four():
    rows = ["1...", "..2.", ".3..", "...4"]
    cells = [(r, c) for r in range(4) for c in range(4)]
    variables = [{"name": f"r{r}c{c}", "values": [int(rows[r][c])] if rows[r][c] != "." else [1, 2, 3, 4]}
                 for r, c in cells]
    binary = [{"between": [f"r{r}c{c}", f"r{s}c{d}"], "relation": "different"}
              for i, (r, c) in enumerate(cells) for (s, d) in cells[i + 1:]
              if r == s or c == d or (r // 2, c // 2) == (s // 2, d // 2)]
    return {"variables": variables, "binary": binary, "global": []}


def late_global():
    names = ["a", "b", "c"]
    return {"variables": [{"name": n, "values": [0, 1, 2, 3]} for n in names],
            "binary": [{"between": ["a", "b"], "relation": "different"},
                       {"between": ["b", "c"], "relation": "different"},
                       {"between": ["a", "c"], "relation": "less"}],
            "global": [{"over": names, "relation": "sum-at-most", "limit": 4},
                       {"over": names, "relation": "some-equals", "value": 3}]}


def triangle():
    return {"variables": [{"name": n, "values": ["red", "green"]} for n in ["A", "B", "C"]],
            "binary": [{"between": p, "relation": "different"} for p in [["A", "B"], ["B", "C"], ["A", "C"]]],
            "global": []}


VECTORS = {
    "australia-in-three-colours": ("AIMA 6.1.1's map, MRV, LCV and AC-3", australia(["red", "green", "blue"]),
                                   1, True, True, True),
    "australia-another-seed": ("the same map, another seed: the ties go another way",
                               australia(["red", "green", "blue"]), 9, True, True, True),
    "australia-in-order-alone": ("the same map with no heuristic and no inference: the seeded order only",
                                 australia(["red", "green", "blue"]), 1, False, False, False),
    "six-queens-plain-backtracking": ("six queens, no heuristic, no inference: it goes back often",
                                      queens(6), 3, False, False, False),
    "six-queens-maintaining-arc-consistency": ("six queens with MRV, LCV and AC-3", queens(6), 3, True, True, True),
    "four-by-four-sudoku": ("a 4x4 Sudoku, givens as one-value domains", sudoku_four(), 1, True, True, True),
    "a-triangle-in-two-colours-has-none": ("no answer, found by searching: AC-3 alone cannot see it",
                                           triangle(), 1, True, True, True),
    "a-global-checked-late": ("two global constraints, one checkable only when all three are assigned",
                              late_global(), 5, True, True, True),
    "least-constraining-first": ("LCV alone: each queen on the row that attacks fewest free squares",
                                 queens(6), 3, False, True, False),
}


def main(directory):
    for stem, (description, problem, seed, mrv, lcv, propagate) in VECTORS.items():
        vector = dict(problem, description=description, seed=seed, mrv=mrv, lcv=lcv, propagate=propagate)
        solution, count = solve(vector)
        vector.update(solution=solution, assigned=count["assigned"], assignments=count["assignments"],
                      backtracks=count["backtracks"], pruned=count["pruned"])
        with open(f"{directory}/{stem}.json", "w", encoding="utf-8") as out:
            json.dump(vector, out, indent=1)
            out.write("\n")


if __name__ == "__main__":
    main(sys.argv[1])
