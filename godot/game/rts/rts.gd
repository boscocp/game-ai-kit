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
## time to read -- the rules and the AIs are the ones `test/rts/rts_match.gd`
## measures, only shown slower.
##
## K puts T25's human clock on the computer (`RtsHumanClock`): it answers
## what it sees only after a person's reaction time, and gives no more
## commands in five seconds than a person did; the thinking view then draws
## the late enemy it was handed, hollow, threaded to where it stands now
## (`RtsThinking.clock`). M shows the meter, each computer side's share of
## the frame beside its base (`RtsMeter`), hidden until asked. Opened with
## `-- --record` (`make record-rts`), every match you play to its end is
## kept in `data/rts/`; `make measure-rts-clock` turns those into the
## clock's values, which the game only reads.
##
## G switches T151's flock (`RtsFlock`): a group sent to one cell, by you or
## by the computer, walks as a flock instead of filing into a column, and
## the first unit of your selection that is in one shows its three forces.
##
## Your orders and the computer's pass through the same door
## (`RtsMatch.give`, `RtsRules`): you may not order what it may not, and it
## sees only what its units see.
##
## When not to use it: as the match to measure. `test/rts/rts_match.gd` plays
## the same match headless, faster and with no person in it.
class_name RtsGame
extends Node2D

## Ticks of match a frame, at each speed: a frame is a tick at 1x.
const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0]
const FIRST_SPEED: int = 1
const BUILD_KEYS: Dictionary = {KEY_B: RtsKinds.BARRACKS, KEY_D: RtsKinds.DEPOT, KEY_L: RtsKinds.LAB,
	KEY_T: RtsKinds.TOWER, KEY_E: RtsKinds.BASE}
const TRAIN_KEYS: Dictionary = {KEY_W: RtsKinds.WORKER, KEY_1: RtsKinds.RUNNER, KEY_2: RtsKinds.SHIELD,
	KEY_3: RtsKinds.MORTAR, KEY_A: RtsKinds.ARM}
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
@onready var _meter: RtsMeter = $Map/RtsMeter

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
## K: the computer's sides play under the human clock (T55).
var human_clock: bool = false
## G: a group's move order walks as a flock (T151). The world's crowd, kept
## across restarts with its switch.
var flock := RtsFlock.new()
## Whether the flock walked at any point of this match. Pressing G is not a
## command, so a recording cannot replay it: such a match is not kept.
var flock_used: bool = false
## Opened to record, and how many matches it has kept.
var recording: bool = OS.get_cmdline_user_args().has("--record")
var matches_kept: int = 0
# Whether this match has been kept already.
var _kept: bool = false
## Where a recording is written; a test points it elsewhere.
var recordings_folder: String = RtsClockMeasure.directory()

var _drag_from: Vector2 = Vector2.ZERO
var _dragging: bool = false
# Fractions of a tick owed at the slower speeds.
var _owed: float = 0.0


func _ready() -> void:
	_view.art = RtsArt.new(RtsView.SIDE_COLOURS)
	_minimap.board = _view
	_card.chosen.connect(_on_card)
	_legend.set_entries(_legend_entries())
	# The meter waits to be asked for, with M: it is more ink on a board a
	# person is reading, and T25 wants it hidden for clips of play.
	_meter.visible = false
	restart()
	Language.apply_if_opened_alone(self)


# Rebuilt in the language just chosen (T80): the header, the panel and the
# card are set from code and keep the words they were given, and the legend
# is drawn.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_legend.set_entries(_legend_entries())
		_card.forget_buttons()
		_refresh()


