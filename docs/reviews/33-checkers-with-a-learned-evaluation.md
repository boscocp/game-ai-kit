# Review: wave/33-checkers-with-a-learned-evaluation

One fresh context reviewed it, in its own git worktree, detached at 9718b4f;
the base is c624388, the merge of wave 32. It read CLAUDE.md, T32 and its
notes, the concept page, the diff and the OCR of Samuel's 1959 reprint. It
ran `make check` and each T32 acceptance command. It cross-checked the
Python and GDScript rules, counts and alpha-beta choices on 20,259
positions, re-ran the match under other seeds, depths, weights and
shuffles, and ran 27 mutations. A worktree has neither
`godot/addons/gdUnit4/` nor `scripts/forbidden-term-hashes.txt`; both were
copied in read-only, and the scratch files were deleted afterwards.

## What was reviewed

Commit 9718b4f:
- `python/gameaikit/checkers/` and `python/tests/test_checkers.py`;
- `spec/vectors/checkers/`, `checkers_vectors_runner.gd` and
  `checkers_learned_test.gd`;
- in `godot/game/checkers/`: the evaluation, the weights reader, the game,
  the E toggle with `why()`, and the panel's breakdown;
- `checkers_weights.json`, N7 and N8 in `check_no_training.py`, the
  Makefile, the README row and the T32 notes.

## Checked and true

- `make check` and every T32 acceptance command passed.
- **The two languages agree** on 20,259 positions, from 150 random games and
  300 king-heavy endings. That includes 19 at the 40-move limit and 2 king
  captures ending on their own square. Agreed on each:
  - the legal moves in order, `is_over`, `winner` and the three counts;
  - on 3,515 of them, alpha-beta's choice at depths 1-3 under both sets of
    weights, tie-break included: 21,090 searches with no divergence.

  The scratch runner was itself shown to go red on planted errors.
- **The vectors runner** exits 1 on a wrong case and 2 on a missing file, an
  empty case list or no argument.
- **Every number from the published file** on the concept page and in the
  notes matches it, and the match replays exactly.
- **The negative result is not a bug.**
  - The hand against itself scores exactly 0.500, so swapping colours is
    fair.
  - The learned weights score 0.085-0.14 at depth 2 under three other
    seeds, and 0.02 at depth 3.
  - With the advancement weight set to zero they score 0.53.
- **The paper's quotations** match the OCR.
- **Invariants 6 and 13** hold. On 120 decisions, the active column of the
  breakdown added up to the decision's value. The panel fits at depth 6
  with every footnote.

## Findings

Of 27 mutations, 24 were killed and 3 survived. Four more were caught only
by the 45-second N7, and one only by gdUnit, not by the vector.

### Must fix

- **The page explained a result the experiment does not isolate, and the
  control was not a chance baseline.**
  - Alpha-beta only compares scores, so it ignores the weights' scale. A fit
    to noise, about a hundredth the size, plays at full strength in whatever
    direction it points.
  - Men and advancement correlate at 0.889 in the rows, so a fit to noise
    tends to point men up and advancement down. Eight extra shuffles all
    did. Their depth-2 scores were 0.09 to 0.415, around the learned 0.125.
    Shuffle 5001 reproduced the learned results almost exactly.
  - So the match cannot tell weights fitted to results from weights fitted
    to noise, and "no better than chance" cannot fail where it matters.
  - The men weight's sign cannot be read alone: men correlate at −0.174
    with winning, and the fit gives them +1.72 only beside advancement's
    −2.43.
  - The kings explanation is contradicted: with advancement zeroed, still
    valuing a king at a third of a man, the weights score 0.53.
  - The real mechanism was unstated. Under the learned weights a man three
    or more rows up is worth less than nothing. In 100 depth-2 games the
    learned side crowned 26 times to the hand side's 247.

### Should fix

- **Depth figures did not reproduce.** "46, 14, 11 of 60" comes out 41, 12
  and 18 with seed 1959. "0.28 over 30 openings" and "three other ways ...
  lost" had no seed or command.
- **The panel's "why" claimed too much.** It is one position under two sets
  of weights, not the difference between moves. Advancement was the largest
  gap in 110 of 120 decisions, and the evaluations chose differently in 46.
- **Samuel's target was misstated**: the comparison is with the backed-up
  score of the position one move later, not of the same position.
- **N8 had a hole.** `FileAccess.open(CheckersWeights.PATH, ...)` from
  outside the folder produced nothing, and a built path was reported as N2.
- **N3 survived**: `run()` ignoring that N7 could not run.
- **The rules vector compared notation only.** G9 (a jump that does not
  crown) passed it, and the vector could not express the 40-move rule or a
  king's capture back to its own square.
