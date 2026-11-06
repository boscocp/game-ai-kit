# What a scene leaves alive at exit, and how to name it

<!-- doc-meta
half_life: practice
verified_on: 2026-11-06
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
  name the port, and each leaks 18 objects and 17 resources when loaded
  alone. This was found in the review of PR #100. Today's scenes do not load
  them first, and every demo scene closes clean.

`GDScriptLanguage::finish` (gdscript.cpp, 4.7.2-stable) breaks cycles between
scripts through member types and function signatures only, before
`script_list` is cleared. A script still referenced after that pass is never
freed. Which reference survives here is not known, and finding it needs a
debug build.

No Godot issue was found. One forum report shows the same symptom on 4.3,
with no root cause (forum.godotengine.org/t/95708).

The change to `rts.gd` is a workaround at the observed trigger. `_seat`
returns the clock or null, typed `RtsHumanClock`, and never names the port.
T146 runs the same exit check over every demo scene and looks at the squad
leak.

## The gate

A process cannot read what it prints after it ends. So `make test-rts-exit`
runs `scripts/check_exit_leaks.py`, which starts Godot on the scene as a
child and reads that child's output for the two lines. Each child runs
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
   second review of PR #100.
3. **The deadline.** A child that stops on an error before `quit()` never
   ends. It is killed at `--timeout` (60 s in the Makefile), and the gate
   exits 2.

The script's `--self-test` holds the readings: a leaking output is refused
and a clean one passes.

An earlier version ran the child from GDScript with `OS.execute`. That
needed an exception in `lint-llm-validated`, invariant 7's net, and it had
no deadline. The review of PR #100 asked for this form instead.
