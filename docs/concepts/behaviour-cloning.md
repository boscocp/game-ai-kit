# Behaviour cloning: what a learned model buys over a table

<!-- doc-meta
half_life: concept
verified_on: 2026-10-15
tier: 1
source: https://www.gamedeveloper.com/programming/the-killer-groove-the-shadow-ai-of-killer-instinct
invalidated_if: the situation's features, the split, the four methods compared, or the owner's recordings change and the numbers here are not replaced
teaches: behaviour-cloning
-->

> Record a player, learn what it did in each situation, and play like it.
> Then ask the question the kit has been building towards: what did a
> learned model buy over T17's frequency table, and over a ghost that only
> looks things up?

**The published player is the owner**, from four fights recorded on
2026-10-15 -- about four minutes of play, 237 decisions. That is very little,
and the numbers below carry it. Before the owner played, the pipeline was
built on three scripted stand-ins (`godot/test/stand_in_player.gd`); their
numbers are at the end, because the contrast is the lesson.

## The pipeline, in four files

1. **Record.** `make record-fights` opens the training mode with recording
   on; every fight you play is kept in `data/fights/` as its input log --
   T16 made a log a replay, so nothing else needs keeping.
2. **Cut.** `make clone-rows` replays each log in Godot and writes one row
   per decision of the recorded player to `data/cloning/rows.json`: the
   moment it began a new action, what it did, and the situation it saw
   **15 frames before** -- a person's reaction time, and the delay the
   cloned opponent will be held to, so what it learns from and what it is
   later asked about are the same age.
3. **Fit.** `gameaikit.cloning` (Python, standard library) splits the rows
   **by recording**, fits a softmax model and counts a ghost's table on the
   training part, and publishes both in
   `godot/addons/ai_learning/clone_weights.json`.
4. **Play.** Three dummy modes in `make demo-fighting` -- *ghost: exact*,
   *ghost: nearest*, *clone* -- do what the recorded player would have done.

The features are computed in GDScript only (`FightSituation`): Python never
sees a fight, only rows. So there is no second copy of the arithmetic to
drift, which T6 and T32 each needed vectors to hold together.

## A situation is six words

`last` (what this player did last -- what an order-2 n-gram sees),
`other` (what the other fighter is doing), `me` (free, moving, airborne, hit,
blocking), `distance` (close, near, far), `health` (ahead, even, behind),
`corner` (yes, no). Words rather than numbers, so a row reads aloud and a
ghost can key on it: `step in | crouch | free | close | even | no -> throw`.

## The four ways to use a recording

| method | what it is | where in the literature |
|---|---|---|
| **n-gram** (T17) | counts what the player did after what, during *this* fight; starts empty | the 2019-2020 arena entries |
| **ghost, exact** | the answers the player gave in exactly this situation; all its play when it never met it | the ghost papers, on Street Fighter Zero 3 |
| **ghost, nearest** | the answers in the recorded situations fewest features away, pooled | Killer Instinct's Shadows |
| **clone** | multinomial logistic regression over the six words | behaviour cloning proper |

The n-gram *answers* the player; the other three *imitate* one. They are
compared on the same thing -- guessing the player's next action -- and then
each is seated in the game.

## The comparison

`python3 python/gameaikit/cloning/compare.py --report`, on the owner: 3
recordings fitted (151 decisions), 1 held out (86 decisions, the one fight
against the hard opponent).

| method | held-out accuracy | numbers | built in | beats medium |
|---|---|---|---|---|
| always the commonest (step in) | 43.0% | 1 | -- | -- |
| **n-gram (T17)** | **48.8%** | ≤121 | nothing beforehand | 40/100 (as the learner) |
| ghost, exact | 44.2% | 133 | ~0 s | 66/100 |
| ghost, nearest | 44.2% | 133 | ~0 s | 75/100 |
| model, last action only | 47.7% | 143 | 0.17 s | -- |
| model, the situation | 36.0% | 363 | 0.30 s | 47/100 |