func _legend_entries() -> Array[Array]:
	return [
		[RtsView.SIDE_COLOURS[RtsScenario.WEST], tr("you: west")],
		[RtsView.SIDE_COLOURS[RtsScenario.EAST], tr("the computer: east")],
		[RtsThinking.STATE_COLOURS[Squad.ADVANCE], tr("its squad advancing, to its region")],
		[RtsThinking.STATE_COLOURS[Squad.FIGHT], tr("its squad fighting")],
		[RtsThinking.STATE_COLOURS[Squad.RETREAT], tr("its squad falling back")],
		[RtsThinking.PLAN_COLOUR, tr("where its plan will build")],
		[RtsView.FORCE_COLOURS[Flock.Rule.SEPARATION], tr("G flock: away from the too close")],
		[RtsView.FORCE_COLOURS[Flock.Rule.ALIGNMENT], tr("G flock: towards their heading")],
		[RtsView.FORCE_COLOURS[Flock.Rule.COHESION], tr("G flock: towards their middle")],
	] as Array[Array]


## A new match from the same seed, with the level, planner and mode chosen,
## paused, the camera on your base.
func restart() -> void:
	world = RtsScenario.start(SEED)
	flock.reset()
	world.crowd = flock
	flock_used = flock.on
	var level: Difficulty = RtsLevels.presets()[level_index]
	computer = RtsCommander.new(RtsScenario.EAST, level, SEED * 7, planner)
	stand_in = QueueSide.new(RtsScenario.WEST, level, SEED * 11)
	var sides: Dictionary = {}
	_thinking.clock = _seat(sides, computer)
	_meter.sides = {RtsScenario.EAST: computer}
	if watching:
		_seat(sides, stand_in)
		_meter.sides[RtsScenario.WEST] = stand_in
	played = RtsMatch.new(world, SEED, sides)
	_view.world = world
	_view.selected.clear()
	_view.placing = ""
	_thinking.side = computer
	last_refusal = ""
	_kept = false
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
		_keep_if_over()
		_refresh()


# `side` put in `sides` at its seat as it plays: under the human clock when
# K has put it on, bare otherwise. Returns the clock, or null without one.
#
# Typed by the clock, never by the port the clock and the side share
# (`GakRtsController`). A workaround, not a cause: on 4.7.2 the old
# `_clocked(...) -> GakRtsController` here was the observed trigger of 15
# scripts left alive at exit ("21 ObjectDB instances were leaked", "15
# resources still in use"), and only while this script compiled first. The
# engine mechanism is not identified: `rts_roster.gd` has seven such
# signatures and loads clean (T138, docs/godot/exit-leaks.md).
func _seat(sides: Dictionary, side: RtsSide) -> RtsHumanClock:
	if not human_clock:
		sides[side.side] = side
		return null
	var clock: RtsHumanClock = RtsHumanClock.at(side, RtsHumanClock.knob_values())
	sides[side.side] = clock
	return clock


# A match you played to its end, written to `recordings_folder` once, when
# the scene was opened to record: the clock's reference (T55). A match the
# queues played for you is not yours, and is not kept; nor is one the flock
# walked in, which its recording could not replay.
func _keep_if_over() -> void:
	if not recording or watching or RtsVictory.winner(world) == RtsVictory.UNDECIDED or _kept:
		return
	if flock_used:
		_kept = true
		return
	var kept: Dictionary = played.recording()
	kept.merge({"who": RtsClockMeasure.PERSON, "side": RtsScenario.WEST, "opponent": computer.level.name,
		"human_clock": human_clock})
	if RtsClockMeasure.save(kept, recordings_folder) != "":
		matches_kept += 1
	_kept = true


## One decision of the computer's: the match played up to and through its
## next decision, which is what `test/menu/demo_overlays.gd` steps by.
func step_decision() -> void:
	played.play(played.decide_every)
	_refresh()


## What the computer is reasoning with, for `test/menu/demo_overlays.gd`: its
## goal, its plan with each step's wait, and its squads' states and odds.
func decision_overlay() -> Dictionary:
	var thinking: Dictionary = computer.overlay(RtsSnapshot.of(world, computer.side))
	var shown: Dictionary = {"tick": world.tick, "level": computer.level.name, "goal": thinking["goal"]}
	var plan: Array[String] = []
	for step: Dictionary in thinking["plan"]:
		plan.append("%s at %.1f s" % [step["step"], step["starts"]])  # not shown: the gate's overlay
	shown["plan"] = plan if not plan.is_empty() else ["goal met"]  # not shown
	shown["waiting"] = Sentence.english(thinking["waiting"]) if not thinking["waiting"].is_empty() else "nothing"  # not shown: the gate's overlay
	shown["income"] = BuildSchedule.income(RtsSnapshot.of(world, computer.side))
	if not thinking["squads"].is_empty():
		shown["squads"] = thinking["squads"]
	if not flock.watched_forces.is_empty():
		shown["flock"] = _flock_overlay()
	return shown


