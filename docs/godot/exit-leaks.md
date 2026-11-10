# What a scene leaves alive at exit, and how to name it

<!-- doc-meta
half_life: practice
verified_on: 2026-11-10
tier: 1
source: https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html ; https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/core/object/object.cpp ; https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/core/io/resource.cpp ; https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/modules/gdscript/gdscript.cpp ; https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/modules/gdscript/gdscript_cache.cpp ; https://forum.godotengine.org/t/95708
invalidated_if: Godot stops printing the two exit lines without --verbose, renames them, or a 4.7.x release changes how GDScriptLanguage::finish breaks cycles between scripts
teaches: none
-->

> T138, wave 146. Closing `make demo-rts` printed `21 ObjectDB instances
> were leaked at exit` and `15 resources still in use at exit`. What the
> engine prints and when, what was measured, and what is still unknown.

## What the engine prints

The command-line page says only that `--verbose` is "verbose stdout mode".
The 4.7.2-stable source says what it changes at exit:

- `ObjectDB::cleanup` (object.cpp, line 2536) prints `N ObjectDB instances
  were leaked at exit` whenever an object is still alive, verbose or not.
  With `--verbose` it adds a `Leaked instance: <class>:<id>` line per object.
- `ResourceCache::clear` (resource.cpp, line 817) prints `N resources still
  in use at exit` whenever a resource loaded from a path is still
  referenced. With `--verbose` it adds `Resource still in use: <path>
  (<class>)` per resource.

So a gate can read the two summary lines without `--verbose`. It needs
`--verbose` only to say which class and which file.

## Headless sees it

Measured on 4.7.2: `./scripts/godot --headless --verbose --path godot
res://game/rts/rts.tscn --quit-after 1` printed the same 21 and 15 as the
window did. A windowed run with `--quit-after 300` printed them too. The
leak was there from the first frame, so it was made while loading, not
while playing.

## What leaked, and what is known of why

Every leaked object was a `GDScript` (15) or a `GDScriptNativeClass` (6).
They are scripts, not instances. Loading `rts.gd` alone with `load()`,
nothing instanced, was enough.

**The observed trigger.** A scratch copy was bisected function by function,
then line by line. The trigger observed was one signature in `rts.gd`:

```gdscript
func _clocked(side: RtsSide) -> GakRtsController:
```

Typed `-> RefCounted`, or written as a function that returns the
`RtsHumanClock` it makes, nothing leaked.

**Load order matters.** With `addons/ai_rts_core/rts_controller.gd` (the
class `GakRtsController`) loaded before `rts.gd`, nothing leaked. With
`rts_command.gd` or `rts_snapshot.gd` loaded first, it still leaked.

**The engine mechanism is not identified.** The signature is not enough on
its own:

- The same signature in a three-line script did not leak.
- `game/league/rts_roster.gd` declares seven `-> GakRtsController`
  signatures and loads clean as the first script.
- `game/squad/squad_ruleset.gd` and `game/squad/squad_map_words.gd` never
  name the port, and each leaked 18 objects and 17 resources when loaded
  alone. This was found in the review of PR #100. T146 found the trigger,
  below.

`GDScriptLanguage::finish` (gdscript.cpp, 4.7.2-stable) breaks cycles between
scripts through member types and function signatures only, before
`script_list` is cleared. A script still referenced after that pass is never
freed. Which reference survives here is not known, and finding it needs a
debug build.

No Godot issue was found. One forum report shows the same symptom on 4.3,
with no root cause (forum.godotengine.org/t/95708).

The change to `rts.gd` is a workaround at the observed trigger. `_seat`
returns the clock or null, typed `RtsHumanClock`, and never names the port.

## T146: two more triggers, and what they share

Measured on 4.7.2 in wave 166, with a scratch `-s` script that `load()`s
one script and quits, the way T138 measured `rts.gd`. Function bodies were
stubbed one at a time, then lines changed one at a time.

**The squad.** The trigger was one line of `SquadRuleset.build_controller`:

```gdscript
if built is SearchingSquad:
	(built as SearchingSquad).spread_over_frames()
```

With either the `is` or the `as` there, and `squad_ruleset.gd` compiled
first, 18 objects leaked. `squad_map_words.gd` leaked only because it names
`SquadRuleset` in a signature, so the ruleset compiled first. The fix is in
the game: `SquadRoster.for_the_scene` makes that choice now, and the ruleset
calls it. Every script under `game/squad/` and `game/tactical/`, loaded
first, now closes clean.

