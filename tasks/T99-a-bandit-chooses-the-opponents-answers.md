# T99 — A bandit chooses the fighting opponent's answers, during one fight

Size: M · Prereqs: T37 · Files: `godot/addons/ai_bandit/`, `godot/test/ai_bandit/`, `modules/ai_bandit.json`, `python/gameaikit/bandit/`, `spec/vectors/bandit/`, `python/tests/`, `godot/game/fighting/`, `godot/test/fighting/`, `scripts/check_no_training.py`, `CLAUDE.md`, `docs/techniques/`, `docs/concepts/`, `Makefile`

## Goal

The owner, 2026-10-26, answering T73's question 3 -- bandits learn from
payoffs at game time; extend ADR 0016's exception to them, or leave them
out? -- "faz o recomendado pensando em didática de IA": do the
recommended, with teaching AI in mind. The question itself recommended
neither answer; ADR 0016's amendment of 2026-10-26 reads the owner's words
as **extend** -- a bandit fitted offline would lose the lesson, which is
exploration against exploitation while you watch -- and names this
bandit as one of the three components the exception covers, on its three
conditions: **counts only; empty at the start of every fight; rebuildable
from that fight's log**. The owner confirms that reading in this task's
review.

A bandit teaches exploration against exploitation (AIMA 4th ed., 17.3
Bandit Problems; GAP2 ch. 25 presents it for games). UCB1 plays each arm
once, then the arm whose mean payoff plus a confidence term is highest --
"the sum of two terms. The first term is simply the current average
reward. The second term is related to the size ... of the one-sided
confidence interval" [Auer, Cesa-Bianchi & Fischer 2002].

## Decisions written down first (the owner confirms in review)

- **Home: the fighting game's opponent** (T37), the roadmap's first
  suggestion. T37's opponent "names the situation it sees, draws one of
  that situation's options by weight" -- fixed weights. The bandit
  opponent keeps T37's situations, options, reaction and execution, and
  replaces the fixed draw with one bandit per situation whose arms are
  that situation's options. What it learns is which answer works against
  *this* person *in this fight*, beside T17's n-gram, which predicts what
  the person will do. The RTS commander's build orders are the named
  alternative; a match gives far fewer pulls.
- **The payoff**, in [0, 1] as UCB1 needs: the health difference over a
  fixed window of frames after the option ends, scaled by a fixed range;
  every constant in the fighting data.
- **A new technique addon, `ai_bandit`**: UCB1, and epsilon-greedy with a
  fixed epsilon for the comparison; arms are indices, payoffs floats, no
  fighting word inside (invariant 2). Python twin, vectors.
- **ADR 0016's three conditions, held**: the state is pulls and payoff
  **sums** per arm, and an arm's mean is computed when it is read
  (`sum / pulls`), never kept and updated in place -- the incremental
  `mean += (reward - mean) / n` is refused by the amendment, because it has
  the shape of a learning-rate step; `new_fight` empties it; a recorded fight replayed through
  a fresh bandit opponent seated on the same frame rebuilds the same
  counts, twice, compared (`FightReplay`, as T17's test does).
- **The gate**: this task writes **N13** in `check_no_training.py`, as the
  amendment specifies. It finds its targets as N9 does (`OPPONENT_ADDON`
  and `TABLE_HOLDERS_RE`): every file under `godot/addons/ai_bandit/`, and
  any GDScript that names the bandit's classes -- a script holding one by
  type. In those, no line writes a file, a `ConfigFile` or a resource, and
  no `+=` or `-=` multiplies or divides a difference. Planted: a bandit
  that saves its counts; one saved under another name from a script that
  holds it; an arm value moved by a learning rate (`* (a - b)`); an
  incremental mean (`(a - b) / n`).
- **What the amendment proposes for `CLAUDE.md`** -- invariant 6's row
  naming N9, N13 and N14 as ADR 0016's exceptions, by name -- is made here
  only once the owner confirms it in review; N9's docstring in
  `check_no_training.py` (which today calls the n-gram "the one exception
  to this invariant") says it is one of three.

## Steps

1. Read ADR 0016 and its amendment, `ngram_predictor.gd`, T37's
   `fight_opponent.gd` and T17's replay test.
2. Python: `python/gameaikit/bandit/` (UCB1, epsilon-greedy) and vectors
   -- a payoff sequence per arm and a seed in, the arm chosen each pull
   out; a test that UCB1's regret on a known two-arm problem grows
   slower than epsilon-greedy's over 10,000 pulls.
3. `godot/addons/ai_bandit/`, held to the vectors; its header says what it
   solves, the complexity, when not to use it, and cites the ADR.
4. `FightBanditOpponent` in `godot/game/fighting/`, a level in the
   opponent list ("bandit"); the replay test of condition 3.
5. N13 with its planted cases; N9's docstring; `CLAUDE.md`, as confirmed.
6. Measured, in the fighting page: against T18's stand-in players and the
   owner's recordings, the bandit opponent against T37's medium and hard,
   100 fights each; how many pulls it takes to settle on an answer.
7. The `ai_bandit` technique page, both languages; the literature page's
   bandit row names it.

## Acceptance

```bash
python3 -m unittest discover -s python/tests -t python -p "test_bandit*.py"
make test-bandit-vectors
make test-godot-some SUITES="test/ai_bandit test/fighting"
python3 scripts/check_no_training.py
python3 scripts/check_no_training.py --self-test
python3 scripts/check_addon_deps.py
python3 scripts/check_translations_docs.py
python3 scripts/check_literature_table.py
make lint-modules
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Fight the bandit opponent in `make demo-fighting` and keep answering one
situation the same way: does it switch to what beats you, and how many
exchanges does it take? Restart: has it forgotten?

How invariant 13 is met: the fighting panel shows, for the situation the
opponent just named, each option's pulls, mean payoff and UCB1 bound as
bars, the chosen one highlighted before it is played -- the bandit's
counts and the arithmetic that chose, live.

References, opened on 2026-10-26: AIMA 4th ed., contents (17.3)
<https://aima.cs.berkeley.edu/contents.html>; Auer, P., Cesa-Bianchi, N.,
Fischer, P. "Finite-time Analysis of the Multiarmed Bandit Problem."
*Machine Learning* 47, 2002, the main results and figure 1
<https://homes.di.unimi.it/~cesabian/Pubblicazioni/ml-02.pdf>.
