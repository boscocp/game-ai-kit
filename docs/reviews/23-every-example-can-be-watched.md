# Review: wave/23-every-example-can-be-watched

Two fresh contexts reviewed it, each in its own git worktree, which was the
lesson of wave 22. One attacked the gate. The other read the three examples
as a person would see them, from the drawing code and from scenes driven
headless. Both found the same thing from opposite ends: the gate
accepted examples that did not show the decision, and one of the examples
was exactly that.

## What was reviewed

Commit 1c85662 on this branch:
- `scripts/check_demos.py` and `test/demo_overlays.gd`, the two halves of
  invariant 13's gate;
- the legend, step and overlay added to `make run`, `make demo-search` and
  `make demo-stealth`;
- `docs/godot/examples.md`;
- the CI wiring.

## Findings

### The board showed blue's decision only after playing it

One press ended red's turn, decided both blue units, played both moves and
handed the board back. Before the press, the overlay was empty. After it,
the units had already moved. T21's manual check asks whether you can tell
what the AI is about to do *before* it does it, and here you could not. The
probability lived only inside a sentence, and the overlay padded itself with
a constant `"deciding": "blue"`.

### The gate passed an example that crashed, or decided nothing

- **Crashes.** A step that raised a script error on every call passed with
  exit 0, because nothing counted errors.
- **Nothing decided.** A step that did nothing, with an overlay that never
  changed, also passed.
- **Packed arrays.** A packed array was never looked inside, so a route
  stored as an empty `PackedVector2Array` counted as something.
- **No per-example claim.** The spec says the frontier is there, and that
  the probability is a number. Nothing per example was asserted.

### The gate could be walked round

- **An empty recipe** borrowed the scene of the target below it.
- **A recipe with `--headless`,** one that only echoed the path, and a `run`
  that opened nothing all passed as "a window".
- **A comment.** Listing a scene in a comment in `demo_overlays.gd`
  satisfied the rule that it be listed.
- **Hidden targets.** `demo_racing:` and two targets on one line were
  invisible, and so was an example scene with no target at all.
- **A detached legend.** A legend declared and never attached passed, and
  so did functions written inside a string.
- **The editor's forms.** Legitimate scene forms the editor writes made the
  gate go red: `uid=` before `path=`, and `groups=` on the root.

### What a person would see

- **No ids.** The reasons said "unit 3" and "guard 2", and nothing on screen
  carried a number.
- **The legends:**
  - The board's legend called the selected-unit ring something else, and
    left out open ground.
  - The stealth legend ran 15 px off the screen. It called the suspicion bar
    white when it is drawn in the guard's colour, and left out the next-step
    dots, the last-known ring, walls and trees.
  - Every translucent swatch was painted over the window's grey instead of
    over the ground it sits on in the game, so it was a different colour.
- **The search drew its frontier only at the end,** although the frontier is
  what invariant 13 names.

## What was done about them

- **One decision at a time.** Blue's turn is played one decision per press.
  A unit decides, `PlanView` draws its route, the cell it ends on and the
  number it decided on, and only the next press plays it. Clicks are
  refused while blue is deciding. Each overlay entry carries `p_win` or
  `turns` as a number.
- **The engine half:**
  - it counts engine errors with a custom `Logger`, measured working on the
    pinned engine for script errors and `push_error` alike;
  - it requires the overlay to change across three decisions;
  - it looks inside every packed array;
  - it asserts each example's required field;
  - it checks that every legend line says something and fits on the screen.

  Each rule first rejects a planted example built in memory.
- **The structural half:**
  - it reads each recipe line by line and requires it to open a window;
  - it parses `SCENES` with comments stripped;
  - it treats any target spelled like an example as one, and refuses the
    malformed ones;
  - it finds example scenes on disk that no target opens;
  - it requires a node to run the legend;
  - it ignores functions written inside strings;
  - it reads scene attributes in any order.

  It went from 9 planted cases to 20.
- **On screen.**
  - Units and guards carry their ids.
  - The legends were redrawn against what is actually drawn, and paint a
    square of ground under every swatch.
  - The search derives its frontier at every step, and draws it. The
    derivation is held against the real final frontier of all four
    searches, which is how it can be trusted without changing `ai_search`.
- **Re-run.** Twelve mutations, across the examples and the checker's own
  rules, were run against the fixes. All twelve go red.

### Recorded, not fixed

- **`CLAUDE.md`'s invariant table** still says invariant 13 has no gate. It
  is the owner's file. The row can now read `check_demos.py` and
  `test/demo_overlays.gd`, with the seeing still a person's.
- **Lines over 100 characters.** No gate measures line width. That is still
  open, as it has been since wave 15.

### Not proven

- **Nothing in this repository can look at the screen.** For each example,
  can you tell what the AI is about to do, and why, before it does it? That
  is a person's question, and it is the manual check in T21.
- **The fixes in this record were not reviewed by a fresh context.**
