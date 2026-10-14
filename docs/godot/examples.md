# What an example in this kit is

<!-- doc-meta
half_life: practice
verified_on: 2026-10-14
tier: 2
source: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html ; https://docs.godotengine.org/en/stable/classes/class_scenetree.html
invalidated_if: --headless starts rasterising, or a SceneTree script's added nodes become ready without a frame passing
teaches: none
-->

> An example is a window where you can watch the AI decide. This page is
> the convention every example follows, and the reason for each part.

Invariant 13 says every example can be watched, and shows the decision
rather than only the outcome. The kit had already been bitten twice without
it:
- the board could not be read at all (T8 exists because of this);
- the search demo drew over the one thing it existed to show.

## The examples, and what each one teaches

| target | the game | the technique | what is drawn |
|---|---|---|---|
| `make run` | checkers, you against white | minimax with alpha-beta (`ai_adversarial`) | every move white considered with its value, the one it will play in pink, the line of play it expects, the positions searched and the replies skipped |
| `make demo-skirmish` | the 12×8 skirmish board | logistic and linear regression (`ai_learning`), A\* routes (`ai_search`) | each blue unit's decision and the probability it was made on |
| `make demo-tictactoe` | noughts and crosses, you against MENACE | Michie's matchboxes, reinforcement learning trained in Python; minimax as the yardstick | each empty square's beads and chance before the draw, the bead drawn, and (M) what perfect play makes of each square |
| `make demo-search` | four searches on a board you can paint, and four named boards | BFS, DFS, Dijkstra, A\* (`ai_search`) | the expansion order, the frontier, the route |
| `make demo-tactical` | Advance Wars style tactics, you against blue | rule-based blue, chosen as a `BlueController` (`ai_core`'s `DecisionPolicy`); `ai_search`-style reach | blue's next decision in pink before it is played, with why; your spent units greyed |
| `make demo-stealth` | cross a hall unseen | sight and hearing (`ai_perception`), fuzzy suspicion (`ai_fuzzy`) | each guard's cone, suspicion and state |

`make run` is the project's main scene, so it names no scene in its recipe.
Until T27 it opened the skirmish board, which is now `demo-skirmish`.

## The five parts

1. **A make target.** `make run` opens the board, and every other example is
   `make demo-<name>` with a `##` line, so `make help` lists them all.
2. **The decision on screen.** Draw what the AI is reasoning *with*, not only
   what it did:
   - the search's next cell and its frontier;
   - a guard's cone, its suspicion and where the rules pull it;
   - the learned opponent's probability, in its own words.
3. **One decision at a time.** The root script offers `step_decision()`, and
   a key does the same: space in every example so far. A person can then stop
   on the frame where the AI surprised them and read why.
4. **A legend.** A `Legend` node (`res://game/legend.gd`) in the scene, with
   one swatch and a few words per colour on the screen.
5. **A manual check** in the example's task. It says what a person should be
   able to see, and what would count as failing.

The root script also offers `decision_overlay() -> Dictionary`. That is the
data the overlay draws, handed to a test rather than to the screen.

## What a command can check, and what it cannot

**What was measured, on the pinned engine:**
- `--headless` uses the dummy rendering driver, so nothing is rasterised,
  and no command here can look at a picture.
- A scene added to the tree from a `SceneTree` script's `_initialize` is not
  ready until the main loop has turned once. `is_node_ready()` is false
  straight after `add_child`, which is why `test/demo_overlays.gd` awaits a
  frame before asking.

**Each half has its own check:**
- **`make lint-demos`** (`scripts/check_demos.py`, no engine) holds the
  structure. Every example has:
  - one target with a help line, whose recipe opens a window (`--headless`
    is refused);
  - a scene that exists, with a node running the legend;
  - a root script with both functions;
  - a place in `SCENES` in `test/demo_overlays.gd` (a comment does not
    count).
  
  A scene on disk that offers `step_decision` with no target is a finding,
  and so is a Makefile with no example at all.
- **`make test-demo-overlays`** opens each example headless and takes three
  decisions. It fails on:
  - any engine error;
  - an overlay that did not change;
  - a field that holds nothing (an empty list, a list of empty words, an
    empty packed array, a NaN);
  - the field the example's task names being missing, or not a number where
    it must be one;
  - a legend line that says nothing, or runs off the screen.
  
  Each rule is first shown a planted example it must reject.

Neither one can tell whether a person can read the screen. That is each
example's manual check, and the question is the same for all of them: **can
you tell what the AI is about to do, and why, before it does it?**

## Adding an example

1. Add the `demo-<name>` target, with its `##` line.
2. Implement `step_decision()` and `decision_overlay()` on the scene's root
   script.
3. Put a `Legend` in the scene, and add the scene to `SCENES` in
   `test/demo_overlays.gd`.
4. Run `make lint-demos`. It names every part that is missing.
