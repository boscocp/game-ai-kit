# Review: wave/24-a-board-you-can-read

Two fresh contexts reviewed it, each in its own git worktree. One read the
code and attacked the tests with mutations. The other never read the code
for meaning: it took screenshots with a real window and judged each screen
as a first-time player would. They agreed on the worst finding from opposite
ends. On blue's turn, the board marked one unit as "in hand" while the
status named another.

## What was reviewed

Commit 35c19f1 on this branch:
- `godot/game/board_view.gd`: 48 px tiles, the palette, the grid, the costs,
  the reachable overlay, and the centring helper;
- the layout and status in `godot/game/main.gd` and `main.tscn`;
- the legend and comparison in the search demo;
- the stealth scene moved so it still fits;
- the new tests and `docs/godot/drawing-over-tiles.md`.

## Findings

### Must fix

- **The overlay could be deleted with every test green.** The cost test
  checked `cost_label()`, not what is drawn. Nothing at all checked the
  reachable cells once they stopped being a tile. The commit message said
  each defect had a test that goes red without it. For the overlay, that was
  false.
- **Blue's turn marked the wrong unit.**
  - Blue's first unit got the white ring and the reachable tint while the
    status said its second unit was deciding.
  - The tint and the plan were both light blue, so blue's steps read as the
    player's.
- **Refusals named cells nobody could find.**
  - "(9, 6) is occupied" pointed at a board with no coordinates.
  - The far-click refusal still said routes "arrive with ai_search in T3",
    which is out of date and developer talk.
- **A spent unit was told to click a highlighted cell** when none was
  highlighted.
- **The plan's number was unreadable.** It was 14 px light blue on green,
  over the unit's ring, and the route was drawn across the unit's id.
- **The search comparison misled.** Counting only expanded cells made
  depth-first look second best, when its route costs twice as much.

### Could be better

- **Layout untested.** The status and legend placement had no test.
- **A possible leak.** `_marks` was created in a member initialiser, so a view
  that never entered the tree leaked it.
- **A failure listed as a move.** "blue cannot think" appeared under "blue
  has played", where it read like a move.
- **The search legend.**
  - The yellow frontier outline vanished on tan mud.
  - The "ring" entry showed a filled square.
- **Small readability points.** A comment paraphrased its code, a doc said
  what and not why, a test compared a constant to 48, and there were extra
  blank lines.
- **Typed positions.** The search demo and the stealth room are still placed
  with a typed `position`.
- **Units cover numbers.** A unit standing on rough ground hides that cell's
  cost.
- **The status opens at "turn 0".**
- **Stealth sizes.** Stealth's guard markers keep their 32 px sizes.
- **No combat.** "unit 3 attacks unit 2" changes nothing, because the board
  has no combat model.

## What was done about them

Fixed on this branch:

- **The overlay is data now.**
  - `BoardView.marks()` returns the reachable cells and the costs, and
    `_draw_marks` draws exactly that.
  - Tests hold both, and a third holds that the overlay is drawn on the
    `Marks` child with `BoardView` defining no `_draw` of its own. Moving it
    back would make it invisible again.
  - `_marks` is made in `_ready`.
- **Blue has nothing in hand.** No ring and no tint on blue's turn. A test
  steps to blue's second decision and checks the selection is empty, there
  are no reachable cells, and the status names the unit actually deciding.
- **Coordinates and wording.**
  - Column numbers above the board and row numbers to its left, so every
    `(column, row)` on the screen can be found.
  - The far-click refusal names the cell and says what to do instead.
- **One instruction per state.** No unit in hand, a spent unit, a unit that
  can step, and blue deciding each get their own. A test walks a unit until
  it is spent.
- **The plan's number** is 18 px, white on a dark outline, above the deciding
  unit. The route starts at the unit's rim.
- **The search demo.**
  - The comparison shows cells expanded *and* route cost for all four.
  - The frontier is pink.
- **Layout and legend.**
  - A test holds that the status and legend sit inside the window, beside
    the board and level with its top.
  - "blue cannot think" now sits under "blue this turn".
  - The ring's legend entry is words only.
- **Readability nits** fixed. The constant test now checks the tile set.

Each new test was mutation-checked: its rule was removed and the suite went
red, 7 out of 7 cases.

Not fixed, on purpose:
- **Combat** belongs to T10, the tactical scenario. "attacks" stays the
  policy's word for what it chose, and the board has no health to show it.
- **The typed `position`** of the search and stealth scenes, and stealth's
  32 px guard markers. T8 names only the main board. The search demo fits
  as it is, and stealth was moved by hand so it still fits. That will break
  again the next time `TILE_PIXELS` changes. T24 lays every example out in
  one window, so it is the natural place.
- **Turn numbering** counts each side's turn, so red plays turns 0, 2, 4.
  That is `BoardState`'s rule, and the tests depend on it.
- **A unit covering its cell's cost.** Units are drawn after the board, and
  moving them under the numbers would hide the units instead.

The fixes were not re-reviewed by a third context. They were re-screenshotted
and every gate is green.
