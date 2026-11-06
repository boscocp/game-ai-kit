## A map for the XCOM-style mode, built by wave function collapse (T96), and
## the build shown again a step at a time.
##
## The tiles are `tiles.json` beside this file -- a byte-for-byte copy of
## `spec/squad/tiles.json` -- on the tactical map's 14 by 9, the squads'
## eight starts pinned to open ground. `WaveCollapse` builds from
## `first_seed`, restarting from the next seed on a contradiction; the map it
## returns is put to `SquadMapCheck`, and a map that cannot be played is
## refused and the seed after it built. So a map is the first seed, counting
## up, that collapses with no contradiction into a map the rules can play;
## `contradictions` and `unplayable` say what happened to the others.
##
## **Watching it** (B in the scene): every seed tried is collapsed again with
## the trace on, and `step` replays it -- one cell a step, the cell of least
## entropy shown before it collapses, the tiles each open cell has left
## dropping as the collapse is propagated, and a contradiction left on the
## board where it emptied a cell. Then the next seed, until the map that was
## kept. It is a replay of the build that already happened, so watching it
## cannot build a different map from not watching it.
##
## Complexity: a collapse of 126 cells is about 50 ms headless on the
## author's machine; a step replays a few events.
##
## When not to use it: as a map format. The map built is rows of the
## tactical letters, read by `SquadScenario`; this only makes them.
class_name SquadMapBuild
extends RefCounted

## The size of every map: the tactical map's, which the board and the
## layout of the scene are made for.
const SIZE: Vector2i = Vector2i(14, 9)
const TILES_PATH: String = "res://game/squad/tiles.json"
## How many maps may be refused as unplayable before the build gives up.
const TRIES: int = 20

static var _tile_set: Dictionary = {}

## The seed the build started from.
var first_seed: int = 1
## The seed of the map kept; -1 when no seed gave one.
var seed_used: int = -1
## The map kept, rows of `TacticalRules`' letters; empty when none was.
var rows: Array[String] = []
## The cell ("x,y") each contradiction emptied, in the order met.
var contradictions: Array[String] = []
## Why each map refused could not be played, in English, in order.
var unplayable: Array[String] = []

# Every seed tried, in order: {"seed", "outcome" ("contradiction",
# "refused" or "kept"), "why"}.
var _tried: Array[Dictionary] = []
# The replay: which seed is shown, its trace, and how far into it.
var _shown: int = -1
var _trace: Array[Dictionary] = []
var _next_event: int = 0
var _left: Dictionary = {}
var _collapsed: Dictionary = {}
var _choosing: String = ""
var _stuck: String = ""


## A map from `from_seed`, built now; watch it with `step`.
func _init(from_seed: int) -> void:
	first_seed = from_seed
	_build()


## The tile set, read once.
static func tile_set() -> Dictionary:
	if _tile_set.is_empty():
		_tile_set = JSON.parse_string(FileAccess.get_file_as_string(TILES_PATH))
	return _tile_set


## Every start cell ("x,y") pinned to open ground: no piece starts in water
## or rock, and the pieces keep the cells the rules know them by.
static func pinned() -> Dictionary:
	var pins: Dictionary = {}
	for start: Array in SquadScenario.starts():
		pins[TileGrid.cell_name(start[0])] = [TacticalRules.PLAIN]
	return pins


## The collapse of a squad map from `from_seed`.
static func collapse(from_seed: int) -> WaveCollapse:
	return WaveCollapse.new(TileGrid.problem(tile_set(), SIZE, pinned()), TileGrid.weights_of(tile_set()), from_seed)


## The last seed tried, kept or not: the next build starts after it.
func last_seed() -> int:
	return int(_tried[-1]["seed"]) if not _tried.is_empty() else first_seed


