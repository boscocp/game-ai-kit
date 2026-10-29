# Conformance vectors: perception

<!-- doc-meta
half_life: structure
verified_on: 2026-10-29
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: a stealth technique in ai_perception changes its rule, or a vector field is renamed
teaches: none
-->

> What a guard's senses, awareness and belief must answer (T69), written
> down once and checked from both languages.

`make test-perception-vectors` answers these with `ai_perception`, and
`make test-python` with `gameaikit.perception`. Both compare every value
with the file, never with each other. `derive.py` writes the files from a
third copy of the rules that imports nothing from the repository.

Each file has `name`, `why`, `kind`, `query` and `expect`. The kinds:

- **`shape`** -- a `shape` row (`VisionShape.from_row`'s) and a list of
  `looks`, each a distance, an angle, the body `points` that are clear, the
  stance's `needed` count, the `light` at the feet, whether `moving`, and
  the `hidden` share. Expects each look's `zones` index (-1: none) and
  `certainties`.
- **`loudness`** -- `heard`, a list of `[path length, radius, listener
  factor]`; a negative length means no path. Expects each `loudness`.
- **`awareness`** -- a `row` (`Awareness`'; a phase may carry its own
  `decay`, T70) and `steps`, each `perceived`,
  `rate`, `seconds` and `now`, from a fresh number. Expects the `values`
  after each step and the `phases` (indices) they read as.
- **`phase`** -- a `row` and `numbers`. Expects each one's phase index.
- **`belief`** -- `neighbours`, a list of each node's neighbour indices,
  and `steps`, each `{"collapse": node}` or `{"seen": [nodes], "spread":
  s}`, from an even belief. Expects the `shares` after each step and
  whether it was `reseeded`.
- **`particles`** (T91) -- `neighbours`, a particle `count`, a `seed`, the
  `knobs` (`walk_on`, `turn`, `unheard`), and `steps`, each `{"collapse":
  node}` or `{"seen": [nodes], "unheard": [nodes]}`, from a cloud spread
  evenly. Expects after each step every particle's node (`nodes`), the
  normalised `weights` the step gave them, in the order the particles
  were weighed, before the resampling that reorders them (all 0 when it
  reseeded), the
  `shares` per node, the nodes sight `emptied`, and whether it was
  `reseeded`. The draws are Marsaglia's xorshift from `seed`, written out
  in all three copies; a single different draw moves a particle, so these
  vectors pin the order of the draws as well as the rules.

The guard type's awareness **rate** is a fuzzy controller, so its vector is
an ordinary fuzzy vector: `spec/vectors/fuzzy/a-guards-awareness-rate.json`.

## Tolerance

`1e-9`, absolute. Every rule here is a few multiplications and a clamp in
doubles on both sides; the margin catches a different formula, not a
different maths library.

## What they deliberately do not pin

- **The order zones are written in**, beyond a tie: the most certain zone
  holding a body counts, and on a tie the earlier one.
- **What a guard does about any of it.** That is T70's selector.
