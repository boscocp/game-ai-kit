# T146's case: a scene whose script names `SquadRuleset` in a signature and
# nothing else, so `squad_ruleset.gd` is the first game script the engine
# compiles -- as `squad_map_words.gd` was when loaded alone.
#
# Compiled first, the ruleset left 18 objects and 17 resources alive at
# exit while it wrote `is SearchingSquad` itself; `SquadRoster.for_the_scene`
# does that now. `make test-squad-exit` runs this scene through
# `scripts/check_exit_leaks.py`; see `docs/godot/exit-leaks.md`.
#
# Keep it this bare. Measured against the old ruleset, a body that called
# the ruleset, a `BlueController` in a signature or a `var` in `_ready`
# each hid the leak: they change what compiles first.
extends Node


## Nothing: it exists so that a signature names the class, and so that the
## ruleset compiles before any other game script.
static func named_first(rules: SquadRuleset) -> String:
	return ""
