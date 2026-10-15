# T17 — The opponent model

Size: M · Prereqs: T37 · Files: `godot/addons/ai_opponent/`, `python/gameaikit/ngram/`

## Goal

An AI that learns the player, during the match, from a frequency table.

Shipped fighting games mostly write their opponents by hand (T36's survey,
`docs/concepts/fighting-game-ai.md`); the n-gram predictor is the textbook's
answer to learning a player, and it is taught here because it works and
because **you can print it**. An n-gram over the player's recent actions --
"after a low kick, this player guards crouching 60% of the time" -- is twenty
lines and legible in a way no neural network is. T18 is the contrast.

From the survey, two things this task takes. In the research arena, an
entry that learned its model of the opponent **during** the fight, and
searched against its predictions, came second in 2019 and won in 2020. And a perfect
predictor is no fun -- a course built on the textbook says n-gram opponents
are often deliberately weakened -- so the prediction does not drive the
opponent directly: it chooses among T37's options, at T37's levels, under
T37's reaction time.

## Steps

1. An n-gram model over the input stream, with the order as a parameter. Order
   is the lesson: too low and it predicts nothing, too high and it never sees
   the same context twice.
2. Smoothing, so an unseen context does not produce a confident wrong answer.
   The simplest that works, named, with the reason it was chosen over the
   alternatives.
3. A decay, so the model follows a player who changes their habits. A model
   that averages the whole match is a model of a player who no longer exists.
4. The model is **visible**: the demo draws the table and the current
   prediction, and that drawing is most of this task's teaching value.
5. It implements `DecisionPolicy`. The game must not know whether it is playing
   a script, a table or a network.
6. The prediction feeds T37's opponent: the likeliest next action of the
   player picks which of the level's options to weight, and the level's
   reaction time still holds -- the model learns from what was on screen,
   never from a press it could not yet have seen.

## Acceptance

```bash
make test-godot
make test-python
make test-vectors
```

```bash
./scripts/godot --headless --path godot -s res://test/opponent_properties.gd
make test-ngram-vectors
python3 scripts/check_no_training.py
```

The property: against a scripted player with a fixed habit, the model's
prediction accuracy must rise above chance within a stated number of exchanges,
and the script asserts that number. "It learns" is not a claim a test can
check; "it beats chance within 40 exchanges" is.

Also assert that the decay works: after the scripted player switches habits,
accuracy must recover.

## Manual check

Play twenty rounds using the same opening every time, then change it. You should
feel the AI start punishing the habit, and then feel it adapt. If you cannot
feel either, the decay or the order is wrong.

## Decided on the way (2026-10-15)

- **Invariant 6 has one exception, the owner's decision: ADR 0016.** The
  n-gram counts during a fight in GDScript, because the task is a table
  that fills in while you watch. It starts empty every fight, replays from
  the input log, and is never written down; `check_no_training.py` N9
  refuses a file written from `ai_opponent` or an n-gram table saved from
  anywhere -- and, after the review, any file written by a script that holds
  a table (names `NGramPredictor` or `FightModelOpponent`), and a
  `ConfigFile` saved -- with planted cases for each, and for counting, which
  is allowed. It is a net, not a proof: a table can still be smuggled out
  under names the net does not know.
- **Not a `DecisionPolicy`**, for T37's reason: that interface is the
  board's. `FightModelOpponent` extends T37's `FightOpponent` and is seated
  behind the same `FightDelay`, so the game calls it exactly as it calls the
  fixed opponent.
- **The model** is `NGramPredictor` in a new addon, `ai_opponent`, knowing
  nothing of fights: actions are strings. Order is a parameter (the learner
  uses 2); smoothing is additive -- every action starts with one imaginary
  sighting in every context, Laplace's -- chosen over backing off to shorter
  contexts because it is one number you can work out by hand; decay
  multiplies a context's old counts each time it is seen again (the learner
  uses 0.8). `gameaikit.ngram` is the Python copy, and four vectors in
  `spec/vectors/ngram/`, written by an exact-fraction script, hold both.
- **What it watches** is the action read off your fighter as drawn, in the
  late frame it is handed: a move's height, a jump, a guard seen in
  blockstun, a crouch, a step in or out. A prediction weights the answers to
  the expected action among the level's options, and never adds an option
  the level does not have. The weight is 0 at chance and 8 when the model is
  as sure as its decay lets it be -- the predictor's `ceiling`, 6 in 16 at
  decay 0.8 and eleven actions. The first version measured against 1, which
  no decaying row can reach, and never leaned more than 2 (the review).
- **Easy and medium often have no answer to lean towards**: easy knows two
  options a situation, medium four, and against a high, a low, a crouch or a
  guard none of them may be an answer. The choice and the panel say "no
  answer among its options" then, rather than seeming to lean. Measured by
  the review, before the lean was rescaled (40 lancer mirrors each, wins
  for the AI, fixed against learner, against a scripted habitual player):
  low, high, throw at hard 5 and 10; throw alone at medium 8 and 12, at hard
  14 and 22; a low alone 0 and 0 at every level. Not measured again since.
- **The properties**, measured: against low, high, throw repeated, the
  medium learner is right 20 of 20 on actions 21-40, where chance is about
  7; after a switch to low, throw, high, 20 of 20 on actions 81-100. Planted:
  a model that never forgets gets 0 of those 20; one of order 1 gets 0 of
  actions 21-40 -- with no context, three actions seen equally often tie,
  and a tie goes to the first of them, high, which follows a low in this
  habit only once in three. (The first version blamed its decay; at decay 1
  it scores 0 too.) The habit is regular on purpose: the review measured
  that a habit with a repeated action, low, low, high, is predicted at about
  chance at order 2 and only learnt at order 3 -- the order lesson again.
- **The training mode** has three learner modes; the panel prints the
  table, what it expected at its last decision and after which context --
  the table moves every frame, the decision does not -- the context now,
  and how often it has been right.
- **Every fight starts with an empty table**, held two ways: the training
  mode seats a new learner on every restart, and `FightDelay` calls the
  opponent's `new_fight` when the fights it is handed stop following on, so
  a seat reused across a restart cannot carry a table over. Tested.
