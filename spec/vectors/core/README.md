# Conformance vectors: the kit's one seeded generator

<!-- doc-meta
half_life: structure
verified_on: 2026-11-04
tier: 1
source: https://www.jstatsoft.org/article/view/v008i14
invalidated_if: the generator's shifts, its mask, its seed of zero, or the rule that a pick of one spends no draw changes
teaches: none
-->

> A seed in, the first draws out: the file that says `ai_core`'s `Xorshift`
> and `gameaikit.core.Xorshift` are one generator.

Monte Carlo search, the particle filter, the bandit and the maze's ghosts
all draw from Marsaglia's 32-bit xorshift (2003), and since T109 from one
copy of it in each language: `godot/addons/ai_core/xorshift.gd` and
`python/gameaikit/core/xorshift.py`. Each technique's own vectors
(`spec/vectors/adversarial/`, `bandit/`, `perception/`, `maze/`) pin the
order in which it spends the draws. This file pins the draws themselves.

## The file

`xorshift.json` -- `cases`, each from a fresh generator per claim:

- `seed`, and its first six `draws` (`next()`);
- `uniforms`, the first three `uniform()`: `next() / 2^32`, in (0, 1);
- `picks_of` and `picks`: `index(count)` for each count in turn, from one
  generator.

The rules a third implementation must follow to agree:

1. a step is `x ^= x << 13`, `x ^= x >> 17`, `x ^= x << 5`, every left
   shift cut to 32 bits;
2. a seed is cut to 32 bits, and a seed of zero is seed 1, because a state
   of zero would stay zero (so 4294967297 is seed 1, and 0 is seed 1); a
   negative seed is cut in two's complement, so -1 is 2^32 - 1 and draws
   253983 first;
3. a pick of one is 0 and spends no draw; a pick of `count` is
   `next() % count`.

Seed 1 starts 270369, which can be worked by hand: 1 xor (1 << 13) is 8193;
8193 >> 17 is 0, so it stays 8193; 8193 xor (8193 << 5) is
8193 + 262176 = 270369.

## Where the numbers came from

From neither implementation: `derive.py`, the generator written out once
more and importing nothing from this repository, wrote them:

    python3 spec/vectors/core/derive.py spec/vectors/core

Its seed 1, 0, 2463534242 and 86 draws are the ones
`spec/vectors/adversarial/xorshift.json` has held since T86, written by
another script. `make test-core-vectors` reads the file through the addon;
`make test-python` reads it through `gameaikit.core`.
