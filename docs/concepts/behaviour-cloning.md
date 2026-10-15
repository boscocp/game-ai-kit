# Behaviour cloning: what a learned model buys over a table

<!-- doc-meta
half_life: concept
verified_on: 2026-10-15
tier: 1
source: https://www.gamedeveloper.com/programming/the-killer-groove-the-shadow-ai-of-killer-instinct
invalidated_if: the situation's features, the split, or the four methods compared change; or the published player becomes a person and the numbers here are not replaced
teaches: behaviour-cloning
-->

> Record a player, learn what it did in each situation, and play like it.
> Then ask the question the kit has been building towards: what did a
> learned model buy over T17's frequency table, and over a ghost that only
> looks things up?

**The numbers below are from a scripted stand-in, not a person.** The
pipeline has to run before anybody sits down to record, so three scripted
players with strong habits stand in (`godot/test/stand_in_player.gd`). A
stand-in's choices depend on the situation and a die, nothing else, so it is
easier to clone than a person by construction. These numbers say the
pipeline works. What cloning a person buys is the owner's recordings' to
say, and this page is replaced when they exist.

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

`python3 python/gameaikit/cloning/compare.py --report`, on the rushdown
stand-in: 6 recordings fitted, 2 held out (94 decisions).

| method | held-out accuracy | numbers | built in | beats medium |
|---|---|---|---|---|
| always the commonest | 44.7% | 1 | -- | -- |
| n-gram (T17) | 42.6% | ≤121 | nothing beforehand | 40/100 (as the learner) |
| ghost, exact | 55.3% | 207 | ~0 s | 87/100 |
| ghost, nearest | 53.2% | 207 | ~0 s | 92/100 |
| model, last action only | 50.0% | 110 | 0.35 s | -- |
| model, the situation | 55.3% | 341 | 0.65 s | 88/100 |
| the stand-in itself | -- | -- | -- | 72/100 |

The other two stand-ins, held-out accuracy only:

| | commonest | n-gram | ghost exact | ghost nearest | model, last | model, situation |
|---|---|---|---|---|---|---|
| turtle | 37.2% | 46.8% | 44.1% | 45.7% | 54.5% | 53.2% |
| jumper | 38.6% | 57.4% | 53.9% | 58.8% | 63.8% | 63.5% |

What this says, about stand-ins:

- **The model bought little over the ghost.** On the rushdown they tie; on
  the turtle and the jumper the model leads by a few points. 341 numbers and
  a gradient descent against a lookup table counted in a millisecond.
- **The situation bought little over the last action.** The model that sees
  only what the n-gram sees is within two points of the one that sees six
  features, on two stand-ins of three. Most of what is predictable here is
  in the sequence.
- **Fitting beforehand beats learning during, but not by much.** The
  n-gram starts every fight knowing nothing and is still within a few points
  of the fitted models on two stand-ins of three.
- **A clone beats its own player.** The rushdown wins 72 of 100 against the
  fixed medium opponent; its clones win 87 to 92. The stand-in fumbles one
  press in ten and its clone fumbles none: imitation copies the choices, and
  the execution is the opponent's own. A Shadow that was better than you is
  a known complaint, and here is one way it happens.

So the honest answer, so far: **not much, here.** Six words and eleven
actions are a small space, and a ghost covers most of what a player meets
in a few fights. A learned model earns its numbers when situations are too
many to have met -- many features, or numbers rather than words -- and that
is the point at which this kit would reach for one.

## Inference costs nothing a frame would notice

Measured headless on an AMD Ryzen 5 9600X on 2026-10-15
(`make test-inference-budget`): the softmax **0.007 ms** a decision, the
exact ghost **0.002 ms**, the nearest ghost **0.063 ms** -- it compares with
every one of 140 cases. The budget is 1 ms, a sixteenth of a frame. This is
the only machine the owner had to hand; the slowest machine available was
this one.

## What is not proven

- **Anything about a person.** See the top of the page.
- **Whether a person can tell them apart.** The manual check: play the
  clone and the ghosts, and the learner. If you cannot tell them apart, that
  is a result and it goes in the README beside the technique.
- The win rates are measured against one opponent at one level, and only
  re-measured when the published file changes -- a change to the game's
  rules leaves them stale until `make test-clone-fights` runs again.
