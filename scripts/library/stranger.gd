## What a stranger's project does with three unzipped addons: decide twice.
##
## Run by `scripts/library_check.py` in a blank Godot project that holds
## `addons/ai_core/`, `addons/ai_search/` and `addons/ai_learning/` as the
## release zips them, the two examples of
## `docs/techniques/using-the-library.md` beside them, and the model file the
## page's Python step wrote. It adds each example to the tree as the page
## says -- a node in your scene -- and prints one marker per decision that
## came out as the page says it does. A missing class is a parse error in an
## example, so its script cannot be instantiated and this quits with 1; the
## caller requires the markers, not only the exit code (CLAUDE.md, "A script
## error in a `-s` script does not fail the run").
extends SceneTree

const ROUTE_EXAMPLE: String = "res://route_example.gd"
const MODEL_EXAMPLE: String = "res://chance_from_python.gd"
const ROUTE_MARKER: String = "LIBRARY-CHECK: the route goes round the wall"
const MODEL_MARKER: String = "LIBRARY-CHECK: the model Python wrote decides in Godot"


func _initialize() -> void:
	var walker: Node = attached(ROUTE_EXAMPLE)
	var attacker: Node = attached(MODEL_EXAMPLE)
	if walker == null or attacker == null:
		quit(1)
		return
	# Measured on 4.7.2: a child added to the root here has not run its
	# `_ready` yet when `_initialize` reads it back. One frame later it has.
	await process_frame
	var route: Array[Vector2i] = walker.route
	var through_the_gap: bool = route.has(Vector2i(3, 3)) and route.back() == Vector2i(5, 0)
	if through_the_gap:
		print(ROUTE_MARKER)
	var chance: float = attacker.chance
	# The training rows say the healthier side wins, so a healthy attacker
	# against a hurt defender must come out above even.
	var believes_the_rows: bool = not is_nan(chance) and chance > 0.5 and chance < 1.0
	if believes_the_rows:
		print(MODEL_MARKER)
	else:
		printerr("ERROR: the model's chance for 85 against 30 is %s" % chance)
	quit(0 if through_the_gap and believes_the_rows else 1)


## The example at `path` as a node under the root, as a scene would hold
## it; null when its script does not parse, which is how a missing class
## shows.
func attached(path: String) -> Node:
	var script: GDScript = load(path)
	if script == null or not script.can_instantiate():
		printerr("ERROR: %s does not parse in this project" % path)
		return null
	var node: Node = script.new()
	root.add_child(node)
	return node
