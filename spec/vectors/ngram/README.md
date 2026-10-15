# Conformance vectors: n-gram

<!-- doc-meta
half_life: structure
verified_on: 2026-10-15
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the smoothing, the decay or the way a context is written changes
teaches: none
-->

> One table, two languages, and the file that says they predicted the same.

`ai_opponent`'s `NGramPredictor` (GDScript) and `gameaikit.ngram` (Python)
count the same way: an action is counted under the last `order - 1` actions
before it; when a context is seen again its old counts are multiplied by
`decay` first; a prediction adds `prior` to every action's count and divides
by the total. Each vector is one `.json` file -- the settings, a `sequence`
of actions, and `cases` that claim, after `seen` actions, the `context`, the
`probabilities` of every action and the `likeliest`. Both sides check every
claim against the file, never against each other: `make test-ngram-vectors`
on the GDScript side, `make test-python` on the Python side.

## Where the numbers came from

From neither implementation: `derive.py`, an exact-fraction script
importing nothing from this repository, wrote them, and `order-two-by-hand` can be checked by
hand. Order 2, actions high, low, throw, no decay, prior 1, and the
sequence high, low, high, low, high, throw:

- the first high has no context yet; low is counted under "high", high
  under "low", low under "high", high under "low", throw under "high";
- after five actions the context is "high", and its row is low 2: high
  (0 + 1) / (2 + 3) = 1/5, low (2 + 1) / 5 = 3/5, throw 1/5 -- likeliest
  low;
- after six it is "throw", never seen: every action 1/3, and the tie goes to
  the first, high.

`decay-follows-a-change` is the case T17's decay exists for: high answered
by low three times, then by throw twice. At decay 1/2 the row under "high"
is low 0.875, throw 1 after the first throw, and throw is already the
likelier -- where an undecayed table would still say low, three to one.
After the second it is low 0.4375, throw 1.5.

`derive.py` wrote them; run it again to check.

## What is refused

A vector missing a setting, with a case whose probabilities leave an action
out or do not sum to 1, or with a key nobody reads, is refused rather than
half-checked: a misspelt `"likeliest"` would otherwise drop the claim while
every number still passed.
