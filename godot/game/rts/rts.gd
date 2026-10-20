## The RTS demo: you against the commander, or two computers to watch.
##
## T20's game. You play west, in blue, from the bottom left; the computer
## plays east, a `RtsCommander` at the level shown, planning with STRIPS or
## the HTN. Press V to hand your side to the priority queues and watch the
## two play. Everything the computer is thinking is in the panel on the
## right and on the board: its goal, its plan with the time each step
## waits, its squads' choices and, with I, what it believes about the map.
##
## Your orders and the computer's pass through the same door
## (`RtsMatch.give`, `RtsRules`): you may not order what it may not, and it
## sees only what its units see. Controls are in `HELP`.
##
## When not to use it: as the match to measure. `test/rts_match.gd` plays
## the same match headless, faster and with no person in it.
class_name RtsGame
extends Node2D

const HELP: String = "drag: select · right click: move, attack, gather · B D L T E: build (a worker) · " \
	+ "W 1 2 3: train · space: pause · + -: speed · V: watch · C: level · H: planner · I: influence · F: fog · R: again"
const SPEEDS: Array[int] = [1, 2, 4, 8]
const BUILD_KEYS: Dictionary = {KEY_B: RtsKinds.BARRACKS, KEY_D: RtsKinds.DEPOT, KEY_L: RtsKinds.LAB,
	KEY_T: RtsKinds.TOWER, KEY_E: RtsKinds.BASE}
const TRAIN_KEYS: Dictionary = {KEY_W: RtsKinds.WORKER, KEY_1: RtsKinds.RUNNER, KEY_2: RtsKinds.SHIELD,
	KEY_3: RtsKinds.MORTAR}
const SEED: int = 20

@onready var _view: RtsView = $RtsView
@onready var _thinking: RtsThinking = $RtsThinking
@onready var _header: Label = $Interface/Header
@onready var _panel: Label = $Interface/Thinking
@onready var _legend: Legend = $Interface/Legend

var world: RtsWorld
var played: RtsMatch
## The computer's side, and in watch mode the side standing in for you.
var computer: RtsSide
var stand_in: RtsSide
var watching: bool = false
var paused: bool = false
var speed_index: int = 0
var level_index: int = 1
var planner: BuildOrder.Planner = BuildOrder.Planner.STRIPS
## The last thing the rules said to one of your orders.
var last_refusal: String = ""
## F: draw the whole board, fog lifted from the screen (never from a side).
var reveal: bool = false

var _drag_from: Vector2 = Vector2.ZERO


func _ready() -> void:
	_view.art = RtsArt.new(RtsView.SIDE_COLOURS)
	_legend.set_entries([
		[RtsView.SIDE_COLOURS[RtsScenario.WEST], "you: west"],
		[RtsView.SIDE_COLOURS[RtsScenario.EAST], "the computer: east"],
		[RtsThinking.STATE_COLOURS[Squad.ADVANCE], "a squad advancing, to its region"],
		[RtsThinking.STATE_COLOURS[Squad.FIGHT], "a squad fighting"],
		[RtsThinking.STATE_COLOURS[Squad.RETREAT], "a squad falling back"],
		[RtsThinking.PLAN_COLOUR, "where its plan will build"],
		[RtsView.DEPOSIT_COLOURS[RtsKinds.ROCKS], "rocks: ore"],
		[RtsView.DEPOSIT_COLOURS[RtsKinds.VENT], "a vent: magma"],
	] as Array[Array])
	restart()


## A new match from the same seed, with the level, planner and mode chosen.
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
	_refresh()


func _physics_process(_delta: float) -> void:
	if paused or RtsVictory.winner(world) != RtsVictory.UNDECIDED:
		return
	played.play(SPEEDS[speed_index])
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


func _on_mouse_button(button: InputEventMouseButton) -> void:
	if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		if _view.placing != "":
			_view.placing = ""
		else:
			_order_at(RtsView.to_cell(button.position), button.position)
	elif button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		if _view.placing != "":
			_place(RtsView.to_cell(button.position))
		else:
			_drag_from = button.position
			_view.dragging = Rect2(button.position, Vector2.ZERO)
	elif button.button_index == MOUSE_BUTTON_LEFT and _view.dragging.position != Vector2.ZERO:
		_select(Rect2(_drag_from, button.position - _drag_from).abs())
		_view.dragging = Rect2()
	_refresh()


