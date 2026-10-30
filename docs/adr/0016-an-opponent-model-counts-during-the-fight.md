# 0016 — An opponent model counts during the fight

Status: accepted, amended · 2026-10-15 (decided by the owner for T17;
extended by the owner on 2026-10-26 to bandits and to player modelling,
the amendment confirmed by the owner on 2026-10-29 -- see the amendment at
the end)

## Context

Invariant 6 says there is no training at game time: Python fits and emits
numbers, GDScript only multiplies by them. Its reason is written in
`check_no_training.py`: a model fitted inside the game is one nobody can
reproduce, and the first symptom is an opponent that plays differently on
two machines and identically to no recorded version of itself.

T17 asks for the one kind of learning a fighting game is known for: an
opponent that learns *this* player, *during* the fight, from a table of what
the player did after what (T36's survey: an entry that modelled its opponent
during the fight came second in the research arena in 2019 and won in
2020). Fitted offline, from logs, it would learn some other player, earlier.
The task's point is the table filling in while you watch.

The invariant and the task disagree. The owner decided for the task, with
this record, and with the line drawn where the invariant's reason is.

## Decision

An n-gram table in `godot/addons/ai_opponent/` may count during a fight,
because what it does is not the thing invariant 6 exists to stop:

- **It is reproducible from the input log.** The table holds counts of what
  was on screen, nothing else: replaying the log through a learner seated
  on the same frame, at the same reaction, rebuilds the same table -- the
  log alone does not say when a learner was seated, nor at which level, and
  the training mode can seat one mid-fight. Two machines cannot disagree
  about it unless they disagree about the fight, and `FightReplay` already
  holds them to the same fight. A test plays the recorded fight twice
  through a learner and compares the tables.
- **It starts empty every fight and is never written down.** No file, no
  carried-over table, no published weights for a later fight to load: a
  restart seats a new learner, and a seat that sees the fight start again
  tells its opponent to forget (`FightOpponent.new_fight`). It forgets the
  player when the fight ends, so there is no model "of no recorded version
  of itself" to ship.
- **It counts; it does not descend.** There is no loss, no step size and no
  gradient. What it knows can be printed as a table and read, which is the
  lesson.

The rest of invariant 6 stands unchanged: every fitted number -- weights,
beads, evaluations -- is still Python's.

`check_no_training.py` gains **N9**: nothing in `ai_opponent` writes a file,
no script that holds a table writes one, and no line names an n-gram table
it writes. Its planted cases save a table from the addon, from a script that
holds a learner under another name, and through a `ConfigFile`. Like N1 to
N3 it is a net for the common spellings, not a proof.

## Alternatives considered

- **Fit the n-gram offline, from logs, and only read it in the game.**
  Rejected by the owner: it keeps the invariant whole and loses the task --
  the table would describe a player from before the fight.
- **Drop T17 until the invariant is rethought.** Rejected: the invariant's
  reason can be kept exactly, as above, without dropping it.

## Consequences

- The first GDScript in the kit whose numbers change while a game runs.
  The ADR, N9 and the n-gram's header say where the line is.
- T18's learned models stay on the Python side; only the n-gram counts.

## Amended by the owner (2026-10-26): bandits and player modelling

T73's roadmap (`docs/concepts/the-literature-and-the-kit.md`, questions 3
and 4) asked whether two more things that learn while a game runs could
come in under this record. The owner answered both on 2026-10-26:

- **Bandits** (question 3, which offered two answers -- extend the
  exception on its three conditions, or leave bandits out -- and
  recommended neither): "faz o recomendado pensando em didática de IA" --
  do the recommended, with teaching AI in mind. Read as: **extend**. A
  bandit fitted offline would teach the arithmetic and lose the lesson,
  which is exploration against exploitation happening while you watch;
  roadmap entry A.6 had already said it "needs a new decision by the owner
  extending ADR 0016 to it, on the same three conditions". The reading is
  this record's; the owner confirmed it on 2026-10-29, as recommended.
- **Player modelling for difficulty** (question 4): option 3 -- extend
  this record to it on the same three conditions, rather than leave it out
  or allow only a model fitted in Python and shipped fixed.

### What is covered: three components, by name

The exception is not a class of components. It covers exactly these, and
anything else that counts during play needs its own decision by the owner:

| component | where | rule |
|---|---|---|
| the n-gram opponent model (T17) | `godot/addons/ai_opponent/` | N9 |
| a bandit choosing among an opponent's fixed options (T99) | `godot/addons/ai_bandit/` | N13 |
| the player model that sets difficulty in the bot match (T100) | its class in `godot/game3d/botmatch/` | N14 |

Each holds the same three conditions as the n-gram:

1. **It counts; it does not descend.** Its state is counts and sums of
   what happened -- pulls and payoff sums per arm, shots and hits, damage
   taken per encounter. A mean is **kept as a sum and a count and computed
   when read**; it is never updated in place. The incremental form
   `mean += (reward - mean) / n` is exact arithmetic for a mean, and it is
   still refused: it has the shape of a step towards a target
   (`x += rate * (target - x)` with `rate = 1 / n`), and a gate cannot tell
   it from one whose rate is a constant. A count discounted by a fixed
   factor, as the n-gram's decay does, is counts. A value moved a step
   towards a target, an Elo or TrueSkill update, a weight with a gradient:
   those are descent, and stay Python's.
