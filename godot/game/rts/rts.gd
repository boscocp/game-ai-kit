## The RTS demo: you against the commander, or two computers to watch.
##
## T20's game. You play west, in blue, from the bottom left; the computer
## plays east, a `RtsCommander` at the level shown, planning with STRIPS or
## the HTN. Press V to hand your side to the priority queues and watch the
## two play. Everything the computer is thinking is in the panel on the
## right and on the board: its goal, its plan with the time each step
## waits, its squads' choices and, with I, what it believes about the map.
##
## The screen is laid out as StarCraft's and Age of Empires' are: a bar of
## resources on top, the map in a window the camera moves over, and along
## the bottom a minimap and a command card whose buttons say what each
## thing costs and why it cannot be had yet. It starts paused, at half
## speed: the whole clock is slowed, both sides alike, so a person has
## time to read -- the rules and the AIs are the ones `test/rts_match.gd`
## measures, only shown slower.
##
## Your orders and the computer's pass through the same door
## (`RtsMatch.give`, `RtsRules`): you may not order what it may not, and it
## sees only what its units see.
##
## When not to use it: as the match to measure. `test/rts_match.gd` plays
## the same match headless, faster and with no person in it.
class_name RtsGame
extends Node2D

## Ticks of match a frame, at each speed: a frame is a tick at 1x.
const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0]
const FIRST_SPEED: int = 1
const BUILD_KEYS: Dictionary = {KEY_B: RtsKinds.BARRACKS, KEY_D: RtsKinds.DEPOT, KEY_L: RtsKinds.LAB,
	KEY_T: RtsKinds.TOWER, KEY_E: RtsKinds.BASE}
const TRAIN_KEYS: Dictionary = {KEY_W: RtsKinds.WORKER, KEY_1: RtsKinds.RUNNER, KEY_2: RtsKinds.SHIELD,
	KEY_3: RtsKinds.MORTAR}
## How near a click must be to a unit to mean it, in cells.
const CLICK_REACH: float = 0.75
const SEED: int = 20

@onready var _view: RtsView = $Map/RtsView
@onready var _thinking: RtsThinking = $Map/RtsThinking
@onready var _header: Label = $Interface/Header
@onready var _panel: Label = $Interface/Thinking
@onready var _legend: Legend = $Interface/Legend
@onready var _minimap: RtsMinimap = $Interface/Minimap
@onready var _card: RtsCommandCard = $Interface/Card

var world: RtsWorld
var played: RtsMatch
## The computer's side, and in watch mode the side standing in for you.
var computer: RtsSide
var stand_in: RtsSide
var watching: bool = false
var paused: bool = true
var speed_index: int = FIRST_SPEED
var level_index: int = 1
var planner: BuildOrder.Planner = BuildOrder.Planner.STRIPS
## The last thing the rules said to one of your orders.
var last_refusal: String = ""
## F: draw the whole board, fog lifted from the screen (never from a side).
var reveal: bool = false

var _drag_from: Vector2 = Vector2.ZERO
var _dragging: bool = false
# Fractions of a tick owed at the slower speeds.
var _owed: float = 0.0


func _ready() -> void:
	_view.art = RtsArt.new(RtsView.SIDE_COLOURS)
	_minimap.board = _view
	_card.chosen.connect(_on_card)
	_legend.set_entries([
		[RtsView.SIDE_COLOURS[RtsScenario.WEST], "you: west"],
		[RtsView.SIDE_COLOURS[RtsScenario.EAST], "the computer: east"],
		[RtsThinking.STATE_COLOURS[Squad.ADVANCE], "its squad advancing, to its region"],
		[RtsThinking.STATE_COLOURS[Squad.FIGHT], "its squad fighting"],
		[RtsThinking.STATE_COLOURS[Squad.RETREAT], "its squad falling back"],
		[RtsThinking.PLAN_COLOUR, "where its plan will build"],
	] as Array[Array])
	restart()


