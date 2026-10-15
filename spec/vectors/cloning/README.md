# Conformance vectors: cloning

<!-- doc-meta
half_life: structure
verified_on: 2026-10-15
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the softmax, the way a column or a case key is written, or the nearest-case distance changes
teaches: none
-->

> One cloned player, two languages, and the file that says they agreed.

`ai_learning`'s `SoftmaxModel` and `CaseTable` (GDScript) and
`gameaikit.cloning` (Python) read a recorded player the same way. Python
needs its copy to score held-out rows; the game needs its own to play. The
vectors hold both to the same numbers: `make test-cloning-vectors` on the
GDScript side, `make test-python` on the Python side.

- **softmax** -- a situation is words; each `feature=word` with a column adds
  that column's weight to every answer's bias; a word without one adds
  nothing; the scores go through the softmax.
- **ghost** -- a case's key is the situation's words joined by ` | `, in
  feature order. Exact lookup finds that key or nothing. Nearest counts the
  features whose words differ and pools the counts of every case at the
  smallest count.

## Where the numbers came from

From neither implementation: `derive.py`, which imports nothing from this
repository, wrote them. `softmax-by-hand` can be checked by hand: for
`{"distance": "close", "last": "high"}` the scores are high 0 + 0 - 0.5
= -0.5, low 0 + 0.5 + 1 = 1.5, throw -0.25 + 2 + 0 = 1.75, so throw is
likeliest. The empty situation leaves the biases alone: high and low tie at
0, and a tie goes to the first in `classes`, high.