2. **It starts empty every fight or match, and is never written down.** No
   file, no table carried into the next fight, nothing loaded at start but
   fixed constants. A restart or a new match seats a new one.
3. **It can be rebuilt from that fight's log.** Replaying the fight's or
   match's log through a fresh component rebuilds the same counts, and a
   test does it twice and compares them. Where a game has no log of its
   own yet, the task that brings the component in writes one -- the
   events the component counts, in order -- under ADR 0017's rule that
   nothing is recorded unless asked.

What a bandit and a player model are, here:

- **A bandit** (AIMA 17.3) chooses among a fixed set of options by their
  payoffs so far. UCB1 [Auer, Cesa-Bianchi & Fischer 2002] is counts and
  sums with a fixed constant, and so is epsilon-greedy with a fixed
  epsilon.
- **A player model for difficulty** estimates how well the person is
  playing from counts -- a hit rate, damage taken -- as Hamlet models the
  damage a player takes as a distribution [Hunicke & Chapman, undated],
  and a fixed table turns the estimate into the opponents' knobs
  (accuracy, as GAP3 ch. 33 tunes it). It never outlives the match, so it
  is a reading of this person now, not a profile.

### What `check_no_training.py` must then allow and still refuse

N9 stays as it is. Two rules join it, each with planted cases it must
reject (invariant 4), written by the task that brings its component in.
Each finds its targets the way N9 does (`OPPONENT_ADDON` and
`TABLE_HOLDERS_RE` in `check_no_training.py`): every file under the
component's folder, plus any GDScript anywhere that names the component's
class -- a script holding an instance by type.

- **N13 -- the bandit** (written by T99): in those files, no line writes a
  file, a `ConfigFile` or a resource; and no line moves a field it keeps
  by a step towards a target -- `+=` or `-=` with a right-hand side that
  multiplies or divides a difference (`* (a - b)`, `(a - b) / n`).
  Planted: a bandit that saves its counts; one saved under another name
  from a script that holds it; one whose arm value moves by a learning
  rate (`*`); one that keeps an incremental mean (`/ n`).
- **N14 -- the player model** (written by T100): the same refusals for the
  player model's class and the scripts that hold it, plus no line that
  loads its state at start -- a model read back from `user://` would be a
  profile, and a profile outlives the match. Planted: a saved model, a
  model loaded at start, an Elo-style update, an incremental mean. **The
  match's event log is not an N14 finding**: it holds events, not counts,
  is written only when the match is opened with `-- --record` (ADR 0017),
  and is what condition 3 replays. N14 reads the player model's files and
  holders, and the log's writer is neither.

Both stay what N1 to N3 and N9 are: a net for the common spellings, not a
proof. Condition 3 is held by each task's replay test, not by the gate.

**Confirmed by the owner on 2026-10-29, as recommended**: invariant 6's
row in `CLAUDE.md`, "its one exception, ADR 0016, is N9", becomes "ADR
0016's exceptions, by name, are N9, N13 and N14"; invariant 6's text names
the bandit and the difficulty model beside the opponent model; and
`check_no_training.py`'s docstring for N9 says it is one of three. The
change is made by the tasks that bring the rules in, not before: a gate
row naming a rule that does not exist yet would be false. T99 makes it
when it writes N13 -- the row naming N9 and N13, the text the bandit, N9's
docstring one of the exceptions -- and T100 completes it when it writes
N14.

### What is still refused

Everything this record did not already allow: fitting weights, beads or
evaluations in GDScript (N1 to N8, N10 to N12); any count that survives
the fight; a learning rate, a gradient, a loss; any fourth component that
counts during play, until the owner decides it. Q-learning or any
temporal-difference update at game time stays out -- it is a step towards
a target even when written with counts -- and an MDP's policy (T98) is
solved in Python and shipped, like every other fitted number.

### References for the amendment

Opened on 2026-10-26.

- Auer, P., Cesa-Bianchi, N., Fischer, P. "Finite-time Analysis of the
  Multiarmed Bandit Problem." *Machine Learning* 47, 2002; the
  introduction and UCB1's statement (figure 1, theorem 1).
  <https://homes.di.unimi.it/~cesabian/Pubblicazioni/ml-02.pdf>
- Hunicke, R., Chapman, V. "AI for Dynamic Difficulty Adjustment in
  Games"; the abstract and introduction (Hamlet, built on Valve's Half-Life
  engine, models the damage a player takes as a distribution).
  <https://users.cs.northwestern.edu/~hunicke/pubs/Hamlet.pdf>
- Ocio Barriales, S. "Using Your Combat AI Accuracy to Balance
  Difficulty." Game AI Pro 3, 2017, ch. 33 (cited by T73).
  <http://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter33_Using_Your_Combat_AI_Accuracy_to_Balance_Difficulty.pdf>
