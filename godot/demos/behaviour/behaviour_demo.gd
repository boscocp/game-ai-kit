## One guard, four ways to decide, swapped while it walks.
##
## The same guard on T14's room, written as a state machine, a behaviour tree,
## GOAP and an HTN (`ai_behaviour`). An intruder walks a fixed loop through
## the guard's half of the room, so there is always something to notice and
## lose. Space plays a turn, enter plays ten; 1-4 hand the guard to another
## brain without stopping it -- what the guard knows stays, what the brain
## remembers (a state, a plan) starts afresh -- and R starts the room again.
##
## Watch for the seams the task names: the state machine snaps from state to
## state, the tree reconsiders every turn, GOAP plans again every turn, and
## the HTN carries on down the method it chose. The status says, beside the
## brain playing, when that way of deciding is the right answer
## (`WaysToDecide`).
##
## Its own layout, not `BoardLayout`'s: that one centres the board and gives
## the status the strip to its left, which at eighteen columns is too narrow
## for these lines, and they ran over the board in white on green -- the
## owner could not read them. Here the board sits left, the status under it,
## and the legend and the brain's panel share a column on the right: no word
## is drawn on the board.
class_name BehaviourDemo
extends Node2D

## Space round the board and between the panels, as `BoardLayout`'s.
const GUTTER: float = BoardLayout.GUTTER
## Where the board's top-left corner sits: room for the axis numbers.
const BOARD_CORNER := Vector2(48.0, 48.0)
## How tall the legend is, above the brain's panel in the right column.
const LEGEND_HEIGHT: float = 210.0

@onready var _board: BoardView = $BoardView
@onready var _view: BehaviourView = $BehaviourView
@onready var _status: Label = $Interface/Status
@onready var _legend: Legend = $Interface/Legend
@onready var _panel: BrainPanel = $Interface/BrainPanel

var world: BehaviourWorld


func _ready() -> void:
	_legend.set_entries([
		[BehaviourView.GUARD, "the guard (line: facing)"],
		[BehaviourView.SIGHT, "what the guard sees"],
		[BehaviourView.LAST_KNOWN, "ring: last seen or heard"],
		[BehaviourView.STEP, "dots: its move this turn"],
		[BehaviourView.INTRUDER, "the intruder's loop"],
		[BrainPanel.LIT, "panel: the state or step now"],
		[BrainPanel.SHARED, "panel: one subtree, two branches"],
		[BoardView.tile_texture(BoardView.TREES), "trees: slow, block sight"],
		[BoardView.tile_texture(BoardView.WALL), "wall"],
	] as Array[Array])
	restart()
	_lay_out()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.is_pressed() or key.echo:
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_4:
		swap_brain(key.keycode - KEY_1)
	elif key.keycode == KEY_SPACE:
		step_decision()
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		for _turn: int in range(10):
			step_decision()
	elif key.keycode == KEY_R:
		restart()


## The room afresh, the guard thinking with the state machine.
func restart() -> void:
	world = BehaviourWorld.new(GuardFsm.new())
	_refresh()


## Hand the guard to brain `index` -- 0 state machine, 1 tree, 2 GOAP,
## 3 HTN -- where it stands, mid-round.
func swap_brain(index: int) -> void:
	world.use([GuardFsm.new(), GuardTree.new(), GuardGoap.new(), GuardHtn.new()][index])
	_refresh()


## One turn: the intruder steps, the guard decides and moves, then looks.
func step_decision() -> void:
	world.step()
	_refresh()


## What the guard is deciding with: the brain, its deed and its thinking --
## the state, the trail, the plan, the method -- and the suspicion it rests
## on, for `test/menu/demo_overlays.gd`.
func decision_overlay() -> Dictionary:
	return {"brain": world.brain.brain_name(), "deed": world.brain.deed,
		"thinking": world.brain.thinking(), "suspicion": world.senses.suspicion.level}


## The status line's words. What the brain is thinking is the panel's. Three
## lines, each under the board's width (864 px): the window has room under
## the board for three and no more, and a line that wrapped would push the
## last one off the bottom.
func status_text() -> String:
	var brain: GuardBrain = world.brain
	var lines: Array[String] = [
		"turn %d  ·  the guard thinks with: %s -- right when: %s" % [world.turn, brain.brain_name(), _when_right(brain.brain_name())],
		"suspicion %.0f  ·  deed: %s  ·  caught %d time(s)%s" % [world.senses.suspicion.level,
			brain.deed if brain.deed != "" else "(decides on the next turn)", world.catches,
			"  ·  CAUGHT -- it starts its loop again" if world.caught else ""],
		"1 state machine  ·  2 behaviour tree  ·  3 GOAP  ·  4 HTN  ·  space: a turn  ·  enter: ten  ·  R: again",
	]
	return "\n".join(lines)


# The board left, the status under it, the legend and the brain's panel in
# the column to its right.
func _lay_out() -> void:
	var window: Vector2 = BoardLayout.window_size()
	position = BOARD_CORNER
	var board := Rect2(BOARD_CORNER, BoardView.pixel_size(world.room.graph))
	_status.position = Vector2(board.position.x, board.end.y + GUTTER / 2.0)
	_status.size = Vector2(board.size.x, window.y - _status.position.y)
	var column: float = board.end.x + GUTTER
	_legend.position = Vector2(column, board.position.y)
	_legend.size = Vector2(window.x - column - GUTTER, LEGEND_HEIGHT)
	_panel.position = Vector2(column, board.position.y + LEGEND_HEIGHT + GUTTER)
	_panel.size = Vector2(window.x - column - GUTTER, window.y - _panel.position.y - GUTTER)


func _refresh() -> void:
	_board.draw_board(world.room.graph, [] as Array[Vector2i], [] as Array[Vector2i], _trees())
	_view.show_world(world, _board)
	_panel.show_brain(world.brain)
	_status.text = status_text()


# The room's dear ground is trees, which the board would otherwise draw from
# their cost alone as rough ground -- as the stealth demo draws them.
func _trees() -> Dictionary:
	var tiles: Dictionary = {}
	var graph: GridGraph = world.room.graph
	for index: int in range(graph.width * graph.height):
		var cell := Vector2i(index % graph.width, index / graph.width)
		if graph.cost_at(cell) == StealthRoom.TREE:
			tiles[cell] = BoardView.TREES
	return tiles


static func _when_right(brain: String) -> String:
	for row: Array in WaysToDecide.when_each_is_right():
		if row[0] == brain:
			return row[1]
	return ""

