# T58 — Modules, and gates that run for what a wave touches

Size: L · Prereqs: T20 · Files: `scripts/`, `Makefile`, `mk/`, `.github/workflows/ci.yml`, `godot/test/`, `modules/`

## Goal

The owner's request of 2026-10-20, after wave 62: the kit stays a set of
lessons on real games, but **every AI is a module that can be configured into
any game**, and **a wave tests and gates only the modules it changes, adds or
evolves** -- not the whole repository. Merges have grown slow and bureaucratic,
and time and tokens go on tests of things nobody touched.

This task is the plumbing that makes that true without giving up an
invariant: a module manifest, tests filed by module, a selector that reads
`git diff` and the dependency graph, and a `make check-affected` that a wave
runs instead of the whole of `make check`. The full check does not go away; it
moves to `main` and to the release, where it belongs.

The refactor of the modules themselves (ports, adapters, the registry) and the
library are **planned here and done in later tasks** -- see "The shape the
modules grow into" and "The library, later". Moving code and moving gates in
the same wave would make the review unable to tell a selector that skipped a
test from a refactor that broke one.

## Diagnosis (measured 2026-10-20 on `f0fbf9b`)

**D1. What `make check` costs, gate by gate.** Timed one target at a time on
the author's machine, nothing else running (`make <target>`, wall clock):

| target | seconds | module it belongs to |
|---|---:|---|
| `test-opponent-levels` | 165.5 | the fighting game (`ai_learning`, `game/fighting`) -- and not in CI (D3) |
| `lint-no-training` | 115.7 | global rules plus four refits from seed: tactical, MENACE, checkers, clone |
| `test-godot` (every gdUnit4 suite) | 44.2 | all of them, in one run |
| `test-rts-match` | 40.0 | `game/rts` |
| `test-models` | 27.6 | `gameaikit.training` |
| `test-rts-simulation` | 20.1 | `ai_rts_core` |
| `test-python` | 19.9 | all of `gameaikit` |
| `test-clone-report` | 16.1 | `gameaikit.cloning` |
| `test-difficulty-knobs` | 13.2 | `game/tactical` |
| `test-planner-benchmark` | 11.3 | `ai_planning` over `game/tactical` |
| `lint-employer-refs` | 10.8 | global (every blob in history) |
| `test-planner-properties` | 8.7 | `ai_planning` |
| `test-rts-budget` | 6.7 | `ai_rts_core` |
| `lint-selftests` | 5.8 | global |
| 15 other engine targets | 1.8 -- 3.7 each, 37.7 in all | one module each; ~1.8 s is the floor of starting Godot |
| the other 12 lints, `import` | 2.2 in all | global |
| **total** | **550.4** | about 9 minutes, every target green |

Two things in that table decide the design. The lints that are global by
nature cost about 20 seconds; the rest is engine tests and refits, each of
which belongs to one module. And the two most expensive targets
(`test-opponent-levels`, the refits) belong to work that has not been
touched since waves 43-47.

**D2. Every gate runs every time, and twice per wave.** `make check` has 22
prerequisites expanding to 48 targets, with no notion of what changed.
`make wave-merge` runs the full `make check` again after the author already
ran it -- so every wave pays at least 2 x 9 minutes for every module, including a
docs-only wave such as wave 57 (6 files, 4 of them in `godot/demos/behaviour`).

**D3. A gate that went green while CI skipped nine gates.** `check_workflow.py`
promises (W5) that every gate in `make check` is reached by CI. Its
`target_prerequisites` reads only the **first line** of a recipe's
prerequisites: the regex `[^\n]*(?:\\\n[^\n]*)*` lets the first `[^\n]*` eat the
trailing backslash, the repetition then matches zero times and the match
succeeds, so nothing backtracks. It sees `check-no-engine lint-disk-layout
test-godot test-vectors` and nothing after them. Measured, these nine are in
`make check` and in no CI job:

`test-planner-benchmark`, `test-replay`, `test-opponent-levels`,
`test-opponent-properties`, `test-clone-rows`, `test-inference-budget`,
`test-clone-report`, `test-difficulty-knobs`, `test-rts-budget`.

Its self-test plants W5 only with a one-line `check:`, so the planted case
cannot catch it -- invariant 4's question, *does this pass on an empty
scene?*, had the answer yes. This is fixed in this wave whatever else is
decided, because the selector below leans on the same parsing.