func _on_mouse_motion(motion: InputEventMouseMotion) -> void:
	if _view.dragging.position != Vector2.ZERO:
		_view.dragging = Rect2(_drag_from, motion.position - _drag_from)
	_view.placing_at = RtsView.to_cell(motion.position)
	_view.queue_redraw()


func _on_key(code: Key) -> void:
	if BUILD_KEYS.has(code) and not watching:
		_view.placing = BUILD_KEYS[code]
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


# Your units inside `box`, or the one under a click: fighters and workers
# by box, anything of yours by click.
func _select(box: Rect2) -> void:
	_view.selected.clear()
	var clicked: bool = box.size.length() < 4.0
	for unit: Dictionary in RtsSnapshot.of(world, RtsScenario.WEST).mine():
		var at: Vector2 = RtsView.to_screen(unit["position"])
		if clicked and at.distance_to(box.position) <= RtsView.CELL * 0.6:
			_view.selected[unit["id"]] = true
			return
		if not clicked and box.has_point(at) and not RtsKinds.is_building(unit["kind"]):
			_view.selected[unit["id"]] = true


# A right click: attack what is there, gather from it, or walk to it.
func _order_at(cell: Vector2i, point: Vector2) -> void:
	var ids: Array[int] = _selected_movers()
	if ids.is_empty() or watching:
		return
	var view: RtsSnapshot = RtsSnapshot.of(world, RtsScenario.WEST)
	for unit: Dictionary in view.units:
		if RtsView.to_screen(unit["position"]).distance_to(point) > RtsView.CELL * 0.6:
			continue
		if RtsKinds.is_deposit(unit["kind"]):
			_give(RtsCommand.gather(ids, unit["id"]))
			return
		if unit["side"] != RtsScenario.WEST:
			_give(RtsCommand.attack(ids, unit["id"]))
			return
	_give(RtsCommand.move(ids, cell))


func _place(cell: Vector2i) -> void:
	for id: int in _selected_movers():
		var unit: RtsUnit = world.unit(id)
		if unit != null and unit.kind == RtsKinds.WORKER:
			_give(RtsCommand.build(id, _view.placing, cell))
			_view.placing = ""
			return
	last_refusal = "select a worker to build with"
	_view.placing = ""


func _train(kind: String) -> void:
	for id: int in _view.selected:
		var unit: RtsUnit = world.unit(id)
		if unit != null and kind in RtsKinds.of(unit.kind, "trains"):
			_give(RtsCommand.train(id, kind))
			return
	last_refusal = "select a building that trains a %s" % kind


func _give(command: RtsCommand) -> void:
	last_refusal = played.give(RtsScenario.WEST, command)


func _selected_movers() -> Array[int]:
	var ids: Array[int] = []
	for id: int in _view.selected:
		var unit: RtsUnit = world.unit(id)
		if unit != null and not RtsKinds.is_building(unit.kind):
			ids.append(id)
	return ids


func _refresh() -> void:
	var yours: RtsSnapshot = RtsSnapshot.of(world, RtsScenario.WEST)
	_view.view = yours
	_view.tick = world.tick
	_view.everything = reveal or watching
	_thinking.view = RtsSnapshot.of(world, computer.side)
	_header.text = _header_text(yours)
	_panel.text = "\n".join(_thinking.lines())
	_view.queue_redraw()
	_thinking.queue_redraw()


func _header_text(yours: RtsSnapshot) -> String:
	var seconds: int = world.tick / RtsWorld.TICKS_PER_SECOND
	var who: String = "the queues (watching)" if watching else "you"
	var line: String = "%s, west  vs  the commander, east: %s, %s  ·  %d:%02d  ·  x%d%s" % [who,
		computer.level.name, "STRIPS" if planner == BuildOrder.Planner.STRIPS else "HTN",
		seconds / 60, seconds % 60, SPEEDS[speed_index], "  (paused)" if paused else ""]
	line += "\nore %d  magma %d  supply %d/%d" % [yours.resources[RtsKinds.ORE], yours.resources[RtsKinds.MAGMA],
		yours.supply_used, yours.supply_cap]
	if RtsVictory.winner(world) != RtsVictory.UNDECIDED:
		line += "  ·  over: " + RtsVictory.why(world)
	elif last_refusal != "":
		line += "  ·  " + last_refusal
	return line + "\n" + HELP
