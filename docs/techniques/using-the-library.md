# Using the library — the kit in a project of your own

<!-- doc-meta
half_life: practice
verified_on: 2026-11-04
tier: 2
source: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html ; https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html ; https://packaging.python.org/en/latest/tutorials/installing-packages/
invalidated_if: scripts/release.py changes what an archive holds, ADR 0024 changes the prefixed names, .godot-version moves, or scripts/library_check.py stops following one of this page's steps
teaches: none
-->

> Português: [using-the-library.pt-BR.md](using-the-library.pt-BR.md). The
> words that stay in English are in the [glossary](glossary.pt-BR.md).

This is the page to follow with a Godot project of your own, outside this
repository. Every step on it is one `make library-check` takes in a
throwaway folder that knows nothing of the kit, with the two examples
below as they are printed here: a step on this page that the check does
not take fails the check.

## What the library is {#what}

Two halves, each usable without the other.

- **Godot addons**, one zip each. `ai_core` is the kernel: a grid
  (`GakGridGraph`) and a pathfinder port (`GakPathfinder`), no algorithm.
  Every other addon is one technique -- `ai_search`, `ai_behaviour`,
  `ai_steering`, ... -- and depends on nothing but, at most, `ai_core`, so
  you take only what you use. The [catalogue](catalogue.md) says what each
  decides.
- **A Python wheel**, `gameaikit`, the techniques' twins in plain Python,
  standard library only: where the kit trains or checks something, and
  where you train for your game.

The names your own code types as a type carry the prefix `Gak`: the
ports you extend or implement and the kernel's grid (ADR 0024). The
algorithms keep their book names -- `AStarSearch`, `StripsPlanner`.

| name | addon | what you do with it |
|---|---|---|
| `GakGridGraph` | `ai_core` | fill it from your tiles |
| `GakPathfinder` | `ai_core` | ask it for a route |
| `GakSearchGraph` | `ai_search` | extend it for a map that is not a grid |
| `GakSearch` | `ai_search` | extend it with a search of your own |
| `GakAdversarialGame` | `ai_adversarial` | extend it with your game's moves |
| `GakGameDomain` | `ai_planning` | copy it to write your planning domain |
| `GakLlmRuntime` | `ai_llm` | extend it to reach your language model |
| `GakSteeringBehaviour` | `ai_steering` | extend it with a behaviour of your own |
| `GakRtsController` | `ai_rts_core` | extend it with your side's commander |

**Not in it**, on purpose: the examples -- the games under `godot/game/`,
the demos, the `board` kernel they share (ADR 0021) and the Python
packages the examples own (`checkers`, `menace`, `cloning`, `racing`, ...);
the art, which is not in this repository either; and the tests, which
stay here. A technique page that leans on one of those says so.

## In a Godot project {#godot}

### The archives {#archives}

<!-- library-step: release -->
Nothing is published yet, so the archives are built from a checkout:

```bash
make release
```

`dist/` then holds one `<addon>-<version>.zip` per addon and
`gameaikit-<version>-py3-none-any.whl`. On the day the kit is published,
the same files are what you download.

### Unzip one addon {#unzip}

<!-- library-step: unzip -->
Into your project's `res://addons/`: the addon you want and, if its
README says so, `ai_core` beside it. For a route, both:

```bash
cd my_game
unzip ai_core-0.1.0.zip -d addons/
unzip ai_search-0.1.0.zip -d addons/
```

There is no plugin to enable. Copying `godot/addons/ai_core/` and
`godot/addons/ai_search/` from a checkout gives the same files without
`VERSION` and the README; it is the alternative, not a different library.

### Let Godot register the classes {#import}

<!-- library-step: import -->
Every class in an addon announces itself with a `class_name` line, and
Godot keeps the list of those names in a cache under your project's
`.godot/` folder. The editor rebuilds it when it notices new files. A run
from the command line does not, and a script that uses a class the cache
has not seen fails with `Could not find type "GakGridGraph" in the current
scope` -- which reads like a typo and is not one. Once, after unzipping:

```bash
godot --headless --path . --import
```

### A first decision in your scene {#first-decision}

<!-- library-step: route -->
The `ai_search` page's minimal example, unchanged: attach it to any node
of a scene and run the scene; `route` holds the cells to walk. Here it is
not inside this kit -- the check puts it in a project holding nothing else
but the three addons, which is the proof that the zips are enough.

<!-- example: godot/test/ai_search/route_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_search.md, run by
# route_example_test.gd. A node of your own that finds a route across a
# board of its own as it enters the scene tree.
extends Node

## The route it found: the start left out, the goal included.
var route: Array[Vector2i] = []