**D4. Invariant 2 holds in code; `ai_core` is not what it says it is.**
Class-level dependency graph, code lines only (doc comments excluded):

| addon | files | lines | reaches into `ai_core` for |
|---|---:|---:|---|
| `ai_adversarial` | 4 | 296 | nothing |
| `ai_behaviour` | 8 | 578 | nothing |
| `ai_fuzzy` | 5 | 377 | nothing |
| `ai_opponent` | 1 | 158 | nothing |
| `ai_steering` | 7 | 313 | nothing |
| `ai_perception` | 4 | 283 | `GridGraph` |
| `ai_search` | 6 | 435 | `GridGraph`, `Pathfinder` |
| `ai_rts_core` | 12 | 1711 | `GridGraph` |
| `ai_planning` | 9 | 978 | nothing (comments name `BoardState`, `PlannedBlue`, `LeveledBlue`) |
| `ai_learning` | 8 | 1293 | `BoardState` (19 uses), `Unit` (35), `Move` (13), `UnitType`, `DecisionPolicy`, `GridGraph`, `Pathfinder` |
| `ai_core` | 10 | 851 | -- |

No addon reaches into `game/` or `demos/` in code; five doc comments in
addons name a class of `game/tactical`. So the invariant's letter holds. Its
spirit does not, twice:

- `ai_core` is described as "types and interfaces, no logic", and holds the
  tactical board's whole domain: `BoardState` (390 lines, 21 functions --
  funds, upgrades, production, `apply`, `why_refused`), `Unit`, `UnitType`,
  `Attack`, `Upgrade`, `ProductionOrder`. Six of eleven addons use none of it.
- `ai_learning` mixes a generic technique (`LearnedModel`, `SoftmaxModel`,
  `ModelFile`, `CaseTable`) with the tactical board's adapter
  (`LearnedPolicy`, `BoardFeatures`, which reads units and moves). Someone who
  wants a logistic model for their own game copies the board with it.

**D5. `game/` couples by hand-written chains.** `game/tactical` and
`game/league` depend on each other (`tactical.gd:407` cycles the computer
through `GoapTeam`, `HtnTeam`, ... in an `if playing is X: return Y.new()`
chain), and every game leans on the shared files at `game/*.gd` (`art.gd`,
`board_view.gd`, `legend.gd`, ...). Adding a controller edits the game.

**D6. Tests are filed by nobody.** `godot/test/` is 120 scripts in one folder,
mixing addon tests (`search_test.gd`), game tests (`tactical_game_test.gd`)
and runners; `make test-godot` hands gdUnit4 the whole folder (`-a test`).
gdUnit4 v6.2.2 already takes a suite or a directory per `-a` (read in
`GdUnitTestCIRunner.gd`, and in its CLI docs), so filing is all that is
missing.

**D7. Every wave touches the same five files.** Waves 61 and 62 both edited
`Makefile`, `tasks/STATUS.md` and `README.md`; an example also edits
`godot/menu/catalogue.json` and often `ci.yml`. A selector that maps "the
Makefile changed" to "run everything" selects everything every wave.

**D8. The Python side is already bounded; its couplings are by path.** Nine
subpackages of `gameaikit`, and **no** subpackage imports another. What ties
them to Godot is files: `cloning` reads `ai_learning/clone_weights.json` and
its GDScript, `ngram` reads `ai_opponent/ngram_predictor.gd`, `dataset` reads
`game/tactical/combat_rules.json`, `checkers` writes into `game/checkers/`,
and every vector in `spec/vectors/` is read from both languages. A selector
that only knows GDScript classes would miss all of it.

**D9. No `pyproject.toml`.** The wheel is written by hand (ADR 0009), which
is fine for a release and is not yet something another project can depend
on.

## The design

### A module is a bounded context, and says so in a manifest

Fowler's bounded context: a large model divided into contexts, each with its
own language. Here a **module** is one technique and everything that
teaches it: its addon, its Python twin, its vectors, its tests, its example.
Each one gets a manifest, `modules/<name>.json`:

```json
{
  "module": "ai_steering",
  "kind": "technique",
  "owns": ["godot/addons/ai_steering/", "godot/demos/steering/",
           "godot/test/ai_steering/", "python/gameaikit/steering/",
           "python/tests/test_steering*.py", "spec/vectors/steering/"],
  "depends_on": [],
  "gates": ["test-steering-vectors", "test-steering-properties"],
  "godot_tests": ["test/ai_steering/"]
}
```