What this says:

- **The learned model bought nothing -- it cost.** Over six features it
  guesses the held-out fight *worse than always saying "step in"*. 151
  decisions spread over 103 situations met is a few sightings each, and
  363 numbers fitted to that learn the three training fights, not the
  player. The penalty keeps the weights small; it cannot invent data.
- **The table that learns during the fight was the best guesser.** T17's
  n-gram starts the held-out fight knowing nothing and still leads: what
  this player did next depended most on what they had just done, and that
  is learnt within one fight.
- **The ghosts are no better than the floor at guessing, yet win most.**
  The nearest ghost beats the fixed opponent 75 times in 100 and the clone
  47: a ghost replays answers the player actually gave, whole, where the
  model averages them into a probability that is never quite any of them.
  Guessing well and playing well are different measurements.
- **The held-out fight was against the hard opponent**, the training ones
  against medium. A player fights differently under pressure; a split by
  recording shows that, and a split by row would have hidden it.

So the honest answer, for this player and this much data: **the learned
model bought nothing here.** The frequency table T17 already ships guesses
better, and a ghost plays better. A model earns its numbers with far more
play than four fights, or with situations too many to have met -- and this
kit would reach for one then, not before.

### The stand-ins: why a pipeline check is not a result

On the rushdown stand-in (6 recordings fitted, 2 held out, 94 decisions):

| method | held-out | beats medium |
|---|---|---|
| always the commonest | 44.7% | -- |
| n-gram (T17) | 42.6% | 40/100 |
| ghost, exact | 55.3% | 87/100 |
| ghost, nearest | 53.2% | 92/100 |
| model, last action only | 50.0% | -- |
| model, the situation | 55.3% | 88/100 |
| the stand-in itself | -- | 72/100 |

Turtle and jumper, held out: the model 53-64%, the n-gram 47-57%, the
commonest 37-39%. On stand-ins the model ties or beats the rest, because a
stand-in *is* a table of situations and a die -- the same shape as the
model. A person is not, and the ranking turned over. The clones also beat
the rushdown itself, 87-92 against 72: the stand-in fumbles one press in
ten and its clones fumble none -- imitation copies the choices, and the
execution is the opponent's own.

## Inference costs nothing a frame would notice

Measured headless on an AMD Ryzen 5 9600X on 2026-10-15
(`make test-inference-budget`), on the owner's published player: the
softmax **0.007 ms** a decision, the exact ghost **0.002 ms**, the nearest
ghost **0.047 ms** -- it compares with every one of the 103 situations met.
The budget is 1 ms, a sixteenth of a frame. This is the only machine the
owner had to hand; the slowest machine available was this one.

## Is the training deterministic?

Yes, end to end, and checked. Each step is a script with no clock and no
unseeded chance:

1. `make clone-rows` -- Godot replays the logs; the rules are deterministic
   (T16), so the same recordings cut the same rows. `make test-clone-rows`
   cuts them again and fails if the committed file differs.
2. `python3 -m gameaikit.cloning.publish` -- the split is by recording name,
   the fit is full-batch gradient descent from zero weights for a fixed 300
   passes, in a fixed order. `--check` fits again and compares; N10 in
   `check_no_training.py` runs that inside `make check`.
3. `make test-clone-fights` -- every fight is seeded, so the win rates
   repeat; the file names the sha256 of the weights it fought.

`make train-clone` runs all three. The only number that varies between runs
is "built in", the seconds the fit took, which is printed and never stored.

## What is not proven

- **Anything about people in general.** One person, four fights. Record
  more (`make record-fights`, then `make train-clone CLONE_PLAYER=person`)
  and the table here is replaced.
- **Whether a person can tell them apart.** The manual check: play the
  clone and the ghosts, and the learner. If you cannot tell them apart, that
  is a result and it goes in the README beside the technique.
- The win rates are measured against one opponent at one level, and only
  re-measured when the published file changes -- a change to the game's
  rules leaves them stale until `make test-clone-fights` runs again.