**The behaviour demo.** It was not in the review's measurement, which read
`game/` and `menu/`. Run as a scene, `demos/behaviour/behaviour_demo.tscn`
leaked 36 objects, 27 resources and 7 dummy-texture RIDs: the board's
scripts, the stealth room's, `ai_fuzzy` and `ai_perception`, and the seven
terrain textures that `Art`'s static cache held. `behaviour_demo.gd`
loaded alone with `load()` leaked 22 and 20, and `brain_panel.gd` 16 and 15.

What fixed it is one static function, `GuardBrain.every()`, which builds
the four brains. The scene and a script loaded alone do not agree on what
matters. Measured in the review of PR #124, then again after the revert
below:

| Present | `behaviour_demo.tscn` | `brain_panel.gd` loaded first |
|---|---|---|
| `every()` in `guard_brain.gd`, called by `swap_brain` (what ships) | clean | clean |
| `every()` only, old inline list in `swap_brain` | clean | clean |
| `BrainPanel` dispatching on `thinking()`'s keys, no `every()` | leaks 36/27 | clean |
| neither | leaks 36/27 | leaks 16/15 |

So `every()` fixes the scene even when nothing calls it: what matters is that
`guard_brain.gd` names its four subclasses. The same list in
`BehaviourWorld` still leaked. Changing `BrainPanel` to read `thinking()`'s
keys instead of `is GuardFsm` fixed only the script loaded alone, and no
gate holds that case, so it was reverted: `BrainPanel` still writes `is
GuardFsm`. `swap_brain` calls `every()` because it reads better there, not
because the fix needs it.

**What they share, and what they do not.** In each case the script the
engine compiles first names another class: in a signature (`rts.gd`), or in
an `is` or an `as` (the squad). The behaviour demo does not fit the pattern:
it was fixed by a base class naming its subclasses, and nothing in the
script compiled first changed. Loading one more script first also hid each
leak: `tactical_ruleset.gd`, `blue_controller.gd` or `squad_view.gd` before
the ruleset, `guard_tree.gd` or `addons/ai_behaviour/behaviour_tree.gd`
before the demo. So the engine mechanism is still not identified, and the
order the engine compiles scripts in is part of it.

`test/squad/exit_ruleset_first.tscn` is kept bare on purpose. Against the
old ruleset, a body that called the ruleset, a `BlueController` in its
signature or a `var rules: SquadRuleset` in `_ready` each made the case
close clean, so it would no longer have shown the leak.

## The gate

A process cannot read what it prints after it ends. So `make test-rts-exit`
(T138), `make test-demos-exit` and `make test-squad-exit` (T146) run
`scripts/check_exit_leaks.py`, which starts Godot on the scene as a child
and reads that child's output for the two lines. Each child runs
under a deadline, through `godot_shards`' `wait_or_kill`. The order:

1. **The planted leak.** It first runs `godot/test/rts/planted_exit_leak.gd`,
   a `Node` never freed that holds a loaded script. If either line is
   missing there, the gate fails. That way a run that printed nothing is
   never read as clean.
2. **The scene.** Then it runs the scene with `--quit-after 30`. A scene
   that never runs its script leaks nothing, so the scene is also refused
   in three other cases. It fails if it printed an engine-error line (a
   clean run of the RTS prints none). It fails if it loaded no `.gd` at
   all, which is what an empty scene prints. And on a nonzero exit, the
   engine lines that explain it are printed. These were added after the
   second review of PR #100. With `--demos` (`make test-demos-exit`) it
   runs every scene in `check_demos.py`'s list, one after another, after
   the one planted leak. It then runs every extra mode that
   `test/menu/demo_overlays.gd`'s `MODE_REQUIRED` names, through the menu,
   as `make demo-tactical MODE=squad` opens it (`-- --open=demo-tactical
   --mode=squad`). Today that is one mode. A leak in any run fails 1, even
   when another run was killed (2): `sweep_code`. A list that came back
   empty fails.
3. **The deadline.** A child that stops on an error before `quit()` never
   ends. It is killed at `--timeout` (60 s in the Makefile), and the gate
   exits 2.

The script's `--self-test` holds the readings: a leaking output is refused
and a clean one passes.

An earlier version ran the child from GDScript with `OS.execute`. That
needed an exception in `lint-llm-validated`, invariant 7's net, and it had
no deadline. The review of PR #100 asked for this form instead.