- **G7 survived**: `why()` replaying from the wrong board.
- **A test did not check what it named**, and P6, P7, P8 and P12 were caught
  only by N7.

### Notes

- A test comment's statistics were inverted. The standard error is
  0.02-0.03, so 0.6 is a fair bound, but on one replay.
- The "fixed by the experimenter" quotation is about the term's sign.
- The status line did not mention E.
- `CheckersWeights.read` crashed on `"learned": 3` and accepted string
  weights (G5).
- A missing file was read from disk on every refresh.
- "Will not push a man it could crown" was ambiguous.

### The mutations

| # | Mutation | Result |
|---|---|---|
| P1 | py: crowning does not end a jump | killed |
| P2 | py: capturing is not compulsory | killed |
| P3 | py: diagonal order swapped | killed |
| P4 | py: a man's move counts towards the draw | killed |
| P5 | py: advancement from the crowning row | killed |
| P6 | py: labels flipped | killed by N7 only |
| P7 | py: draws kept, labelled 0 | killed by N7 only |
| P8 | py: control not shuffled | killed by N7 only |
| P9 | py: match colours not swapped | killed |
| P10 | py: tie-break to the last equal move | killed |
| P11 | py: every game the same opening | killed |
| P12 | py: rows from the opening too | killed by N7 only |
| G1 | gd: advancement from the crowning row | killed |
| G2 | gd: every contribution uses the first weight | killed |
| G3 | gd: `read` accepts any feature order | killed |
| G4 | gd: `read` accepts any number of weights | killed |
| G5 | gd: `read` accepts non-numbers | survived |
| G6 | gd: E never switches | killed |
| G7 | gd: `why()` from the current board | survived |
| G8 | gd: `why()` counted for red | killed |
| G9 | gd: crowning does not end a jump | killed by gdUnit; vector passed |
| G10 | gd: ▶ on the wrong column | killed |
| N1 | gate: N8 branch removed | killed |
| N2 | gate: N7 compares only `learned` | killed |
| N3 | gate: `run()` ignores whether N7 ran | survived |
| N4 | gate: `run()` never calls N7 | killed |
| N5 | gate: N7 findings left tagged N4 | killed |

## What was done about them

- **The control and the page.**
  - Four shuffles are published, each a seed of its own, at both depths,
    together with an ablation: the learned weights with advancement set to
    0. At depth 2 the controls score 0.105, 0.21, 0.07 and 0.13. One of them
    points men down. The ablation scores 0.53.
  - The page has a new section, "Reading the controls". It says the search
    ignores scale, that a control is a random direction, and that this match
    cannot tell learned weights from noise. The no-better-than-chance test
    holds, and the page calls it weak.
  - "Why the learned weights lose" now separates what is measured (the
    ablation; an advanced man worth less than nothing; the review's crowning
    count) from what is a hypothesis (why the fit came out so). It says the
    weights cannot be read one at a time. The kings story is gone.
  - Numbers from the review are marked as the review's.
  - The pipeline now takes about two minutes, and the Makefile says so.
- **Depth figures** are re-measured with the seed stated: 41, 12, 18. The
  unreproducible claims are gone.
- **The panel's breakdown** says what it is, in the scene, the panel and the
  page: what the chosen value is made of, not why one move beat another. E
  is on the status line.
- **Samuel's target** is the position one move later. The quotation is said
  to be about the sign, with the paper's "other than the piece-advantage
  term" beside it.
- **N8** matches the file name, `CheckersWeights` and any path into
  `game/checkers/`, with planted cases for the class constant and for a
  built path. **N7 unable to run** now has a planted case: `run()` must exit
  3.
- **The rules vector** carries `crowns`, `taken` and `drawn`, and an
  optional `quiet_plies`. It has two new cases: a king's capture around four
  men back to its own square, and an 80-ply draw. Both languages check every
  field.
- **The tests**:
  - the label test is replaced by one that rebuilds the rows and labels from
    the games independently;
  - a control's labels must be the same labels in another order;
  - the ablation must be the learned weights with advancement at 0;
  - `why()` must stay with the decision after it is played, from a position
    whose line opens with a capture -- in a quiet opening the wrong board
    counts the same;
  - odd weights files must be refused.
- **Re-run as mutations, each now killed**: G5, G7, G9 by the vector alone,
  N3, the N8 hole, P6, P7 and P12, by `test-python` without N7.
- **`CheckersWeights`** no longer crashes on odd shapes, and reads a missing
  file once.
- **Left, on purpose:**
  - P8 (the control not shuffled inside `run()`) is still caught only by
    N7. The fast tests hold `shuffled` itself.
  - The panel does not draw the difference between the ends of two moves'
    lines. The page says that is where a choice is made.

The fixes were not reviewed by a second fresh context.