Three kinds, because they change at different rates and carry different
rules:

- **`technique`** -- an addon plus its twin (`ai_search`, `ai_fuzzy`, ...).
  Depends on `kernel` modules only (invariant 2, unchanged).
- **`kernel`** -- the shared kernel, in DDD's own term: today `ai_core`. A
  change here selects every module that depends on it, which is why the
  kernel should be small (see "The shape the modules grow into").
- **`game`** -- one example (`game/rts`, `game/tactical`, `demos/search`).
  May depend on any technique and kernel, and on `game-shared`.

`depends_on` is **declared and measured**: a new gate, `check_modules.py`,
computes the graph `check_addon_deps.py` already knows (class names and
`res://`/relative paths) plus the path couplings of D8, and fails when the
declaration and the measurement differ -- either way. A manifest that says
less than the code is a selector that skips a test; one that says more is a
module that cannot be lifted alone.

Why per-module files and not one table: a new module adds a file and edits
nothing shared (D7).

### The selector: changed paths, then reverse dependencies

`scripts/affected.py --base <ref> [--head <ref>]` does what Nx's `affected`,
Pants' `--changed-dependents=transitive` and Bazel's `rdeps` do, in about two
hundred readable lines and the standard library:

1. `git diff --name-only <base>...<head>`, plus untracked files when run
   locally.
2. Each path to the module that owns it (`owns`, longest prefix wins).
3. Add every module that depends on one of those, transitively.
4. Print the modules, and with `--targets` the make targets to run: the
   always-on set, then each selected module's `gates` and its `godot_tests`.

**It fails safe, never quiet.** Four rules, each a planted case in its
`--self-test`:

- **A path no module owns selects everything** and says which path did it.
  "I do not know who this belongs to" is never "nobody needs testing".
- **The global paths select everything**: `scripts/`, `mk/common.mk`,
  `.github/`, `.githooks/`, `godot/project.godot`, `.godot-version`,
  `godot/addons/gdUnit4/`, and any `kernel` module. These are the things every
  gate stands on.
- **Paths that only gates read select only those gates**: `tasks/` selects
  `lint-tasks` and `lint-status`; `docs/` and `README.md` select `lint-links`,
  `lint-docs-freshness`, `lint-tiers`. These are D7's hotspots, defused.
- **An empty diff runs the always-on set, not nothing** -- invariant 4's
  question asked of the selector itself.

### What always runs, and what follows the diff

Measured in D1: the lints are cheap and repo-wide **by nature** (commit
messages, the employer terms over all history, licence files, readability of
the tree, the workflow) -- scoping them would save seconds and cost a gate's
meaning. The engine tests and the retraining checks are where the time goes,
and they belong to one module each. So:

- **always**: every `lint-*` except the expensive half of `lint-no-training`,
  plus `lint-modules`.
- **per module**: `test-<x>-vectors`, `test-<x>-properties`, benchmarks,
  matches, the module's gdUnit4 folder, and `lint-no-training`'s
  reproduce-from-seed rules (N4, N6, N7, N10), each tied to the model it
  refits -- `check_no_training.py --only N7` when `checkers` changes.
- **`import`** runs once per invocation, not once per engine target.

### Where each check runs

| when | runs | why |
|---|---|---|
| on the branch, while working | `make check-affected` | the author's loop |
| `make wave-merge` | `make check-affected BASE=main` | the merge pays for what it changes |
| CI on a pull request | `make check-affected BASE=origin/main` | same command, same answer |
| CI on a push to `main` | `make check` | the whole repository, once per merge, on a machine nobody is waiting for |
| `make release` | `make check` | nothing ships that the full check has not seen |

CI does **not** use `on.pull_request.paths`: GitHub documents that a workflow
skipped by a path filter leaves its required checks *Pending* and blocks the
merge, while a *job* skipped by `if:` reports success. So one workflow always
runs, a first job prints the affected targets (`make affected`), and the
engine job runs `make check-affected` -- still only make targets, so
`check_workflow.py`'s rule holds. W5 changes meaning to "every gate in
`make check` is reached by the push-to-`main` job", which is the same promise
it makes today, kept honestly.

