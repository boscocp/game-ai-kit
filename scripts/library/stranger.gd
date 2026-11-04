## What a stranger's project does with the unzipped addons: decide.
##
## Run by `scripts/library_check.py` in a blank Godot project that holds
## only what `docs/techniques/using-the-library.md` told its reader to put
## there, once per example: `-- route` after the route example is saved,
## `-- infer` after the model example and the file the page's Python step
## wrote. It adds that example to the tree as the page says -- a node in
## your scene -- and prints the step's marker when it decided as the page
## says it does.
##
## Every way out calls `quit`. A missing class is a parse error, so the
## example cannot be instantiated; a field the example no longer has is
## read with `get` and found missing, rather than a script error that would
## abort this function and leave Godot running. The caller still requires
## the marker, not only the exit code (CLAUDE.md, "A script error in a `-s`
## script does not fail the run"), and bounds the run with a timeout.
extends SceneTree

const EXAMPLES: Dictionary = {
	"route": "res://route_example.gd",
	"infer": "res://chance_from_python.gd",
}
const MARKERS: Dictionary = {
	"route": "LIBRARY-CHECK: the route goes round the wall",
	"infer": "LIBRARY-CHECK: the model Python wrote decides in Godot",
}


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var step: String = arguments[0] if arguments.size() == 1 else ""
	if not EXAMPLES.has(step):
		printerr("ERROR: run with -- route or -- infer, not %s" % arguments)
		quit(2)
		return
	var example: Node = attached(EXAMPLES[step])
	if example == null:
		quit(1)
		return
	# Measured on 4.7.2: a child added to the root here has not run its
	# `_ready` yet when `_initialize` reads it back. One frame later it has.
	await process_frame
	var decided: bool = route_found(example) if step == "route" else chance_believed(example)
	if decided:
		print(MARKERS[step])
	quit(0 if decided else 1)


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


## Whether the route example went through the gap in the wall to the goal.
func route_found(example: Node) -> bool:
	var route: Variant = example.get("route")
	if not route is Array or (route as Array).is_empty():
		printerr("ERROR: the route example holds no route: %s" % [route])
		return false
	var cells: Array = route
	return cells.has(Vector2i(3, 3)) and cells.back() == Vector2i(5, 0)


## Whether the model example believes the training rows: they say the
## healthier side wins, so a healthy attacker against a hurt defender must
## come out above even.
func chance_believed(example: Node) -> bool:
	var chance: Variant = example.get("chance")
	if not chance is float or is_nan(chance) or chance <= 0.5 or chance >= 1.0:
		printerr("ERROR: the model's chance for 85 against 30 is %s" % [chance])
		return false
	return true
