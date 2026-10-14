# Review: wave/29-the-tactical-game-against-the-computer

One fresh context reviewed it, in its own git worktree, detached at the
feature commit. It read the task, the diff and the docs. It played games
headless, with red only ending its turn, measured the header and the status
against their labels, and ran 26 mutations.

## What was reviewed

Commit 43a8f37 on this branch:
- `godot/game/tactical/`: the scene rewritten for red against the computer,
  and the new types around it:
  - `BlueController`, `RuleBasedBlue`, `BlueTurn` and `TacticalDecision`;
  - `TacticalTurn` (spent units and undo), `TacticalVictory` and `IntentView`;
- the greying added to `godot/game/unit_view.gd`;
- `godot/test/tactical_game_test.gd`, the changed scenario test, the overlay
  gate's new entry, and the README, the examples table and the Makefile.

## Findings

Of 26 mutations, 12 were killed and 13 survived; one was not a valid
mutation.

### Must fix

- **Blue never won**, so "a game ends" was not true. It aimed at the nearest
  red piece, which is the bolt tower. After 60 rounds there were thirty blue
  shields round it, the workshop two cells away was untaken, and every walk
  said "stays". There was also no round limit.
- **Red's units were never shown to be fresh at red's next turn.** Deleting
  `_turn.begin()` left every red unit spent for good, with all 57 tests green.
- **After the game ended at the hand-off**, blue's next move was still drawn
  in pink, and the overlay still reported it.

### Should fix

- The turn starts with a unit in hand, so the first click on it made it wait.
- Building with a spent walker in hand blamed the workshop.
- A boxed-in or penniless workshop said "nothing beats any red piece".
- The win rule was on screen only once somebody had won.
- Blue's turn took one press per piece, holds included.
- Surviving mutations:
  - a wait not remembered for undo;
  - the end-turn question not cancelled by build, undo or the forge;
  - "making for the bridge" always said;
  - greying never drawn;
  - the overlay's `played` field;
  - the status dropping blue's reason;
  - undo not re-selecting a unit;
  - `BlueController.choose` never called.
- Three doc comments said something untrue: two floods where there are
  three, "within walking reach" for "reachable at all", and a doc on the
  wrong declaration.

### Notes

- Undo is a stack, not "any move". Holds included, blue is shown one
  decision at a time.
- The header's second line was 1197 of 1232 px.
- Checked and fine:
  - `winner` is never overwritten;
  - R in the middle of blue's turn;
  - input during blue's turn;
  - a queued unit that is gone;
  - a unit built this turn;
  - the docs, apart from "a game ends".

## What was done about them

- **Blue walks every unit at red's workshop**, and against a red that only
  waits it wins in round 5. This departs from T30's "nearest enemy". The
  departure is written in the task file, the class header and STATUS, for
  the owner to keep or overrule.
- **A game ends.** After 40 rounds it is a draw, and taking the workshop on
  the last turn still wins.
- **The win rule is on the header** from the first frame, provisional and
  all, and the header is three lines, the widest 1007 px. The controllers
  still to come moved to blue's status.
- **A finished game shows no next move.** `_blue_thinking()` is the one test
  for that, and the guard at the hand-off that duplicated it was removed.
- **Waiting is W**, so a click only picks a unit up. Undo puts the unit it
  took back into your hand.
- **Smaller fixes:**
  - building with a walker in hand lets the board's own refusal speak;
  - a workshop that builds nothing says why: room, funds, or nothing worth
    building;
  - enter plays the rest of blue's turn;
  - the doc comments are corrected.
- **Tests:** one for every survivor that is not equivalent, with greying
  checked through `UnitView.colour_for`. Others:
  - a full game against a waiting red ends in blue's win before round 10;
  - the draw;
  - a finished game drawing nothing;
  - `choose()` answering legally.
- **Re-run:** the 13 survivors and the new rules were planted again. All
  went red except the redundant guard, which was then removed.
- **Left:** the `_remaining` correction and `<` against `<=` change which
  cell is chosen only at ties near trees, and no test pins them. The skip of
  a queued unit that has gone cannot happen before T26 has units die.

The fixes were not reviewed by a second fresh context.