# Collapse from `first_seed` until a map is kept, or `TRIES` are refused.
func _build() -> void:
	var next_seed: int = first_seed
	for _refusal: int in range(TRIES):
		var making: WaveCollapse = collapse(next_seed)
		var found: Dictionary = making.solve()
		for number: int in range(making.restarts):
			_tried.append({"seed": next_seed + number, "outcome": "contradiction", "why": making.contradictions[number]})
		contradictions.append_array(making.contradictions)
		if found.is_empty():
			return
		next_seed += making.restarts
		var built: Array[String] = TileGrid.rows_of(found, SIZE)
		var why: String = SquadMapCheck.why_unplayable(built)
		_tried.append({"seed": next_seed, "outcome": "refused" if why != "" else "kept", "why": why})
		if why == "":
			rows = built
			seed_used = next_seed
			return
		unplayable.append(why)
		next_seed += 1


# -- watching it ---------------------------------------------------------------

## Start the replay at the first seed tried, its first cell about to collapse.
func watch() -> void:
	_shown = -1
	_next_attempt()
	step()


## The next step: the cell about to collapse is collapsed and propagated,
## and the next cell of least entropy is shown -- or, at the end of a seed
## that failed, the next seed starts.
func step() -> void:
	if _next_event >= _trace.size() and not finished():
		_next_attempt()
	while _next_event < _trace.size():
		var event: Dictionary = _trace[_next_event]
		_next_event += 1
		_apply(event)
		if event["event"] == "choose":
			return


## True once the replay has shown the whole of the map kept, or every seed
## when none was.
func finished() -> bool:
	return _shown >= _tried.size() - 1 and _next_event >= _trace.size()


## The seed the replay is showing, and what became of it: "contradiction",
## "refused" or "kept"; {} before `watch`.
func shown() -> Dictionary:
	return _tried[_shown] if _shown >= 0 and _shown < _tried.size() else {}


## The cell about to collapse, or (-1, -1) when none is.
func choosing() -> Vector2i:
	return TileGrid.cell_of(_choosing) if _choosing != "" else Vector2i(-1, -1)


## The cell this seed's contradiction emptied, or (-1, -1).
func stuck() -> Vector2i:
	return TileGrid.cell_of(_stuck) if _stuck != "" else Vector2i(-1, -1)


## The tiles `cell` may still be, as the replay stands.
func tiles_left(cell: Vector2i) -> Array:
	return _left.get(TileGrid.cell_name(cell), [])


## The entropy of the cell about to collapse; 0 when none is.
func choosing_entropy() -> float:
	return WaveCollapse.entropy_of(_left.get(_choosing, []), TileGrid.weights_of(tile_set()))


## How many tiles each cell not yet collapsed may still be, by cell.
func counts() -> Dictionary[Vector2i, String]:
	var shown_counts: Dictionary[Vector2i, String] = {}
	for name: String in _left:
		if not _collapsed.has(name):
			shown_counts[TileGrid.cell_of(name)] = str((_left[name] as Array).size())
	return shown_counts


## The map as the replay stands: each collapsed cell its tile, every other
## open ground, under its count.
func partial_rows() -> Array[String]:
	var drawn: Array[String] = TileGrid.rows_of(_collapsed, SIZE)
	for y: int in range(drawn.size()):
		drawn[y] = drawn[y].replace(TileGrid.UNDECIDED, TacticalRules.PLAIN)
	return drawn


func _next_attempt() -> void:
	_shown += 1
	_trace.clear()
	_next_event = 0
	_collapsed.clear()
	_choosing = ""
	_stuck = ""
	if _shown >= _tried.size():
		return
	var replay: WaveCollapse = collapse(int(_tried[_shown]["seed"]))
	replay.record = true
	replay.attempt(int(_tried[_shown]["seed"]))
	_trace = replay.trace
	_left = replay.problem.domains.duplicate(true)


# One event of the trace, applied to what the board shows.
func _apply(event: Dictionary) -> void:
	var name: String = event["variable"]
	match event["event"]:
		"choose":
			_choosing = name
		"assign":
			_collapsed[name] = event["value"]
			_left[name] = [event["value"]]
			_choosing = ""
		"prune":
			(_left[name] as Array).erase(event["value"])
		"contradiction":
			_stuck = name
