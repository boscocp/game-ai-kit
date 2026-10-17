# Behaviour cloning: what a learned model buys over a table

<!-- doc-meta
half_life: concept
verified_on: 2026-10-16
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
2026-10-15 -- four against the fixed opponent at medium, one at hard, four
against the learner at hard; 10,685 frames, about three minutes of play,
450 decisions. That is still little, and the numbers below carry it. Before the
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

**Everything is as late as the game sees it**, `last` included. A cloned
opponent reads its own fighter off the frames `FightDelay` hands it, so it
knows what it was doing 15 frames ago, not what it is doing now; the rows
write `last` the same way (`FightRecording.last_seen`), and a test plays the
clone through a fight and checks every decision's `last` against the rows'.
An earlier version asked the clone with the option it had *drawn* -- 28% of
its decisions disagreed with the rows, mostly strikes out of reach that
came out as steps (the wave 42 review). The n-gram is scored the same way:
it guesses each action from what it had seen 15 frames before.

One difference is left: the rows hold one decision per *change* of action,
and the clone decides whenever its plan runs out, every 10 to 12 frames of
a walk or a guard. So it is asked "what next?" sooner than the player was.

The features are computed in GDScript only (`FightSituation`): Python never
sees a fight, only rows. So there is no second copy of the arithmetic to
drift, which T6 and T32 each needed vectors to hold together.

## A situation is six words

`last` (the last action this player was seen doing, as of the frame the
situation is read from -- what an order-2 n-gram seated as late sees),
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

`python3 python/gameaikit/cloning/compare.py --report`, on the owner. It
prints three views, because a held-out set of three fights can be decided
by one of them; the third is the one to read.

**Every recording held out once, fitted on the other eight** (450
decisions):

| method | accuracy |
|---|---|
| always the commonest (step in) | 28.0% |
| **n-gram (T17)** | **32.0%** |
| ghost, exact | 26.7% |
| ghost, nearest | 26.7% |
| model, last action only | 25.8% |
| model, the situation | 26.7% |

**The published split** -- 6 recordings fitted (317 decisions), 3 held out
(133), the fits the game ships:

| method | held-out | numbers | built in | beats medium |
|---|---|---|---|---|
| always the commonest | 21.1% | 1 | -- | -- |
| n-gram (T17) | 32.3% | ≤144 | nothing beforehand | 37/100 (as the learner) |
| ghost, exact | 20.3% | 267 | ~0 s | 70/100 |
| ghost, nearest | 21.1% | 267 | ~0 s | 71/100 |
| model, last action only | 21.8% | 156 | 0.38 s | -- |
| model, the situation | 21.1% | 432 | 0.67 s | 48/100 |

The fixed opponent at medium beats itself 33 times in 100 (a draw is no
win): that is the reference for the last column. These are against T40's
medium, retuned, with twelve actions counted. Against T37's medium they
were 40, 78, 86 and 64, and the reference 35.

What this says:

- **Nothing fitted beforehand guessed this player better than "always step
  in".** Not the ghosts, not the model, with six features or one. Nine
  fights is a few sightings of each of the situations met, and this player
  fights differently from fight to fight -- one held-out fight mostly
  stepping out, another mostly crouching.
- **The table that learns during the fight is the only one above the
  floor**, by four points over all nine fights. That is not much, and it is
  the only gain on the table. Each held-out fight alone (the report prints
  them) shows how much one fight moves it.
- **Guessing and fighting are different measurements.** The ghosts guess at
  the floor and beat medium 70 and 71 times in 100 (78 and 86 before T40
retuned it); the clone 48. A ghost
  replays whole answers the player actually gave; the model averages them
  into probabilities that are never quite any of them.
- **The first reading of these numbers was wrong.** Before the review's
  fixes, the page said the n-gram led by seven points on a split where one
  fight decided it, and scored the n-gram on the present while the models
  saw the past. Held to the same delay and to every fight in turn, the lead
  is four points and only the n-gram has one.

So the honest answer, for this player and this much data: **the learned
model bought nothing here.** T17's frequency table is the only method that
beat the floor, and a ghost is the better opponent. A model earns its
numbers with far more play, a player whose habits hold from fight to
fight, or situations too many to have met -- and this kit would reach for
one then, not before.

### The stand-ins: why a pipeline check is not a result

Every recording held out once, the same report on each scripted stand-in:

| | commonest | n-gram | ghost exact | ghost nearest | model, last | model, situation |
|---|---|---|---|---|---|---|
| rushdown | 46.6% | 42.4% | 48.7% | 47.3% | 46.6% | 51.5% |
| turtle | 38.5% | 29.9% | 35.3% | 35.1% | 38.5% | 39.1% |
| jumper | 39.8% | 30.3% | 36.8% | 36.4% | 39.8% | 41.5% |

On stand-ins the six-feature model is the best guesser every time, and the
n-gram the worst: a stand-in *is* a table of situations and a die, the
model's own shape, with no habit in its sequence. A person is not, and the
ranking turned over.

Against medium, published one at a time: the rushdown wins 72 in 100, and
its ghosts and clone 87 to 94 -- the stand-in fumbles one press in ten and
its copies fumble none. The turtle wins 30, its copies 19 to 24; the
jumper and every copy of it win none -- this opponent never jumps in with
an attack, so a jumper only jumps.

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
(`make test-inference-budget`), on the owner's published player. The lookup
alone: the softmax **0.007 ms**, the exact ghost **0.002 ms**, the nearest
ghost **0.094 ms** -- it compares with every one of the 212 situations met,
so it grows with the recordings. The whole decision the game makes -- the
fight read into six words, the lookup, the draw, the inputs -- on every
frame of a recorded fight: the clone **0.038 ms**, the ghosts **0.12 ms**
(the exact one pools all its play on a miss).
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
   passes, in a fixed order, its numbers rounded to six places so another
   machine's last bits cannot differ. `--check` fits again and compares the
   text exactly; N10 in `check_no_training.py`, inside `make check`, fits
   again and compares every number to a tolerance. `compare.py` fails if the
   published file was fitted on another split than the one it scores.
3. `make test-clone-fights` -- every fight is seeded, so the win rates
   repeat; the file names the sha256 of the weights and of the frame data
   it fought under. A change to an opponent's script is not hashed: rerun it
   after one.

`make train-clone` runs all three. The only number that varies between runs
is "built in", the seconds the fit took, which is printed and never stored.

## What is not proven

- **Anything about people in general.** One person, nine fights. Record
  more (`make record-fights`, then `make train-clone CLONE_PLAYER=person`)
  and the table here is replaced.
- **Why they could not be told apart.** The manual check, played by the
  owner on 2026-10-15: *the clone, the two ghosts and the learner could not
  be told apart much*; only the fixed hard opponent felt a little harder
  than the rest, and all of them still very easy. The owner's own guess is
  the game rather than the AI -- the fight has no evade, so there are few
  choices for any of them to differ in. That was not measured: whether a
  richer moveset separates them is open.
- The win rates are measured against one opponent at one level, in lancer
  and dancer mirrors -- and every recorded fight was the lancer against the
  dancer, so half the column is a matchup the player never played.
