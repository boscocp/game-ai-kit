# T167 — No addon names itself as a value

Size: S · Prereqs: T162 · Files: `scripts/check_self_naming.py` (new), `Makefile`, `modules/`, `docs/godot/exit-leaks.md`

## Goal

T162 (wave 176) found that an addon script that names its own class as a
value in its own file holds a reference to itself. Examples are
`GakGridGraph.new()` inside `grid_graph.gd`, `is BayesNetwork` inside
`bayes_network.gd`, and an inner class calling `BehaviourTree.said()`. Only
the engine's walk at exit frees such a script, and that walk can end
early. The details are in `docs/godot/exit-leaks.md`. Sixteen scripts were
changed to say `new()` instead.

Today only the loader checks hold this, in `check_published.py` and in
`library-check`'s `kit` step. They see the leak only in the orders they
load scripts in. A new self-naming script that ends up last in the loader's
order leaks nothing there, and it would ship. The review of wave 176
(finding 4) prototyped a static check in about 20 lines. It found exactly
the 16 files on main before T162, and none after. This task makes that
check a gate, so the rule does not stay prose.

## Decisions written down first

_Proposed in the review of wave 176; the owner chose a follow-up task on
2026-11-11. The wave confirms the details._

- **What it refuses.** In every `.gd` under `godot/addons/ai_*/`, take the
  `class_name`. Its own file must not name it in a value position:
  `Name.new(`, any `Name.<call>(`, `Name.CONSTANT`, `is Name` or
  `as Name`. This counts inner classes naming their outer class. Names in a
  type position stay allowed: `-> Name`, `var x: Name`, `Array[Name]`,
  and an argument typed `Name`. T162 measured those as harmless. Comments
  and strings are stripped first.
- **What it does not refuse.** Game code, tests and demos. The rule is about
  what ships, and a game naming its own class is the game's choice. The
  page says how to avoid it.
- **Fast, no engine.** It runs in `make check` as a lint, a module of its
  own, like the other `lint-*` gates.

## Acceptance

```bash
python3 scripts/check_self_naming.py
python3 scripts/check_self_naming.py --self-test
make lint-selftests
```

The self-test plants one script of each refused spelling, which must each
be named, and one script that names itself only in types, which must pass.
It also plants an empty `addons/` folder, which must not pass as checked.

## Manual check

- Read the finding the gate prints for a planted `Foo.new()`. It must say
  what to write instead: `new()` in a static function, or a static factory
  called from an instance function.
