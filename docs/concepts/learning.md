# Learning: two regressions and a tree you can read

<!-- doc-meta
half_life: concept
verified_on: 2026-11-06
tier: 1
source: https://en.wikipedia.org/wiki/Logistic_regression ; book:Leo Breiman, Jerome Friedman, Richard Olshen and Charles Stone, "Classification and Regression Trees", Wadsworth, 1984 -- CART and the Gini impurity
invalidated_if: the regressions stop being linear in their features, the tree stops being CART on Gini impurity, or training moves out of Python's standard library
teaches: learning
-->

> How a logistic regression decides *attack or retreat*, how a linear one
> decides *which node falls first*, how a decision tree guesses *what the
> fighter in front of it does next*, and why all three are trained in
> Python and only evaluated in the game. Needs Python 3 and nothing else.
> The code is [`python/gameaikit/`](../../python/gameaikit/) and
> [`godot/addons/ai_learning/`](../../godot/addons/ai_learning/) with the
> tactical board's adapter in [`godot/game/tactical/`](../../godot/game/tactical/), and
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
  at whichever node the model says will fall first -- unless an enemy is
  standing on one, which neither model was ever told about: then a written
  rule sends the unit there instead, and says so.

Five features for a fight: the health difference, the numeric advantage, the
defender's terrain, how far away the nearest friend is, and -- since T44 --
which way the counter table leans (+1, 0 or -1), because the dataset's units
now have a type as the tactical board's do. Four for a node.

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

The rows come from simulated games. A fight is rounds of dice -- the
defender's terrain adds to the damage it hits back with, the side with more
units nearby hits harder, a friend nearby can arrive halfway -- and **not** a
logistic formula. If the outcome were computed by the same shape of function
being fitted, the model would recover the line somebody wrote three files away
and the lesson would be circular. Here the
weights are an approximation that can be wrong, which is the only kind worth
printing.

## Reading what it learned

```bash
PYTHONPATH=python python3 -m gameaikit.tactical.report
```

prints the weights, beside how well the model does on games it never saw. The
combat model is right about 86% of held-back fights. Two yardsticks sit next to
that number, and the second is the honest one:

* always saying "the attacker loses" scores 58%;
* **looking the fight up in a table** of training fights scores 71%. The
  features are small integers, so most held-back fights have an exact twin
  among the ones trained on.

A model with five weights cannot memorise hundreds of situations, so its 86%
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

## A decision tree

A regression adds: each feature pushes the answer by its weight, whatever
the others say. A **decision tree** asks: one question at a time -- is the
distance close? is the health at most 2.5? -- and goes to the left or the
right child on the answer, until it reaches a leaf. The leaf holds how often
each answer was seen among the training rows that came the same way, and
the likeliest is the one it saw most. Read aloud, a path is a rule, which is
the reason to fit one: "after a high, while the opponent is doing nothing,
when ahead on health -- a high again, 4 times in 12".

It is fitted by **CART** (Breiman and others, 1984), in
[`tree.py`](../../python/gameaikit/training/tree.py). At each node, try
every test the rows allow -- each word of each word feature, each threshold
halfway between two numbers of each number feature -- and keep the one that
leaves the two sides least mixed. "Mixed" is the **Gini impurity**: for n
rows, n minus the sum of each answer's count squared over n. A side that is
all one answer scores 0; the split scores the sum of its two sides. Stop at
the depth cap, when a side would hold fewer than the leaf size, or when no
test makes the rows purer. The arithmetic is exact (fractions, not floats),
and of two equally good tests the first in feature order wins, so the same
rows make the same tree on every machine.
[`spec/vectors/tree/`](../../spec/vectors/tree/README.md) works one root
by hand, and holds the Python fit and the game's walk to the same answers.

### What it reads in the fighting game

T17's learner (`ai_opponent`'s n-gram) answers "what will the player do
next?" from the player's last action, counting during the fight. The tree
answers the same question from the whole situation as the player saw it --
the six words behaviour cloning cuts each decision into: the player's last
action, what the opponent was doing, the player's condition, the distance,
the health, the corner. It is fitted on the person's recorded fights before
the fight starts, and the opponent leans its answers towards what beats the
leaf's likeliest action, as the learner leans towards the n-gram's. In
`make demo-fighting`, the "tree:" modes show the path on the panel, a test
a line, and the leaf's counts.

`make tree-report` fits it at several depths on the six training fights
(317 decisions) and scores it on the three held out (133), beside the
n-gram scored as it plays, from an empty table, a quarter of a second late:

| reader | leaves | right on the rows it was fitted on | right on fights it never saw |
|---|---|---|---|
| always the commonest action | 1 | 30.9% | 21.1% |
| tree, depth 2, leaf at least 5 rows | 4 | 35.3% | 23.3% |
| tree, depth 3, leaf at least 5 rows (published) | 8 | 37.2% | 20.3% |
| tree, depth 5, leaf at least 5 rows | 18 | 39.7% | 17.3% |
| tree, depth 8, leaf at least 2 rows | 49 | 46.4% | 18.0% |
| tree, depth 20, leaf at least 1 row | 138 | 63.7% | 19.5% |
| the n-gram (T17), learning during the fight | -- | -- | 32.3% |

Two things to read in it.

**The left column climbs and the right one does not.** That is
**overfitting**: a deeper tree has more leaves, each holding fewer rows,
until a leaf is one decision the person made once. It scores better and
better on the rows it was fitted on because it is learning *those rows*, and
no better on a new fight, which is the only score that means anything. 133
held-out decisions cannot tell 20% from 23% apart, so the published depth
was chosen for the panel -- three tests is a path that fits on it -- and not
on the held-out fights, which would have made them training data.

**The n-gram wins, and by a margin.** Six words of situation say little
about what this person does next: the best tree is two points over always
guessing the commonest action, and the published depth-3 tree, at 20.3%,
is under that floor of 21.1%. The n-gram knows something the tree cannot:
what the person is doing *this* fight. A person's habits move from fight to
fight, and a model fitted on last week's fights reads last week's person.
The scripted stand-ins, whose habits never move, are the other way round:
the published tree scores 40.0%, 48.9% and 38.3% on their held-out fights
against the n-gram's 30.7%, 41.5% and 29.5% -- and the floor's 38.6%, 44.7%
and 37.2%, so even there it buys only a few points over the commonest
action.

So the tree is not here because it reads this person well. It is here
because it is the first learned model whose decision a person can follow
step by step on the screen, and because its weakness alone -- a high-variance
learner on few rows -- is exactly what a forest of them voting fixes (T114).

The same split as the regressions holds: Python fits and publishes
`opponent_tree.json`, the game only walks it, and `check_no_training.py`
holds both halves -- the published tree is what a fresh fit writes (N16),
and no GDScript writes where it lives (N17). The n-gram beside it is the
only model in the fight that learns anything, as ADR 0016 allows.

## When not to use it

When the decision is not a function of a few numbers you can name. A
regression is the right tool exactly when you can say what it should look at,
and the wrong one for "play the whole game". A network that plays the whole
game teaches nothing anybody can print.

A tree alone, deep, on few rows: it memorises the rows, as the table above
shows. Cap its depth and its leaf size, judge it only on fights it never
saw, and when one tree is not enough, many trees voting is the next step.