**The selector's own truth check:** the push-to-`main` job also runs
`make check-affected BASE=HEAD^1` before `make check`; a failure the full
check finds and the affected one did not names a missing dependency, and is a
finding against the manifests.

### The Makefile stops being a hotspot

`Makefile` keeps the commands people type; each module's targets move to
`mk/<module>.mk`, included by glob, and each fragment appends to the lists
`check` is built from (`MODULE_GATES += test-steering-vectors ...`). A new
module adds a fragment and a manifest and edits neither the Makefile nor
`ci.yml`. `check_workflow.py` and `check_demos.py` read the fragments.

## The shape the modules grow into (later tasks, not this wave)

The patterns that fit, chosen for what this repository already does and where
it hurts:

- **Ports and adapters** (Cockburn, 2005: "a port identifies a purposeful
  conversation"). Each technique addon owns its **port** as an `@abstract`
  class and never knows the game; each game writes the **adapter**.
  `ai_adversarial` already does exactly this (`AdversarialGame`), and is the
  model the others should copy. Concretely: `ai_search` searches a
  `SearchGraph` port (neighbours, cost) that `GridGraph` implements, instead
  of `GridGraph` itself; `ai_learning` keeps `LearnedModel`, `SoftmaxModel`,
  `ModelFile`, `CaseTable`, and `LearnedPolicy` + `BoardFeatures` move to
  `game/tactical/` as the adapter (D4); `ai_planning` plans over its own
  `WorldState`, and the bridges already in `game/` are its adapters.
- **A small shared kernel.** `ai_core` keeps the ports and value types more
  than one technique truly shares (`GridGraph`, `Move`, `DecisionPolicy`,
  `Pathfinder`); `BoardState` and the unit types become the tactical board's
  own kernel (`game/board/` or an `ai_board` module of kind `kernel`), so a
  change to the board stops selecting `ai_steering`.
- **Strategy**, which the kit already teaches without naming it: every
  controller is a `DecisionPolicy`, every steering force a
  `SteeringBehaviour`. It stays the configuration point: a game is handed a
  policy object; it never constructs one by name.
- **A registry instead of `if playing is X` chains** (D5): each game reads its
  controllers from a table -- the menu's `catalogue.json` already lists the
  techniques and their evidence classes, and grows a `controllers` list per
  example. Godot's own advice for this: a `class_name` with `static func` as
  a helper library, rather than an autoload's global state (*Autoloads versus
  regular nodes*), and dependencies injected by the parent (*Scene
  organization*).
- **Game Programming Patterns** for the vocabulary readers will meet:
  Component and Service Locator (decoupling), Type Object (`UnitType`,
  `RtsKinds` already are one).

### The Python side, by *Fluent Python* (2nd ed.)

- **Ports as `typing.Protocol`** (ch. 13, *Interfaces, Protocols, and ABCs*;
  ch. 15): structural, so a user's game class satisfies the port without
  inheriting from the kit. An ABC only where a default method earns it.
- **Strategy as plain functions** (ch. 10, *Design Patterns with First-Class
  Functions*): a heuristic, a utility curve or a steering force is a
  `Callable`, not a one-method class.
- **Registration by decorator** (ch. 9 and ch. 10's `promotion` decorator in
  `strategy_best4.py`): `@technique("a-star")` fills the registry the menu and
  the league read, instead of a list kept by hand.
- **Values as frozen data classes** (ch. 5, *Data Class Builders*): states,
  moves and vectors immutable by construction, matching `BoardState`'s
  "apply returns a new state".
- **Sequences that behave like sequences** (ch. 2, ch. 12): a path or a plan
  supports `len`, iteration and slicing rather than exposing a list.

## The library, later

Two artefacts from one tree, both built from the modules above.

**Godot.** Each technique addon is already zipped on its own with LICENSE and
NOTICE (ADR 0009, `check_license.py`). What a library needs beyond that:

- **Names.** `class_name` registers globally and GDScript has no namespaces
  in 4.7 (godot-proposals #1566, open since 2020; its opening post is the
  plugin case: "Unique global class ... already exists"). `Unit`, `Move`,
  `Search`, `Steering`, `Hearing` will collide in someone's game. A decision
  for the owner, because it trades against invariant 1: a prefix
  (`GakAStarSearch`), or the generic names kept and the release's README
  saying so. Recommended: rename only the ports and the kernel (the names
  most likely to collide), keep the algorithms' names readable.