func _ready() -> void:
	# Six by four, open ground, and a wall down column 3 with a gap at the
	# bottom -- the route has to find the gap.
	var board := GakGridGraph.new(6, 4)
	for row: int in range(0, 3):
		board.block(Vector2i(3, row))
	# Held as ai_core's GakPathfinder, so the caller does not care which search
	# answers: swap AStarSearch for DijkstraSearch and nothing else changes.
	var pathfinder: GakPathfinder = GridPathfinder.new(AStarSearch.new())
	route = pathfinder.find_path(board, Vector2i(0, 0), Vector2i(5, 0))
```

Every other technique page has its own minimal example in the same place,
under **In your own project**.

## The Python side {#python}

### Install the wheel {#wheel}

<!-- library-step: wheel -->
Python 3.12 or later, nothing else: the wheel has no dependencies, so it
installs with no index. In a virtual environment of its own:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install --no-index gameaikit-0.1.0-py3-none-any.whl
```

`from gameaikit import techniques` then lists what is installed,
`techniques.available()`. From a checkout, `pip install ./python` installs
the same package.

### Train in Python, decide in Godot {#train}

<!-- library-step: train -->
The kit learns in Python and only infers in GDScript (its invariant 6): no
weight changes while your game runs. A training script of yours fits a
model and writes it as a file; the game reads the file. This one fits "does
this attack win?" from eight fights, and is run from your project's folder:

```python
# Fit "does this attack win?" from a few fights, and write the model file
# the game reads. Python learns here; the game will only multiply.
import json

from gameaikit.training import descent, model_file

fights = [  # (my_health, their_health), and 1 when I won
    ([90, 20], 1), ([80, 40], 1), ([70, 30], 1), ([60, 50], 1),
    ([30, 80], 0), ([40, 90], 0), ([20, 60], 0), ([50, 70], 0),
]
rows = [row for row, _ in fights]
labels = [won for _, won in fights]
# Fit on standardised numbers, then fold the scaling back in, so the
# weights apply to raw health and the game needs no scaler.
means, deviations = descent.standardise(rows)
scaled = descent.apply_standardisation(rows, means, deviations)
weights, bias = descent.fit(scaled, labels, descent.logistic_prediction)
weights, bias = descent.unstandardise(weights, bias, means, deviations)

published = {"generated_by": "my_training.py", "models": {"chance": {
    "kind": "logistic", "features": ["my_health", "their_health"],
    "weights": weights, "bias": bias}}}
refused = model_file.why_wrong(published)  # the same rules the game applies
assert not refused, refused
with open("chance_model.json", "w", encoding="utf-8") as file:
    json.dump(published, file, indent=2)
```

<!-- library-step: infer -->
In Godot, unzip `ai_learning-0.1.0.zip` beside the others (it needs no
`ai_core`), import again, and a node of yours reads the file and multiplies:

<!-- example: scripts/library/chance_from_python.gd -->
```gdscript
# The second example on docs/techniques/using-the-library.md, run by
# scripts/library_check.py in a project that has never seen this kit.
# A node of your own that reads the model your Python side wrote, and
# only multiplies: nothing in the game changes a weight.
extends Node

## Where the training script wrote its file, run from the project's folder.
const MODEL_PATH: String = "res://chance_model.json"

## How likely a healthy attacker is to beat a hurt one, 0 to 1; NAN when
## the file was refused, which no threshold passes.
var chance: float = NAN


func _ready() -> void:
	var published: ModelFile = ModelFile.load_from(MODEL_PATH)
	if not published.is_loaded():
		push_warning(published.error)
		return
	var model: LearnedModel = published.model("chance")
	chance = model.predict_named({"my_health": 85.0, "their_health": 30.0})
```

Retraining is running the script again and shipping the new file. The
[ai_learning](ai_learning.md) page has the file's format and what refuses
it.

## Versions and the licence {#versions}

<!-- library-step: licence -->
- **Godot**: the kit is tested on the version in `.godot-version`, today
  4.7.2 -- the check below runs that one. An older Godot 4 is not tested.
- **The library's version** is in each zip's `VERSION` and the wheel's
  name -- 0.1.0 today. What it promises to keep is what ADR 0024 writes
  down: the nine `Gak` names above, which your code extends -- renaming
  one after a release breaks every game that does, which is why they are
  few. Below 1.0 any other name may still change between releases.
- **A name that collides with one of yours**: each zip's README says it --
  rename the `class_name` line, and its uses, inside that addon's folder.
  Nothing of yours changes.
- **Licence**: Apache-2.0. Every zip carries `LICENSE` and `NOTICE` beside
  its code, and the wheel carries both in its metadata. Whatever you
  redistribute that contains them keeps them -- a third-party-licences
  screen is enough. A credit in your game is asked, not required (the
  [README](../../README.md) says why).

## Deeper {#deeper}

- Why the names carry `Gak`, and why only the techniques ship:
  [ADR 0024](../adr/0024-the-library-prefixes-its-ports.md).
- What `ai_core` holds and why it is so small: [ai_core](ai_core.md).
- How an addon's files, `class_name` and `.uid` fit together in Godot:
  [godot/addon-anatomy.md](../godot/addon-anatomy.md).