# The watched unit's flock, as the overlay carries it: who, how many
# groupmates it counted, and how hard each rule pushes, in cells a second
# a second.
func _flock_overlay() -> Dictionary:
	var shown: Dictionary = {"unit": flock.watched, "counted": flock.watched_counted.size()}
	for rule: int in range(RtsFlock.RULES.size()):
		shown[RtsFlock.RULES[rule]] = snappedf(flock.watched_forces[rule].length(), 0.01)
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
		return tr("select a worker to build with")
	return RtsRefusal.words(RtsRules.why_refused(world, RtsScenario.WEST, RtsCommand.build(builder, what, cell)))


func _on_key(code: Key) -> void:
	if BUILD_KEYS.has(code) and not watching:
		_on_card("build", BUILD_KEYS[code])  # not shown: an identifier
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
		KEY_K:
			human_clock = not human_clock
			restart()
		KEY_M:
			_meter.visible = not _meter.visible
		KEY_G:
			flock.on = not flock.on
			flock_used = flock_used or flock.on
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
		_say(tr("click open ground to put {what} -- green is a place it can go; right click cancels").format({
			what = RtsWords.with_the(what)}), false)
	else:
		_say(tr("select a worker to build with"), true)
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
			_give(RtsCommand.repair(_selected_workers(), unit["id"]))
			return
	_give(RtsCommand.move(ids, cell))


# The command card's Repair: the worker nearest the selected building sent
# to mend it, through the same door as a right click.
func _send_a_repairer() -> void:
	var building: RtsUnit = null
	for id: int in _view.selected:
		if world.unit(id) != null and world.unit(id).side == RtsScenario.WEST and RtsKinds.is_building(world.unit(id).kind):
			building = world.unit(id)
	if building == null:
		_say(tr("select a building of yours to repair"), true)
		return
	var nearest: RtsUnit = null
	for unit: RtsUnit in world.units():
		if unit.side != RtsScenario.WEST or unit.kind != RtsKinds.WORKER:
			continue
		if nearest == null or unit.position.distance_to(building.position) < nearest.position.distance_to(building.position):
			nearest = unit
	if nearest == null:
		_say(tr("no worker to send"), true)
		return
	_give(RtsCommand.repair([nearest.id] as Array[int], building.id))
	if last_refusal == "":
		_say(tr("a worker is on its way to mend {what}").format({what = RtsWords.with_the(building.kind)}), false)


func _place(cell: Vector2i) -> void:
	var builder: int = _selected_worker()
	var what: String = _view.placing
	if builder < 0:
		_say(tr("select a worker to build with"), true)
		_view.placing = ""
		return
	_give(RtsCommand.build(builder, what, cell))
	if last_refusal != "":
		return
	_view.placing = ""
	var seconds: float = float(RtsKinds.of(what, "ticks")) / RtsWorld.TICKS_PER_SECOND
	_say(tr("{what} placed -- the worker walks there and builds it ({seconds} s of game)").format({
		what = RtsWords.title(what), seconds = roundi(seconds)}), false)


# Only the workers of the selection: repair is a worker's order, and a mixed
# selection sent whole was refused whole.
func _selected_workers() -> Array[int]:
	var ids: Array[int] = []
	for id: int in _selected_movers():
		if world.unit(id).kind == RtsKinds.WORKER:
			ids.append(id)
	return ids


# The first worker selected, or -1 when none is.
func _selected_worker() -> int:
	for id: int in _selected_movers():
		if world.unit(id).kind == RtsKinds.WORKER:
			return id
	return -1