- **Layout for the Asset Library / Asset Store.** `addons/<name>/` is
  recommended, not required; a LICENSE at the repository root is required;
  a copy of the licence and readme inside the plugin folder is asked for;
  `.gitattributes` `export-ignore` keeps everything else out. The Asset
  Store is in beta and every asset must be re-uploaded to it. A library
  addon needs no `plugin.cfg` (measured here; the docs only say `class_name`
  registers globally). A `.pck` is a runtime overlay for patches and mods,
  not a library format, so it is not the vehicle.
- **No addon ships its tests or its manifest's game paths**; the release
  builder filters by the manifest.

**Python.** A `pyproject.toml` with the PEP 621 `[project]` table in
`python/`, keeping the **flat** layout: PyPA's own discussion says the src
layout requires installing the project to run its code, and the stdlib
`unittest` without an install step is a tier-1 promise. Still stdlib only, so
no `dependencies`; `optional-dependencies` stays empty unless a plotting
extra earns it. A user's own technique plugs in through an entry-point group
(`gameaikit.techniques`), the mechanism PyPA's *Creating and discovering
plugins* recommends; **not** namespace packages, which require every
distribution to omit `__init__.py` and would fight `python/tests`' own
`__init__.py` trap. Building a wheel needs a build backend; publishing is
the moment ADR 0009 is revisited, not before.

Proposed follow-up tasks (numbers taken when the owner approves this one):
the ports and the small kernel (one addon a wave, `ai_learning` first, D4);
the controller registry (D5); and the library (names decision, `pyproject`,
the release filtered by manifest).

## Steps

1. **Fix W5 first, with the planted case it lacked**: a multi-line `check:`
   whose fourth line holds a gate CI never runs. Then put the nine missing
   gates of D3 in CI, or move them out of `make check` with a reason each.
   Measured before and after, the same command.
   *Done in wave 63, approved by the owner 2026-10-20.* The planted case
   failed against the old pattern before the fix; after it,
   `python3 scripts/check_workflow.py` named the same nine gates (exit 1),
   and with all nine put in CI -- `test-clone-report` in the Python job,
   which needs nothing else, the eight engine ones in the Godot job -- it
   exits 0. None of them was taken out of `make check`. Whether the two
   timing budgets hold on a shared runner is known only after the first CI
   run of this branch.
2. **Manifests** for the eleven addons, the examples and `game-shared`, and
   `check_modules.py` (`make lint-modules`): every tracked path under
   `godot/`, `python/`, `spec/` owned by exactly one module; declared
   dependencies equal to measured ones; a technique depending only on
   kernels. Planted: an unowned file, a path owned twice, a `class_name` use
   the manifest does not declare, a path read the manifest does not declare.
3. **File the tests by module**: `godot/test/<module>/`, one `git mv` commit
   with no content change, then `make import` and the `.uid` files. The
   runners shared by several modules (`vectors_runner.gd`) go to
   `godot/test/shared/`, owned by the global set.
4. **`scripts/affected.py`** with its four fail-safe rules as planted cases,
   and `make affected` (prints) and `make check-affected` (runs).
   `check_no_training.py --only <rule>` for the reproduce-from-seed rules.
5. **`mk/<module>.mk` fragments**; `check_workflow.py` and `check_demos.py`
   read them.
6. **`make wave-merge` runs `check-affected BASE=main`**; CI as in the table
   above; the push-to-`main` job runs both and compares.
7. **Measure again** on three replayed waves, the same machine as D1:
   wave 61 (`e349c7e`, a technique), wave 62 (`f0fbf9b`, a game on a new
   core), wave 57 (`cb947ef`, a small example change). Publish what each
   selects and what it costs against the full check.
8. `CLAUDE.md`: the invariants table gains `lint-modules` and the selector;
   "Commands" gains `make check-affected`; the trap that `make check` is no
   longer what a wave runs.

## Acceptance

```bash
make check
```

```bash
python3 scripts/check_workflow.py --self-test
```

```bash
python3 scripts/check_modules.py --self-test && python3 scripts/check_modules.py
```

```bash
python3 scripts/affected.py --self-test
```

The steering wave selects its module and not the RTS:

