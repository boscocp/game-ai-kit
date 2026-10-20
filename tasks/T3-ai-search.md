# T3 — `ai_search`: four ways to cross the board

Size: M · Prereqs: T2 · Files: `godot/addons/ai_search/`, `godot/demos/search/`

## Goal

A\*, Dijkstra, breadth-first and depth-first over `GridGraph`, each written to
be read beside the pseudocode in the book, and a demo that draws which nodes
each one expanded. The point of the demo is the difference between them, which
is invisible in a finished path and obvious in the expansion.

## Steps

1. One file per algorithm, each opening with a header saying what it solves,
   its complexity, and when not to use it — which for all four is "when you
   need throughput, use `AStarGrid2D`, which is engine core in C++".
2. A shared `SearchResult`: the path, the nodes expanded, the frontier at the
   end. The second field exists for the demo and for the test below.
3. Conformance vectors in `spec/vectors/search/` — optimal path, a maze with no
   solution, a map where terrain cost changes the answer.

## Acceptance

```bash
make test-godot
make test-vectors
python3 scripts/check_readability.py
```

The property an A\* must have, asserted rather than inspected: with an
admissible heuristic it expands no more nodes than Dijkstra and returns a path
of the same cost.

```bash
./scripts/godot --headless --path godot -s res://test/ai_search/search_properties.gd
```

## Manual check

Open the demo and step through the four algorithms on the same map. Depth-first
should look obviously wrong, and it should be obvious *why* from the drawing.
