# Review: wave/26-checkers-and-minimax

Two fresh contexts reviewed it, each in its own git worktree. One read the
addon, the rules and the tests, and ran nineteen mutations against the suite.
The other never read the code: it played the scene with real rendering on a
display, as both sides, through a forced capture, multi-jumps, crowning, a
win and a loss, and judged it from the screenshots.

## What was reviewed

Commit 9955ed9 on this branch:
- `ai_adversarial`: `AdversarialGame`, `AdversarialResult`, `MinimaxSearch`,
  `AlphaBetaSearch`;
- `godot/game/checkers/`: the board, the move, the rules of English draughts,
  the evaluation, the adapter to the addon, and the scene with its view and
  panel;
- the three new suites, `make run` moving to checkers, `make demo-skirmish`,
  and `docs/concepts/minimax.md`.

## Findings

### Must fix

- **A king's capture back to its own square could not be played.** The last
  click lands on the king itself, which picked it up again. The game locked,
  with R the only way out. The rules mutation that dropped this case survived.
- **Free choice among captures was not playable.** A click named only the
  last square, so of two jumps ending on the same square the first was always
  played. The rules held the choice and the person could not exercise it.
- **A bound was written as "wins".** After a winning move alpha is a win, and
  a later move cut short comes back as "at most a win". The board and the
  panel said it won; measured, one such move was worth +8.55.
- **Which way pieces capture was untested.** Men capturing backwards and
  kings capturing forward only both survived, as did a king's capture back to
  its start. A piece jumped twice was caught only by a hang.
- **The 40-move test could not tell 40 from any other number.** It looped the
  constant it was testing.
- **The pruned count was half untested.** Only MIN positions were pinned.
- **The doc quoted numbers white never produces**, and said the cost grows by
  the branching factor per ply. Measured, it grows two to three times.
- **From the play review:**
  - the panel's footnote ran under the status bar, and off the window with
    ten moves listed;
  - value labels printed over each other ("≤ -0.C0.05");
  - a multi-jump could not be played hop by hop, and a click on the first
    landing was refused with a sentence that read as "that square is wrong";
  - a piece that could not move still got the selection ring, and the
    refusal stayed up after later clicks;
  - at depth 1 every move was marked "≤" although nothing had been cut, and
    values read "-0.00";
  - with white far ahead, it shuffled a king back and forth for seventy
    plies with nothing on screen saying why.

### Could be better

- One gold for a king, the chosen move and the selection; no legend line for
  the ring or the last move; no direction on the chosen line.
- Ties not explained: a "≤ +0.05" beside a chosen "+0.05" read as "worse".
- A single number did not say why: no line of play behind it.
- "White wins: you cannot move" when red had no pieces at all.
- A sideways click refused as "a man moves only forward"; a click off the
  board refused at all.
- The evaluation, the win's size, the draw's score and crowning resetting the
  quiet count were all untested.
- Wins are not depth-adjusted, so a win in one and a win in five are equal.
- Small errors: "seven rows earn 0.35" (six is the most), the alpha-beta
  trace is figure 5.5 not 5.2, an uncommented member block.

## What was done about them

Fixed on this branch:

- **The hand.** `CheckersHand` keeps the route clicked so far. A multi-jump
  is played one hop per click or straight to its last square, and only the
  moves following the route stay lit. Every open route is drawn and the
  pieces it takes are crossed out. A click on a lit square comes before
  "pick up your own piece", so a king's circular capture plays. Scene tests
  play both routes of a double jump to the same square, and the circular one.
- **"≤" is honest.** A root move at or below alpha is marked a bound only if
  the search below it actually cut something; at depth 1 every value is
  exact. A bound at a win reads "≤ wins: not looked at". Both are tested.
- **New rules tests:** men capture forward only, kings backwards too, a
  king's capture back to its start, no piece jumped twice, the 80 written
  out, crowning resets the count, the draw scores 0 with red a king up, the
  evaluation's three counts, and a win above twelve kings.
- **The pruned count at MAX positions** is pinned by a three-ply tree whose
  cut skips two leaves. The tree game is now any nested list.
- **The screen.**
  - The chosen move is a pink arrow; every considered move is an arrow.
  - Labels sit on dark boxes and move down until they overlap nothing.
  - The legend has the ring and the last move.
  - The panel lists moves best first, five at most, says "played" or "will
    play", explains "≤" and ties, and spells out **the line it expects** --
    the chosen move and each reply at the depth left, which is where the
    value comes from.
  - A test measures that the panel ends above the status line, and the
    status above the window's edge, with many moves at depth 6.
- **Words.** Refusals for a white piece, an empty square, an unfinished jump,
  a sideways click and white's turn. A click off the board does nothing.
  The end says "you have no pieces left" when that is why.
- **The shuffle** is made visible rather than cured: the status counts down
  to the 40-move draw, and the concept page has a section on the horizon.
- **Docs.** The numbers are ones white produces, with the 1828/545 pair
  labelled red to move; the growth is the measured two to three times; the
  lookahead paragraph says the tested position loses the game.

Every mutation the reviewer reported surviving was re-run against the new
suite, and each one now fails it: M3, M5, M6, M7, M9, M10, M12, M15 directly,
M8, M11 and M17 through the new tests aimed at them.

Not fixed, on purpose:
- **Wins are not depth-adjusted.** `AdversarialGame.evaluate` does not know
  how deep it was asked, and adding that to the interface for one game is not
  this task's call. The horizon section names the cost, and T32 or T12 can
  take it up.
- **The shuffle itself.** Curing it needs an evaluation that knows how to
  chase, which is exactly what this one is deliberately not. It is the lesson
  the horizon section draws.

- **The search runs in the frame.** At depth 6 it was measured at 730 ms with
  four white kings in the open (360 ms in a game of men), and the expected
  line adds a shallower search on top. Depth 4, the default, stays near
  50 ms. A thread is the cure, and is left until a depth that matters needs
  it; the scene's doc comment says so.

The fixes were not re-reviewed by a third context. They were re-screenshotted
and every gate is green.
