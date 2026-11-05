# How long the window stalls when L reaches a solved level (T122): the
# scene run headless, L pressed onto a generated level in the solver's
# mode, and the longest frame until that level is played -- solved inline,
# then on the pool; and, for the frame that only builds a world, the same
# seed drawn. A table for docs/godot/infiltration.md, not a gate.
#
#     ./scripts/godot --headless --path godot -s res://test/infiltration/level_solving_measure.gd
#
# Exit codes: 0 measured, 1 a level never arrived or the two ways differ.
extends SceneTree

const SCENE: String = "res://game3d/infiltration/infiltration.tscn"
const SEEDS: Array[int] = [3, 4, 5, 144]
## The ways a level is made here, as `_begin` reads them.
const WAYS: Array[String] = ["drawn", "inline", "the pool"]
## Frames a solve may take before the run counts it lost.
const FRAMES_ALLOWED: int = 2000

var _runs: Array = []
var _demo: Node
var _wanted: int = 0
var _name: String = ""
var _way: String = ""
var _longest: int = 0
var _frames: int = 0
var _last_tick: int = 0
var _levels: Dictionary = {}
var _failed: bool = false


func _init() -> void:
	for seed_value: int in SEEDS:
		for way: String in WAYS:
			_runs.append([seed_value, way])
	print("seed  made       longest frame  frames until played")


func _process(_delta: float) -> bool:
	var now: int = Time.get_ticks_usec()
	if _demo == null:
		if _runs.is_empty():
			quit(1 if _failed else 0)
			return true
		_begin(_runs.pop_front())
		return false
	_longest = maxi(_longest, now - _last_tick)
	_frames += 1
	_last_tick = Time.get_ticks_usec()
	if _demo.world.level.name == _name or _frames > FRAMES_ALLOWED:
		_end()
	return false


# Build the scene on the last hand-made level and press L onto `run`'s seed.
func _begin(run: Array) -> void:
	_wanted = run[0]
	_way = run[1]
	_name = ("generated %d" if _way == "drawn" else "solved %d") % _wanted  # not shown: the level's own name
	_demo = load(SCENE).instantiate()
	_demo.solve_in_background = _way == "the pool"
	root.add_child(_demo)
	if _way != "drawn":
		_demo.rules.level_generator = LevelGenerator.CONSTRAINTS
	_demo._seed = _wanted - InfiltrationLevel.HAND_MADE.size()
	_demo._level_index = InfiltrationLevel.HAND_MADE.size() - 1
	_longest = 0
	_frames = 0
	var pressed: int = Time.get_ticks_usec()
	_demo.next_level()
	_longest = Time.get_ticks_usec() - pressed
	_last_tick = Time.get_ticks_usec()


func _end() -> void:
	var arrived: bool = _demo.world.level.name == _name
	print("%4d  %-9s  %10.1f ms  %d%s" % [_wanted, _way, _longest / 1000.0, _frames, "" if arrived else "  (never arrived)"])
	_failed = _failed or not arrived
	if arrived and _way != "drawn":
		_failed = _failed or _levels.get(_wanted, _demo.solved.data) != _demo.solved.data
		_levels[_wanted] = _demo.solved.data
	_demo.free()
	_demo = null
