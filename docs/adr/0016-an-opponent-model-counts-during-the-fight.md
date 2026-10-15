# 0016 — An opponent model counts during the fight

Status: accepted · 2026-10-15 (decided by the owner for T17)

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
