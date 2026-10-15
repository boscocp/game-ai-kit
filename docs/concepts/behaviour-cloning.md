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

**The published player is the owner**, from nine fights recorded on
2026-10-15 -- three against the fixed opponent at medium, one at hard, five
against the learner at medium and hard; about eight minutes of play, 450
decisions. That is still little, and the numbers below carry it. Before the
owner played, the pipeline was built on three scripted stand-ins
(`godot/test/stand_in_player.gd`); their numbers are at the end, because the
contrast is the lesson.

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

`python3 python/gameaikit/cloning/compare.py --report`, on the owner: 6
recordings fitted (317 decisions), 3 held out (133 decisions) -- every
fourth by name, counting back from the last.

| method | held-out accuracy | numbers | built in | beats medium |
|---|---|---|---|---|
| always the commonest (step in) | 21.1% | 1 | -- | -- |
| **n-gram (T17)** | **40.6%** | ≤121 | nothing beforehand | 40/100 (as the learner) |
| ghost, exact | 25.6% | 265 | ~0 s | 60/100 |
| ghost, nearest | 29.3% | 265 | ~0 s | 53/100 |
| model, last action only | 33.8% | 143 | 0.34 s | -- |
| model, the situation | 32.3% | 396 | 0.65 s | 47/100 |

What this says:

- **The table that learns during the fight guesses best, by seven points.**
  T17's n-gram starts every held-out fight knowing nothing and still leads
  everything fitted beforehand on six other fights. This player changes
  from fight to fight -- one held-out fight is mostly stepping out, another
  mostly crouching -- and only a method that learns *this* fight follows
  that.
- **The situation bought nothing over the last action.** The model that
  sees six features guesses no better than the one that sees only what the
  n-gram sees (32.3% against 33.8%), with almost three times the numbers.
- **The model beats the ghosts at guessing, and loses to them at
  fighting.** It averages the player's answers into probabilities and
  guesses the commonest well; a ghost replays whole answers the player
  actually gave, and the exact one wins 60 fights in 100 against the
  clone's 47. Guessing well and playing well are different measurements.
- **With four fights it was worse.** On the first four fights the
  six-feature model guessed *under* the floor (36.0% against 43.0%): 151
  decisions over 103 situations is a few sightings each, and the model
  learnt the three training fights rather than the player. More play
  lifted it above the floor; it did not lift it past the n-gram.

So the honest answer, for this player and this much data: **the learned
model bought little here, and the frequency table T17 already ships is the
better predictor.** A model earns its numbers with far more play, with a
player whose habits hold from fight to fight, or with situations too many
to have met -- and this kit would reach for one then, not before.

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

## Can a person tell them apart?

Not much. The owner played the clone, both ghosts and T17's learner on
2026-10-15 and could not tell them apart in any useful way; only the fixed
opponent at hard felt a little harder, and everything felt very easy. So
the three ways of copying a player -- and the one way of answering one --
produced opponents a person could not distinguish, in this fight, with
this moveset. That is the result, and it agrees with the table: none of
them guessed the player much better than the others.

## Inference costs nothing a frame would notice

Measured headless on an AMD Ryzen 5 9600X on 2026-10-15
(`make test-inference-budget`), on the owner's published player: the
softmax **0.007 ms** a decision, the exact ghost **0.002 ms**, the nearest
ghost **0.094 ms** -- it compares with every one of the 212 situations met, so it grows with the recordings.
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
- **Why they could not be told apart.** The manual check, played by the
  owner on 2026-10-15: *the clone, the two ghosts and the learner could not
  be told apart much*; only the fixed hard opponent felt a little harder
  than the rest, and all of them still very easy. The owner's own guess is
  the game rather than the AI -- the fight has no evade, so there are few
  choices for any of them to differ in. That was not measured: whether a
  richer moveset separates them is open.
- The win rates are measured against one opponent at one level, and only
  re-measured when the published file changes -- a change to the game's
  rules leaves them stale until `make test-clone-fights` runs again.
