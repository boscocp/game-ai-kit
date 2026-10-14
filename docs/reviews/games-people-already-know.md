# Review: tasks/games-people-already-know

A planning branch: six new task files (T27-T32), and edits to T9, T11, T12,
the README tier table and `tasks/STATUS.md`. One fresh context reviewed it in
its own worktree. It read the invariants, the gates the tasks name, and the
tasks they overlap. It ran `make wave-next` (which picks T27, as intended)
and `make check` (green).

## What was reviewed

Commit 3eaa2dc. The later commits on the branch came after the review was
launched, and are not covered by it:
- the model research in T31, with the owner's pick of FLUX.2 klein 4B and
  Z-Image-Turbo kept in reserve;
- `.claude/worktrees/` in `.gitignore`.

## Findings

### Must fix

- **Two gates would have passed vacuously** (invariant 4):
  - `make lint-no-training` is hard-wired to `ai_learning`'s
    `weights.json`, and matches only assignments to `weights` or `bias`.
    MENACE's beads (T28) and the checkers weights (T32) would pass it
    unchecked.
  - `make test-vectors` is a fixed list, so checkers vectors would never
    have run.
- **T28's shared vector was not feasible.** "Same move from the same seed"
  across Godot (PCG32) and Python (Mersenne Twister).
- **T27's lookahead test could not fail.** "At depth 1 the AI takes a free
  piece" holds for any AI when captures are compulsory.
- **T31's licence rule was not decidable**, and could misfire:
  - "a generated PNG outside the examples directory" looks the same as a
    CC0 PNG;
  - T9's rule would fire on a user's gitignored generated directory.
- **T31 claimed invariant 8 without holding it.** pip, Hugging Face and
  torch cache under `~/.cache` by default.
- **T32's facts about Samuel were wrong or overstated:**
  - the program predates 1959, which is the paper's year;
  - piece advantage was fixed, not learned;
  - he is credited with popularising the phrase, not proven to have coined
    it;
  - his method backed up search values, which is not T32's method.
- **T28's spec was incomplete.** Michie's draw reward and empty boxes were
  missing, and "never loses to a random player" is not decidable with
  random draws.
- **Claims with nothing behind them:**
  - T27 and STATUS promised a T26 change that T26 does not contain;
  - T30 promised a role in T11 and T12 that neither task gave it.

### Could be better

- **T27:**
  - the readability allowlist claim was wrong;
  - the draughts rules were underspecified;
  - the minimax-against-alpha-beta test needed tie-breaking;
  - nothing executable checked the `make run` switch;
  - the Files list was incomplete.
- **T29** was sized S for M's work, and two of its tests were ambiguous.
- **T30's undo** had nothing to "act" with before T26.
- **T31's acceptance was weak:**
  - it did not run an import after generating;
  - it did not say how a build is exported;
  - `NOTICE` did not name the model.
- **The README contradicted T31** ("the art is committed").
- **T9's manual check** covered only the unit types.
- **CLAUDE.md still marks invariant 6 "none yet"** although
  `check_no_training.py` exists.

## What was done about them

All the must-fix findings and all the could-be-better ones are fixed in the
task files, except the last:
- **The gates.** T28 and T32 each extend `check_no_training.py`, with
  planted cases, and name `make lint-selftests`. T32 adds
  `test-checkers-vectors` to `test-vectors`' prerequisites.
- **T28's vector** carries the uniform draw as an input, and its strength
  test plays the most-beaded move over 1,000 seeded games. Michie's rewards
  (+3, +1, -1), resignation on an empty box, and the 304 boxes are written
  down.
- **T27:**
  - the lookahead test uses two captures, one losing the piece to a
    recapture, at depth 2 or more;
  - the full English draughts rules are written down, with tests for free
    choice among captures, crowning mid-jump, and the 40-move draw;
  - minimax and alpha-beta are compared under a fixed tie-break;
  - greps check `project.godot` and `demo-skirmish`.
- **T31:**
  - it calls the generator only through a `scripts/artgen` wrapper that
    sets the four cache variables, and `check_disk_layout.py` gains them
    with a planted case;
  - its licence rules read tracked files only, and require every committed
    PNG to be listed by file;
  - it imports after generating, states the export story, and names the
    model in `NOTICE`;
  - its acceptance shows that `make check` never reaches the generator.
- **T32** is now "after Samuel". It states what the 1959 paper did and
  asks for every claim to be checked against the paper. It is sized L, with
  a Python port, a rules vector, randomised openings and a shuffled-labels
  control.
- **Blue.** T30 makes blue a controller chosen among several (rules,
  planner, learned). T11 and T12 name the rule-based blue as their baseline
  and floor, and STATUS says this rather than promising a change to T26.
- **T29** is sized M, and every named board carries its own expectation.
- **The README** says the CC0 art is committed.
- **T9's licence rule** reads tracked files, by path. Its manual check
  covers checkers and tic-tac-toe, and a test holds the stable asset paths.

Not fixed:
- **CLAUDE.md's invariant table.** That file is the owner's, so it was left
  alone. It is reported to the owner.

The fixes were not re-reviewed.
