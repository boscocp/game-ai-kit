# Conformance vectors: bandit

<!-- doc-meta
half_life: structure
verified_on: 2026-10-30
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: UCB1's bound, the tie-break, the order of epsilon-greedy's draws, or the xorshift generator changes
teaches: none
-->

> One bandit, two languages, and the files that say they chose the same.

`ai_bandit`'s `Bandit` (GDScript) and `gameaikit.bandit` (Python) keep the
same two numbers an arm -- how often it was pulled, and the sum of what it
paid -- and choose from them by the same rules. Each vector is one `.json`
file: the bandit's settings (`policy`, `arms`, `exploration`, `epsilon`,
`seed`), a `payoffs` sequence for each arm, and the claims -- the arm
`chosen` on every pull, and each arm's final `pulls` and `sums`. The k-th
pull of an arm pays its sequence's k-th payoff, from the start again when
the sequence runs out. Every payoff here is known at once, so a pull is
`reward` -- `pull` and `pay` together -- and the paid count equals the
pulls; a delayed payoff (`pull` now, `pay` later) is held by the unit
tests in both languages, not by these files. Both sides check every claim against the file, never
against each other: `make test-bandit-vectors` on the GDScript side, `make
test-python` on the Python side.

The rules the two follow, and that a third implementation must follow to
agree:

1. an arm never pulled is chosen first, the lowest index first, and no
   draw is spent;
2. with one arm there is no choice, and no draw is spent;
3. UCB1 takes the highest `sums[j] / pulls[j] + exploration * sqrt(ln n /
   pulls[j])`, `n` every arm's pulls together, computed in that order;
4. epsilon-greedy draws one number, `next() / 2^32`; below `epsilon` it
   draws a second and takes arm `next() % arms`, otherwise the highest mean;
5. of equal bounds or means, the first arm.

The draws are Marsaglia's 32-bit xorshift, the generator T86 wrote for Monte
Carlo search. Seed 1 starts 270369, which can be worked by hand: 1 xor
(1 << 13) is 8193; 8193 >> 17 is 0, so it stays 8193; 8193 xor (8193 << 5)
is 8193 + 262176 = 270369. Seed 0 is seed 1, because a state of zero would
stay zero.

## Where the numbers came from

From neither implementation: `derive.py`, a script importing nothing from
this repository, wrote them. The payoffs are halves, quarters and eighths,
so every sum is exact. `ucb1-two-arms-by-hand` can be checked by hand, with
`c` the square root of two, so `c * sqrt(ln n / k)` is `sqrt(2 ln n / k)`.
Arm 0 always pays 1; arm 1 pays 0, then 0.5:

- pulls 1 and 2 try each arm once (rule 1): arm 0 pays 1, arm 1 pays 0;
- pull 3, n = 2: arm 0's bound is 1 + sqrt(2 ln 2 / 1) = 2.18, arm 1's
  0 + 1.18 -- arm 0;
- pulls 4 to 6 the same way, the gap closing: at n = 3, 1 + sqrt(2 ln 3 /
  2) = 2.05 against sqrt(2 ln 3) = 1.48; at n = 4, 1.96 against 1.67; at
  n = 5, 1.90 against 1.79 -- arm 0 each time;
- pull 7, n = 6: arm 0 has been pulled five times, and its bonus has
  shrunk to sqrt(2 ln 6 / 5) = 0.85, so its bound is 1.85; arm 1, left out
  of five pulls, has grown to sqrt(2 ln 6) = 1.89 -- **arm 1**, though it
  paid nothing. That is the exploration term doing what it is for: an arm
  tried once is poorly known, and UCB1 goes back to it.

So the claimed choices are 0, 1, 0, 0, 0, 0, 1, the final pulls 5 and 2,
the sums 5 and 0.5.

The others: `ucb1-settles-on-the-best` pulls the arm paying 3/4 on average
22 times in 40; `ucb1-ties-go-to-the-first` cycles through equal arms in
order (rule 5); `ucb1-without-exploration-is-greedy` stays on the arm that
paid best on its first pull, though the other pays more on average -- the
trap UCB1's second term exists for; `epsilon-greedy-seeded` and
`epsilon-one-is-random` pin the order of the draws; `one-arm-draws-nothing`
pins rule 2.

`derive.py` wrote them; run it again to check.

## What is refused

A vector with a key nobody reads, settings that cannot work, an arm with no
payoffs, a payoff outside [0, 1], no pull claimed, final counts that do not
name every arm or do not add up to the pulls claimed, is refused rather
than half-checked: a misspelt `"chosen"` would otherwise drop the claim
while every number still passed. Two planted bandits must fail, in both
languages: one that gives a tie to the last arm (rule 5), and one that
spends a spare draw before every choice (rule 4).
