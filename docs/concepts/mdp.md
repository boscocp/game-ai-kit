# Markov decision processes: deciding a step at a time when the world rolls dice

<!-- doc-meta
half_life: concept
verified_on: 2026-10-29
tier: 1
source: https://aima.cs.berkeley.edu/contents.html
invalidated_if: gameaikit.mdp stops solving by value iteration, or spec/maze/mdp.json changes its state, rewards or discount
teaches: sequential-decisions
-->

> Search finds a path when every move lands where you meant it to. An MDP
> is for when it may not: a move has outcomes, each with a probability, and
> the answer is not a path but a **policy** -- a move for every state you
> might end up in. Tier 1: the solvers are Python's standard library, in
> [`python/gameaikit/mdp/`](../../python/gameaikit/mdp/). `make demo-maze`,
> then C, watches the solved policy play Pac-Man.

## The parts

AIMA (4th ed., ch. 17, "Making Complex Decisions") writes a Markov
decision process as five things:

- **states** -- here, Pac-Man's cell, Blinky's cell and the way he last
  moved, and which of the four pellets are left: 82,160 that a game can
  reach;
- **actions** -- Pac-Man's four moves; into a wall he stays put;
- **a transition model**, P(s' | s, a): where an action can lead, and how
  likely each is. In the maze the chance is Blinky's: at a fork he takes
  the arcade's way with probability 0.8 + 0.2 / ways and any other with
  0.2 / ways (a rule of this game, written in `spec/maze/rules.json`);
- **rewards** -- a pellet +1, the last one +10 more, caught -10, and -0.04
  for every step, so that dawdling costs something;
- **a discount**, gamma = 0.95: a pellet next step is worth more than the
  same pellet in ten.

"Markov" is the promise that the state is enough: what happens next
depends on the state and the action, not on how you got there. That
promise is a property of the *state you chose*, and the maze shows how it
breaks. In the arcade the ghosts switch between scatter and chase on a
timer, and every switch makes them turn round; the timer is not in the
state above, so two identical-looking states can have ghosts about to do
different things. The kit solves the regime where the promise holds --
Blinky chasing for ever, as the arcade does after its last switch -- and
says so (`spec/maze/mdp.json`), rather than solve the wrong problem
exactly.

## The value of a state, and the Bellman update

A state's **value** U(s) is the reward you can expect from it on, playing
as well as possible, each step discounted once more. It satisfies the
Bellman equation: a state is worth its best action's

    Q(s, a) = sum over s' of P(s' | s, a) [R(s, a, s') + gamma U(s')]

which is circular -- values defined by values -- and that is exactly what
makes it solvable by repetition.

**Value iteration** (AIMA 17.2.1) starts every value at 0 and applies that
equation to every state as an update, sweep after sweep. Each sweep the
values are closer to the true ones; it stops when no value moved by more
than epsilon (1 - gamma) / gamma in a sweep, which bounds the remaining
error by epsilon. The policy is then read off: in each state, the action
with the best Q.

**Policy iteration** (AIMA 17.2.2) keeps a policy instead. It works out
what that policy is worth (here by sweeps that try only the policy's
action, to the same threshold, rather than solving for them exactly), improves it everywhere by one greedy
step, and stops when improving changes nothing.

## Measured, on the maze

`PYTHONPATH=python python3 -m gameaikit.mdp.measure --compare`, on a
desktop Ryzen 5 9600X (one core; pure Python, no numpy):

| | value iteration | policy iteration |
|---|---|---|
| outer rounds | 60 sweeps | 22 improvements |
| sweeps over all states | 60 | 1,233 |
| Q-values computed | 19.7 million | 106.7 million |
| seconds | 3.4 | 21.6 |

Building the model, 82,160 states with every action's outcomes, takes 1.0
s, and the whole process peaks at 117 MB. The two agree on every value to
within 0.0001, and choose differently in 2,109 states -- each one a tie,
two moves worth exactly the same, most of them two walks into a wall,
which are the same "stay".

So AIMA's comparison holds in its own terms -- far fewer improvements
than value iteration has sweeps -- and loses on the clock: evaluating the
first policy (every state's first move, "up") is slow, because a Pac-Man
who walks up into walls survives a long while before Blinky catches him,
and every evaluation sweep pays for it. Value iteration needs only 60
sweeps, not the hundreds the discount alone would suggest, because the
episodes end: the values stop moving once the optimal play is a few
dozen steps long.

## Why the policy is computed in Python

Solving is a batch job, a few seconds on a desk; looking up is one
array index. The kit's rule (invariant 6) is that the batch job runs in
Python and the game only reads what it wrote: `make solve-maze` writes
`data/maze/values.json` and `policy.json`, `MdpPacMan` in
`godot/game/maze/` reads them, and `check_no_training.py`'s N15 solves
again and fails if the committed files are not what comes out. The
values Godot draws beside Pac-Man -- each move's Q -- are a one-step
lookahead over the published values, a reading, never an update.
Updating values while playing is Q-learning (AIMA 22.3.3), and it stays out
of the game.

## Does it play well?

Over 1,000 seeded games against the imprecise Blinky
(`PYTHONPATH=python python3 -m gameaikit.mdp.measure`), the policy won all
1,000, never caught, in 30.5 steps on average. A controller that walks
the A\* path to the nearest pellet and ignores Blinky won 826 and was
caught 174 times. The MDP's edge is not cleverness about pellets -- both
take about 30 steps -- but never stepping where Blinky's dice can reach.

## Frozen Lake

Gymnasium's *Frozen Lake* is the usual first MDP: on slippery ice a move
goes the intended way with probability 1/3 and to either side otherwise,
equally; a hole ends the episode with nothing, the goal pays +1. The
two-by-two version is solved by hand in `python/tests/test_mdp.py`, and
the answer is the lesson: from the start, the best move is *into the
wall*, because a wall cannot be slipped through and the hole can.

## When not to use it

- **A state space you cannot list.** Every sweep visits every state. A
  second ghost multiplies the maze's 82,160 by about 200, some 16 million
  states -- at the rate measured here, an estimate and not a measurement,
  over ten minutes a solve and tens of gigabytes in pure Python. Then
  states are sampled or approximated, which is learning.
- **A state that is not Markov.** The arcade schedule is the example
  above: solve it as if it were, and the policy is exact for a game
  nobody plays.
- **A model you cannot write down.** Value iteration needs P(s' | s, a).
  With only the game to play, the agent learns from experience instead.

## References

Opened on 2026-10-29.

- Russell, S., Norvig, P. *Artificial Intelligence: A Modern Approach*,
  4th ed., ch. 17: 17.1 Sequential Decision Problems, 17.2.1 Value
  Iteration, 17.2.2 Policy iteration; 22.3.3 Temporal-difference
  Q-learning (contents).
  <https://aima.cs.berkeley.edu/contents.html>
- Gymnasium, *Frozen Lake*: the slippery move and the rewards.
  <https://gymnasium.farama.org/environments/toy_text/frozen_lake/>
