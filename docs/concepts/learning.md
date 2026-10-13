# Learning: two regressions you can read

<!-- doc-meta
half_life: concept
verified_on: 2026-10-13
tier: 1
source: https://en.wikipedia.org/wiki/Logistic_regression
invalidated_if: the models stop being linear in their features, or training moves out of Python's standard library
teaches: learning
-->

> How a logistic regression decides *attack or retreat*, how a linear one
> decides *which node falls first*, and why both are trained in Python and only
> evaluated in the game. Needs Python 3 and nothing else. The code is
> [`python/gameaikit/`](../../python/gameaikit/) and
> [`godot/addons/ai_learning/`](../../godot/addons/ai_learning/), and
> [the Godot page](../godot/learning.md) is how to call it.

## Two questions, two models, one shape

Both models compute `w·x + b`: multiply each feature by its weight, add them
up, add a bias.

* **Will this attack work?** The answer must be a probability, so the sum goes
  through the logistic function -- a sigmoid that turns any number into one
  between zero and one. That is *logistic* regression. The game attacks when
  the probability clears a threshold, and retreats when it does not.
* **How long will this node take to fall?** The answer is a number of turns,
  so the sum is used as it stands. That is *linear* regression. The game walks
  at whichever node the model says will fall first.

Four features each. For a fight: the health difference, the numeric advantage,
the defender's terrain, and how far away the nearest friend is.

## One update rule for both

Training is gradient descent: start with zero weights, nudge each one in the
direction that makes the predictions less wrong, repeat. For both models the
nudge is the same expression:

    gradient = mean over rows of (prediction - label) * feature

For log loss through a sigmoid this is the gradient exactly. For squared error
through a linear prediction it is the gradient of *half* the squared error; the
factor of two disappears into the learning rate. That is why
[`descent.py`](../../python/gameaikit/training/descent.py) has one `fit` and
not two, and a reader who does the calculus and finds a 2 will find it
accounted for there.

## Where the data comes from, and why it is dice

The rows come from simulated games. A fight is rounds of dice -- terrain
reduces the damage that gets through, numbers add to it, a friend nearby can
arrive halfway -- and **not** a logistic formula. If the outcome were computed
by the same shape of function being fitted, the model would recover the line
somebody wrote three files away and the lesson would be circular. Here the
weights are an approximation that can be wrong, which is the only kind worth
printing.

## Reading what it learned

```bash
PYTHONPATH=python python3 -m gameaikit.training.report
```

prints the weights, beside how well the model does on games it never saw. The
combat model is right about 88% of held-back fights. Two yardsticks sit next to
that number, and the second is the honest one:

* always saying "the attacker loses" scores 69%;
* **looking the fight up in a table** of training fights scores 82%. The
  features are small integers, so most held-back fights have an exact twin
  among the ones trained on.

A model with four weights cannot memorise hundreds of situations, so its 88%
is earned. A model with more capacity would have to beat the table, not the
majority, before its score meant anything.

Every combat weight has the sign the simulator's rules imply: more health and
more numbers help, defensive terrain and a distant friend hurt.

## Python trains, the game only infers

That is invariant 6, and `make lint-no-training` is its gate. Training is
offline, deterministic and checked; the game loads a JSON file of weights and
does arithmetic. The two languages are held to the same rows and the same
numbers by the vectors in
[`spec/vectors/learning/`](../../spec/vectors/learning/), and the weights are
published rounded to six decimals so that they can agree.

One lesson from building it: **a conformance vector only tests the range its
board can reach.** A feature that reports "nobody is coming" with a sentinel
distance was wrong on the game's 12-wide board and right on every vector,
because the vectors' boards were too small to reach it.

## When not to use it

When the decision is not a function of a few numbers you can name. A
regression is the right tool exactly when you can say what it should look at,
and the wrong one for "play the whole game". A network that plays the whole
game teaches nothing anybody can print.