## A new match from the same seed, with the level, planner and mode chosen,
## paused, the camera on your base.
func restart() -> void:
	world = RtsScenario.start(SEED)
	var level: Difficulty = RtsLevels.presets()[level_index]
	computer = RtsCommander.new(RtsScenario.EAST, level, SEED * 7, planner)
	stand_in = QueueSide.new(RtsScenario.WEST, level, SEED * 11)
	var sides: Dictionary = {RtsScenario.EAST: computer}
	if watching:
		sides[RtsScenario.WEST] = stand_in
	played = RtsMatch.new(world, SEED, sides)
	_view.world = world
	_view.selected.clear()
	_view.placing = ""
	_thinking.side = computer
	last_refusal = ""
	paused = true
	_owed = 0.0
	RtsView.frame_at(Vector2(RtsScenario.home(RtsScenario.WEST)) - RtsView.shown_cells().size / 2.0)
	_refresh()


func _process(delta: float) -> void:
	var direction := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	direction += _edge_push(get_viewport().get_mouse_position())
	if direction != Vector2.ZERO:
		RtsView.pan(direction.limit_length(1.0) * RtsView.PAN_SPEED * delta)
		_redraw()


func _physics_process(_delta: float) -> void:
	if paused or RtsVictory.winner(world) != RtsVictory.UNDECIDED:
		return
	_owed += SPEEDS[speed_index]
	var ticks: int = floori(_owed)
	_owed -= ticks
	if ticks > 0:
		played.play(ticks)
		_refresh()


## One decision of the computer's: the match played up to and through its
## next decision, which is what `test/demo_overlays.gd` steps by.
func step_decision() -> void:
	played.play(played.decide_every)
	_refresh()


## What the computer is reasoning with, for `test/demo_overlays.gd`: its
## goal, its plan with each step's wait, and its squads' states and odds.
func decision_overlay() -> Dictionary:
	var thinking: Dictionary = computer.overlay(RtsSnapshot.of(world, computer.side))
	var shown: Dictionary = {"tick": world.tick, "level": computer.level.name, "goal": thinking["goal"]}
	var plan: Array[String] = []
	for step: Dictionary in thinking["plan"]:
		plan.append("%s at %.1f s" % [step["step"], step["starts"]])
	shown["plan"] = plan if not plan.is_empty() else ["goal met"]
	shown["waiting"] = thinking["waiting"] if thinking["waiting"] != "" else "nothing"
	shown["income"] = BuildSchedule.income(RtsSnapshot.of(world, computer.side))
	if not thinking["squads"].is_empty():
		shown["squads"] = thinking["squads"]
	return shown


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		_on_mouse_button(button)
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		_on_mouse_motion(motion)
		return
	var key := event as InputEventKey
	if key != null and key.is_pressed() and not key.echo:
		_on_key(key.keycode)
		_refresh()


# The mouse in the map window's edge pans that way, as in every RTS.
static func _edge_push(mouse: Vector2) -> Vector2:
	var rect: Rect2 = RtsView.MAP_RECT
	if not rect.has_point(mouse):
		return Vector2.ZERO
	var inside: Vector2 = mouse - rect.position
	var push := Vector2.ZERO
	push.x = -1.0 if inside.x < RtsView.EDGE else (1.0 if inside.x > rect.size.x - RtsView.EDGE else 0.0)
	push.y = -1.0 if inside.y < RtsView.EDGE else (1.0 if inside.y > rect.size.y - RtsView.EDGE else 0.0)
	return push


func _on_mouse_button(button: InputEventMouseButton) -> void:
	var on_map: bool = RtsView.MAP_RECT.has_point(button.position)
	var local: Vector2 = button.position - RtsView.MAP_RECT.position
	if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed and on_map:
		if _view.placing != "":
			_view.placing = ""
		else:
			_order_at(RtsView.to_cell(button.position), local)
	elif button.button_index == MOUSE_BUTTON_LEFT and button.pressed and on_map:
		if _view.placing != "":
			_place(RtsView.to_cell(button.position))
		else:
			_drag_from = local
			_dragging = true
	elif button.button_index == MOUSE_BUTTON_LEFT and not button.pressed and _dragging:
		_dragging = false
		_select(Rect2(_drag_from, local - _drag_from).abs())
		_view.dragging = Rect2()
	_refresh()


func _on_mouse_motion(motion: InputEventMouseMotion) -> void:
	if _dragging:
		_view.dragging = Rect2(_drag_from, motion.position - RtsView.MAP_RECT.position - _drag_from)
	_view.placing_at = RtsView.to_cell(motion.position)
	if _view.placing != "":
		_view.placing_refusal = _why_not_here(_view.placing, _view.placing_at)
	_view.queue_redraw()


