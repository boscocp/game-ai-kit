# What an example in this kit is

<!-- doc-meta
half_life: practice
verified_on: 2026-10-13
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
  structure. Every example has its target, its help line, a scene that
  exists, a legend and both functions, and it is listed in
  `test/demo_overlays.gd`. A Makefile with no example at all is a finding.
- **`make test-demo-overlays`** opens each example headless, takes three
  decisions, and requires every field of the overlay to hold something. An
  empty list, a list of empty words or a NaN all fail.

Neither one can tell whether a person can read the screen. That is each
example's manual check, and the question is the same for all of them: **can
you tell what the AI is about to do, and why, before it does it?**

## Adding an example

1. Add the `demo-<name>` target, with its `##` line.
2. Implement `step_decision()` and `decision_overlay()` on the scene's root
   script.
3. Put a `Legend` in the scene, and add the scene to `SCENES` in
   `test/demo_overlays.gd`.
4. Run `make lint-demos`. It names the first part that is missing.