func _train(kind: String) -> void:
	for id: int in _view.selected:
		var unit: RtsUnit = world.unit(id)
		# An armed or arming tower cannot take another arm: the next one may.
		var taken: bool = unit != null and RtsKinds.is_upgrade(kind) and (unit.armed or kind in unit.queue)
		if unit != null and unit.side == RtsScenario.WEST and kind in RtsKinds.of(unit.kind, "trains") and not taken:
			_give(RtsCommand.train(id, kind))
			return
	if RtsKinds.is_upgrade(kind):
		_say(tr("select a tower, complete and not yet armed"), true)
	else:
		_say(tr("select a building that trains {what}").format({what = RtsWords.with_a(kind)}), true)


func _give(command: RtsCommand) -> void:
	last_refusal = played.give(RtsScenario.WEST, command)
	if last_refusal != "":
		_say(RtsRefusal.words(last_refusal), true)


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
	_thinking.world = world
	_thinking.watcher = -1 if (reveal or watching) else RtsScenario.WEST
	flock.watched = _watched_in_a_flock()
	_view.flock = flock
	_header.text = _header_text(yours)
	_panel.text = tr("What the computer is thinking") + "\n" + "\n".join(_thinking.lines())
	_card.show_selection(yours, _view.selected)
	_redraw()


# The lowest id of your selection that walks in a group's move order: the
# unit whose forces are drawn. 0 when none does, or the flock is off. Read
# after a tick, so a unit just ordered is watched from its first flocking one.
func _watched_in_a_flock() -> int:
	var ids: Array[int] = _selected_movers()
	ids.sort()
	for id: int in ids:
		if flock.is_flocking(id):
			return id
	return 0


func _redraw() -> void:
	_view.queue_redraw()
	_thinking.queue_redraw()
	_meter.queue_redraw()
	_minimap.queue_redraw()


func _header_text(yours: RtsSnapshot) -> String:
	var seconds: int = world.tick / RtsWorld.TICKS_PER_SECOND
	var who: String = tr("the queues (watching)") if watching else tr("you")
	var state: String = tr("PAUSED -- space to play") if paused else tr("speed x{speed} (+ -)").format({speed = SPEEDS[speed_index]})
	var line: String = tr("ore {ore}   magma {magma}   supply {used}/{cap}   |   {clock}  {state}   |   {who} (west, blue)  vs  the commander (east, red): {level}, {planner}").format({
		ore = yours.resources[RtsKinds.ORE], magma = yours.resources[RtsKinds.MAGMA], used = yours.supply_used,
		cap = yours.supply_cap, clock = "%d:%02d" % [seconds / 60, seconds % 60], state = state, who = who,
		level = RtsWords.word(computer.level.name), planner = "STRIPS" if planner == BuildOrder.Planner.STRIPS else "HTN"})
	if RtsVictory.winner(world) != RtsVictory.UNDECIDED:
		return line + "\n" + tr("over: {why} -- R plays again").format({why = RtsVictory.told(world)})
	if last_refusal != "":
		return line + "\n" + RtsRefusal.words(last_refusal)
	return line + "\n" + tr("V watch two computers · C level · H planner · I influence · F fog · R again · arrows or the edge: look round") \
		+ " · " + tr("K human clock · M meter") + " · " + (tr("G flock: on") if flock.on else tr("G flock: off")) + _clock_text()


# The human clock's state, and the recording's, for the header's last line.
func _clock_text() -> String:
	var said: String = ""
	if human_clock:
		var clock: Dictionary = RtsHumanClock.knob_values()
		said += "   |   " + tr("human clock on: {ms} ms late, {actions} commands in {seconds} s").format({
			ms = roundi(clock["reaction_ms"]), actions = clock["most_actions"], seconds = roundi(clock["window_seconds"])})
	if recording:
		said += "   |   " + tr("recording: {count} match(es) kept in data/rts/").format({count = matches_kept})
		if flock_used:
			said += " " + tr("(not this one: G walked a flock, which a recording cannot replay)")
	return said