# What the rules would say to building `what` at `cell` with a selected
# worker: asked, never given -- `why_refused` changes nothing.
func _why_not_here(what: String, cell: Vector2i) -> String:
	var builder: int = _selected_worker()
	if builder < 0:
		return "select a worker to build with"
	return RtsRules.why_refused(world, RtsScenario.WEST, RtsCommand.build(builder, what, cell))


func _on_key(code: Key) -> void:
	if BUILD_KEYS.has(code) and not watching:
		_on_card("build", BUILD_KEYS[code])
	elif TRAIN_KEYS.has(code) and not watching:
		_train(TRAIN_KEYS[code])
	match code:
		KEY_SPACE:
			paused = not paused
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			speed_index = mini(speed_index + 1, SPEEDS.size() - 1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			speed_index = maxi(speed_index - 1, 0)
		KEY_V:
			watching = not watching
			restart()
		KEY_C:
			level_index = (level_index + 1) % RtsLevels.presets().size()
			restart()
		KEY_H:
			planner = BuildOrder.Planner.HTN if planner == BuildOrder.Planner.STRIPS else BuildOrder.Planner.STRIPS
			restart()
		KEY_I:
			_thinking.show_influence = not _thinking.show_influence
		KEY_F:
			reveal = not reveal
		KEY_R:
			restart()


# A button on the command card, or its key: a building waits for a click
# on the map; a unit is trained at once.
func _on_card(action: String, what: String) -> void:
	if action == "train":
		_train(what)
	elif action == "repair":
		_send_a_repairer()
	elif _selected_worker() >= 0:
		_view.placing = what
		_say("click open ground to put the %s -- green is a place it can go; right click cancels" % what, false)
	else:
		_say("select a worker to build with", true)
	_refresh()


# Your units inside `box` (map window points), or the one under a click:
# fighters and workers by box, anything of yours by click -- and, when a
# click finds nothing of yours, whatever you can see there, to read about:
# how much a rock has left, how hurt an enemy is. It takes no orders.
func _select(box: Rect2) -> void:
	_view.selected.clear()
	var clicked: bool = box.size.length() < 4.0
	var view: RtsSnapshot = RtsSnapshot.of(world, RtsScenario.WEST)
	for unit: Dictionary in view.mine():
		var at: Vector2 = RtsView.to_screen(unit["position"])
		if clicked and at.distance_to(box.position) <= RtsView.CELL * CLICK_REACH:
			_view.selected[unit["id"]] = true
			return
		if not clicked and box.has_point(at) and not RtsKinds.is_building(unit["kind"]):
			_view.selected[unit["id"]] = true
	for unit: Dictionary in view.units:
		if clicked and RtsView.to_screen(unit["position"]).distance_to(box.position) <= RtsView.CELL * CLICK_REACH:
			_view.selected[unit["id"]] = true
			return


# A right click at `point` (a map window point): attack what is there,
# gather from it, or walk to it.
func _order_at(cell: Vector2i, point: Vector2) -> void:
	var ids: Array[int] = _selected_movers()
	if ids.is_empty() or watching:
		return
	var view: RtsSnapshot = RtsSnapshot.of(world, RtsScenario.WEST)
	for unit: Dictionary in view.units:
		if RtsView.to_screen(unit["position"]).distance_to(point) > RtsView.CELL * CLICK_REACH:
			continue
		if RtsKinds.is_deposit(unit["kind"]):
			_give(RtsCommand.gather(ids, unit["id"]))
			return
		if unit["side"] != RtsScenario.WEST:
			_give(RtsCommand.attack(ids, unit["id"]))
			return
		if RtsKinds.is_building(unit["kind"]) and _selected_worker() >= 0:
			_give(RtsCommand.repair(ids, unit["id"]))
			return
	_give(RtsCommand.move(ids, cell))


# The command card's Repair: the worker nearest the selected building sent
# to mend it, through the same door as a right click.
func _send_a_repairer() -> void:
	var building: RtsUnit = null
	for id: int in _view.selected:
		if world.unit(id) != null and world.unit(id).side == RtsScenario.WEST and RtsKinds.is_building(world.unit(id).kind):
			building = world.unit(id)
	var nearest: RtsUnit = null
	for unit: RtsUnit in world.units():
		if unit.side != RtsScenario.WEST or unit.kind != RtsKinds.WORKER or building == null:
			continue
		if nearest == null or unit.position.distance_to(building.position) < nearest.position.distance_to(building.position):
			nearest = unit
	if nearest == null:
		_say("no worker to send", true)
		return
	_give(RtsCommand.repair([nearest.id] as Array[int], building.id))
	if last_refusal == "":
		_say("a worker is on its way to mend the %s" % building.kind, false)


func _place(cell: Vector2i) -> void:
	var builder: int = _selected_worker()
	var what: String = _view.placing
	if builder < 0:
		_say("select a worker to build with", true)
		_view.placing = ""
		return
	_give(RtsCommand.build(builder, what, cell))
	if last_refusal != "":
		return
	_view.placing = ""
	var seconds: float = float(RtsKinds.of(what, "ticks")) / RtsWorld.TICKS_PER_SECOND
	_say("%s placed -- the worker walks there and builds it (%d s of game)" % [what, roundi(seconds)], false)


# The first worker selected, or -1 when none is.
func _selected_worker() -> int:
	for id: int in _selected_movers():
		if world.unit(id).kind == RtsKinds.WORKER:
			return id
	return -1


func _train(kind: String) -> void:
	for id: int in _view.selected:
		var unit: RtsUnit = world.unit(id)
		if unit != null and unit.side == RtsScenario.WEST and kind in RtsKinds.of(unit.kind, "trains"):
			_give(RtsCommand.train(id, kind))
			return
	_say("select a building that trains a %s" % kind, true)


func _give(command: RtsCommand) -> void:
	last_refusal = played.give(RtsScenario.WEST, command)
	if last_refusal != "":
		_say(last_refusal, true)


# A message across the top of the map for a few seconds: what happened to
# the order just given. A refusal is red.
func _say(words: String, bad: bool) -> void:
	_view.toast = words
	_view.toast_bad = bad
	_view.toast_until = Time.get_ticks_msec() + 3500


func _selected_movers() -> Array[int]:
	var ids: Array[int] = []
	for id: int in _view.selected:
		var unit: RtsUnit = world.unit(id)
		if unit != null and unit.side == RtsScenario.WEST and not RtsKinds.is_building(unit.kind):
			ids.append(id)
	return ids


func _refresh() -> void:
	var yours: RtsSnapshot = RtsSnapshot.of(world, RtsScenario.WEST)
	_view.view = yours
	_view.tick = world.tick
	_view.everything = reveal or watching
	_thinking.view = RtsSnapshot.of(world, computer.side)
	_header.text = _header_text(yours)
	_panel.text = "What the computer is thinking\n" + "\n".join(_thinking.lines())
	_card.show_selection(yours, _view.selected)
	_redraw()


func _redraw() -> void:
	_view.queue_redraw()
	_thinking.queue_redraw()
	_minimap.queue_redraw()


func _header_text(yours: RtsSnapshot) -> String:
	var seconds: int = world.tick / RtsWorld.TICKS_PER_SECOND
	var who: String = "the queues (watching)" if watching else "you"
	var state: String = "PAUSED -- space to play" if paused else "speed x%s (+ -)" % SPEEDS[speed_index]
	var line: String = "ore %d   magma %d   supply %d/%d   |   %d:%02d  %s   |   %s (west, blue)  vs  the commander (east, red): %s, %s" % [
		yours.resources[RtsKinds.ORE], yours.resources[RtsKinds.MAGMA], yours.supply_used, yours.supply_cap,
		seconds / 60, seconds % 60, state, who, computer.level.name,
		"STRIPS" if planner == BuildOrder.Planner.STRIPS else "HTN"]
	if RtsVictory.winner(world) != RtsVictory.UNDECIDED:
		return line + "\nover: " + RtsVictory.why(world) + " -- R plays again"
	if last_refusal != "":
		return line + "\n" + last_refusal
	return line + "\nV watch two computers · C level · H planner · I influence · F fog · R again · arrows or the edge: look round"
