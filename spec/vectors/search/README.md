# Conformance vectors: search

<!-- doc-meta
half_life: structure
verified_on: 2026-10-12
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the GridGraph cost convention changes, or a vector field is renamed
teaches: none
-->

> What a search on this kit must answer, written down once and checked from
> both languages.

These files exist so that the GDScript addon and the Python side of the kit can
be held to the **same** answers. A test written beside an implementation drifts
towards it; a vector sitting outside both does not.

Each file is one board and one question.

```json
{
  "name": "a short label for a reader; the file name is what failures quote",
  "why": "what this board is for -- the sentence a reader needs",
  "costs": [[1, 1, 1], [1, -1, 1]],
  "from": [0, 0],
  "to": [2, 1],
  "expect": {
    "reached": true,
    "cheapest_cost": 4,
    "fewest_steps": 3
  }
}
```

- `costs` is row-major: `costs[y][x]`, which is the board's own convention.
  `-1` is `GridGraph.BLOCKED`; every other value is what it costs to **enter**
  that cell, and is never below `1`.
- `from` and `to` are `[x, y]`.
- `expect.cheapest_cost` is what Dijkstra and A\* must both return.
  `expect.fewest_steps` is the length breadth-first must return, which is a
  different question and on some boards a different answer — that difference is
  the reason these two fields are separate.
- When `reached` is `false`, the cost and step fields are absent: there is no
  answer to pin.

**What a vector deliberately does not pin: the path itself.** Two routes can
cost the same, and which one an implementation returns depends on tie-breaking.
Pinning the cells would make a correct implementation fail for a reason that is
not about being correct, and the fix for that kind of failure is always to
weaken the test, which is how a conformance suite dies.

Run them with `make test-vectors`.