```bash
python3 scripts/affected.py --base e349c7e^1 --head e349c7e --targets | grep -qx test-steering-properties
```

```bash
! python3 scripts/affected.py --base e349c7e^1 --head e349c7e --targets | grep -qx test-rts-match
```

An empty diff still runs the always-on set:

```bash
python3 scripts/affected.py --base HEAD --head HEAD --targets | grep -qx lint-employer-refs
```

```bash
make check-affected BASE=main
```

## Manual check

The owner reads the D1 table and step 7's numbers side by side and decides
whether the saving is worth the selector's complexity; and reads
`scripts/affected.py` top to bottom, which should read like the four rules
above and nothing cleverer.

## Out of scope

- Moving any technique's code: the ports, the small kernel, splitting
  `ai_learning`, the controller registry. Planned above, one later wave each.
- The library: the naming decision, `pyproject.toml`, publishing to PyPI or
  the Asset Store, revisiting ADR 0009.
- Caching Godot's import or the toolchain between CI runs beyond what
  `actions/cache` does today.
- Parallel test execution: a second axis of speed, measured only after this
  one.
- Any change to what a gate checks, except W5's fix.

## Sources

Opened on 2026-10-20. Godot pages say "Godot Engine 4.7 documentation" at the
minor version; none names 4.7.2.

- Godot, *Making plugins*: https://docs.godotengine.org/en/stable/tutorials/plugins/editor/making_plugins.html
- Godot, *GDScript basics* (`class_name` registers globally): https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html
- Godot, *Submitting to the Asset Library*: https://docs.godotengine.org/en/stable/community/asset_library/submitting_to_assetlib.html
- Godot, *What is the Asset Store* (beta, re-upload): https://docs.godotengine.org/en/4.7/community/asset_store/what_is_asset_store.html
- Godot docs source, *Submitting to the Asset Store* (master, not 4.7): https://github.com/godotengine/godot-docs/blob/master/community/asset_store/submitting_to_asset_store.rst
- Godot, *Exporting packs, patches, and mods*: https://docs.godotengine.org/en/stable/tutorials/export/exporting_pcks.html
- Godot, *Scene organization*: https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html
- Godot, *Autoloads versus regular nodes*: https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html
- Godot, *Command line tutorial*: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- gdUnit4, command line (`-a`, `-i`, `-c`, exit codes; "latest", not pinned to v6.2.2): https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/cmd/
- godot-proposals #1566, *Implement namespaces in GDScript*: https://github.com/godotengine/godot-proposals/issues/1566
- PyPA, *Packaging Python Projects*: https://packaging.python.org/en/latest/tutorials/packaging-projects/
- PyPA, *src layout vs flat layout*: https://packaging.python.org/en/latest/discussions/src-layout-vs-flat-layout/
- PyPA, *Writing your pyproject.toml*: https://packaging.python.org/en/latest/guides/writing-pyproject-toml/
- PyPA, *pyproject.toml specification*: https://packaging.python.org/en/latest/specifications/pyproject-toml/
- PyPA, *Creating and discovering plugins*: https://packaging.python.org/en/latest/guides/creating-and-discovering-plugins/
- PyPA, *Packaging namespace packages*: https://packaging.python.org/en/latest/guides/packaging-namespace-packages/
- Ramalho, *Fluent Python*, 2nd ed., chapter list and `strategy_best4.py`: https://github.com/fluentpython/example-code-2e
- GitHub, *Workflow syntax* (`paths`, Pending checks): https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions
- GitHub, *Troubleshooting required status checks* (a job skipped by `if:` reports success): https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks
- Nx, *affected*: https://nx.dev/docs/features/ci-features/affected
- Pants, *Advanced target selection*: https://www.pantsbuild.org/stable/docs/using-pants/advanced-target-selection
- Bazel, *Query guide* (`rdeps`): https://bazel.build/query/guide
- Memon et al., *Taming Google-Scale Continuous Testing*, ICSE-SEIP 2017 (abstract only): https://research.google/pubs/pub45861/
- Cockburn, *Hexagonal Architecture*: https://alistair.cockburn.us/hexagonal-architecture/
- Fowler, *BoundedContext*: https://martinfowler.com/bliki/BoundedContext.html
- Nystrom, *Game Programming Patterns*: https://gameprogrammingpatterns.com/contents.html
