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
