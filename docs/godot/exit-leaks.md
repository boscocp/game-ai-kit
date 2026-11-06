# What a scene leaves alive at exit, and how to name it

<!-- doc-meta
half_life: practice
verified_on: 2026-11-06
tier: 1
source: https://docs.godotengine.org/en/4.5/tutorials/editor/command_line_tutorial.html ; https://raw.githubusercontent.com/godotengine/godot/master/core/object/object.cpp ; https://raw.githubusercontent.com/godotengine/godot/master/core/io/resource.cpp ; https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/modules/gdscript/gdscript.cpp ; https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/modules/gdscript/gdscript_cache.cpp
invalidated_if: Godot stops printing the two exit lines without --verbose, renames them, or a 4.7.x release changes how GDScriptLanguage::finish breaks cycles between scripts
teaches: none
-->

> T138, wave 146. Closing `make demo-rts` printed `21 ObjectDB instances
> were leaked at exit` and `15 resources still in use at exit`. What the
> engine prints and when, how the cause was found, and what it was.

## What the engine prints

The command-line page says only that `--verbose` is "verbose stdout mode".
The source says what it changes at exit:

- `ObjectDB::cleanup` prints `N ObjectDB instances were leaked at exit`
  whenever an object is still alive, verbose or not. With `--verbose` it
  adds a `Leaked instance: <class>:<id>` line per object.
- `ResourceCache::clear` prints `N resources still in use at exit` whenever a
  resource loaded from a path is still referenced. With `--verbose` it adds
  `Resource still in use: <path> (<class>)` per resource.

So a gate can read the two summary lines without `--verbose`, and needs it
only to say which class and which file.

## Headless sees it

Measured on 4.7.2: `./scripts/godot --headless --verbose --path godot
res://game/rts/rts.tscn --quit-after 1` printed the same 21 and 15 as the
window did, and so did a windowed run with `--quit-after 300`. The leak was
there from the first frame, so it was made while loading, not while playing.

## What leaked, and why

Every leaked object was a `GDScript` (15) or a `GDScriptNativeClass` (6):
scripts, not instances. Loading `rts.gd` alone with `load()`, nothing
instanced, was enough. Bisected in a scratch copy, function by function and
line by line, the trigger was one signature in `rts.gd`:

```gdscript
func _clocked(side: RtsSide) -> GakRtsController:
```

Typed `-> RefCounted`, or written as a function that returns the
`RtsHumanClock` it makes, nothing leaked. Loading
`addons/ai_rts_core/rts_controller.gd` (the class `GakRtsController`) before
`rts.gd` also stopped the leak, so it depends on load order: `rts.gd` is the
first script the demo compiles, and its signature named the port before
anything had loaded it. The same signature in a three-line script did not
leak, so the rest of `rts.gd`'s references are part of it. Read in the
4.7.2 source, `GDScriptLanguage::finish` breaks cycles between scripts
through member types and function signatures only, before `script_list` is
cleared. A script still referenced after that pass is never freed. This
note does not say which reference survived. Finding that needs a debug
build.

The fix is in the game, where the signature was: `_seat` returns the clock
or null, typed `RtsHumanClock`, and never names the port.

## The gate

`make test-rts-exit` (`godot/test/rts/rts_exit.gd`) starts a second Godot
with `OS.execute`, because a process cannot read what it prints after it
ends. It reads that process's output for the two lines. It first runs a
planted leak (`planted_exit_leak.gd`, a `Node` never freed that holds a
loaded script) and fails if either line is missing. That way a run that
printed nothing is not read as clean.
