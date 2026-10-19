## The tactical scenario, a person against the computer, with turns as
## Advance Wars plays them.
##
## The person plays red, and S swaps sides (T12): the computer then plays red
## and moves first. Click one of your units and everywhere it can reach lights
## up; click a lit cell and it walks there and is spent, greyed out until your
## next turn, and the next unit that can still move is picked up for you.
## W has the unit in hand wait where it is. With the
## workshop in hand, 1-5 build -- once a turn -- and U buys the forge. Z, or
## the button, takes back the last thing you did, as far back as the start of
## the turn. Space, or the button, ends it, and asks first while units are
## still unspent.
##
## The other side's threat map -- every cell it could strike next turn, and by
## how many pieces (T48) -- is tinted red on the board; T hides and shows it.
##
## The computer is whichever `BlueController` the scene was given -- the
## rules by default, and C hands it to the planner (T11), the learned policy
## (T44, T46), the three difficulty levels (T12), the four teams T25 wrote
## from T15's techniques -- the state machine, the behaviour tree, GOAP and
## the HTN -- and back to the rules, each time starting a new game. Each of
## its decisions is drawn before it is played, and space plays it, or enter plays the rest of the turn -- the
## scene is an example in invariant 13's sense, which is why it is
## `make demo-tactical`.
##
## The game ends when one side takes the other's workshop, or in a draw at the
## round limit (`TacticalVictory`).
##
## Opened with `-- --record` (`make record-tactical`), every game played to
## its end is kept in `data/tactical/` -- the decisions both sides played,
## the person's taken back with Z dropped with them (`TacticalRecording`) --
## and the status says how many. Nothing is kept otherwise (ADR 0017).
class_name TacticalGame
extends Node2D

## What the scene says it is, on screen, before anything else.
const WHAT_THIS_IS: String = "tactics in the style of Advance Wars: build, cross the river, destroy the enemy workshop"

## The controllers still to come, named on screen beside the one playing, so
## a person knows the computer is a slot and not a fixed opponent.
const CONTROLLERS_TO_COME: String = "C hands the computer to the next controller -- rules, planner, learned, easy, normal, hard, state machine, behaviour tree, GOAP, HTN -- and S swaps sides; either starts a new game"

@onready var _board: BoardView = $BoardView
@onready var _units: UnitView = $UnitView
@onready var _intent: IntentView = $IntentView
@onready var _status: Label = $Interface/Status
@onready var _header: Label = $Interface/Header
@onready var _legend: Legend = $Interface/Legend
@onready var _end_button: Button = $Interface/EndTurn
@onready var _undo_button: Button = $Interface/Undo

## The game as it stands. Public so tests can set a scene up directly.
var state: BoardState
## Who the computer is. Set it before the scene enters the tree to hand the
## computer's side to another controller; T11 and T12 play theirs this way.
var computer: BlueController = RuleBasedBlue.new()
## The side the person plays: red, moving first, unless S has swapped it.
var person_side: int = TacticalScenario.RED
## `TacticalVictory.NOBODY` while the game is on; then the winner, or `DRAW`.
var winner: int = TacticalVictory.NOBODY
var _turn := TacticalTurn.new()
var _computer_turn: BlueTurn
var _types: Dictionary = TacticalRules.unit_types()
var _selected_id: int = -1
var _last_refusal: String = ""
# What the last action did, in words, so a build is confirmed and not only
# visible as a smaller number.
var _last_event: String = ""
# What the computer's attacks did this turn, kept for the person to read
# when their turn starts: shown only while they were played, they were gone
# by the time the person looked -- and enter played them without showing them
# at all.
var _computer_news: Array[String] = []
# Whether the threat map is drawn (T toggles it).
var _showing_threat: bool = true
# True after one press of end turn with units still unspent: the next press
# ends it. Any other action puts it back.
var _confirming_end: bool = false
## True when the scene was opened to record, and how many games it has kept.
var recording: bool = OS.get_cmdline_user_args().has("--record")
var games_kept: int = 0
## Where a recording is written; a test points it elsewhere.
var recordings_folder: String = TacticalRecording.directory()
# This game's decisions so far, as rows, and whether it has been kept.
var _recorded: Array[Dictionary] = []
var _kept: bool = false
var _starting_seed: int = 0


func _ready() -> void:
	_legend.set_entries(TacticalLegend.entries(_types))
	_end_button.pressed.connect(end_turn)
	_undo_button.pressed.connect(undo)
	new_game()
	BoardLayout.lay_out(self, state.graph, _status, _legend)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		_press(key.keycode)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		click_cell(_board.cell_at(_board.to_local(click.global_position)))


## Start again: red to move, nobody spent, nobody winning -- and when the
## computer is red, its first decision drawn.
func new_game() -> void:
	state = TacticalScenario.build()
	# Played at the top of the tree -- the window's own scene, or opened from
	# the menu -- each game rolls different dice; under a test, which mounts
	# the scene inside its own node, the dice stay the scenario's, so a
	# test's game is the same game every run. Asked of the parent, not of
	# `current_scene`: the menu can only make a scene current once it is in
	# the tree, after this has run (wave 59's review: seed 0 every time).
	if is_inside_tree() and get_parent() == get_tree().root:
		state.dice_seed = randi()
	# Every attack moves the board's seed on, so the one a recording needs is
	# the one the game began with (wave 58's review).
	_starting_seed = state.dice_seed
	_units.reset()
	winner = TacticalVictory.NOBODY
	_computer_turn = BlueTurn.new(computer)
	_computer_news.clear()
	_recorded.clear()
	_kept = false
	# The last game's last event is not news in this one -- and when the
	# computer moves first, nothing below would clear it.
	_last_event = ""
	if person_side == TacticalScenario.RED:
		_start_persons_turn()
	else:
		_begin_computer_turn()


## A click picks up one of your units or walks the one in hand to a lit cell.
## Clicking the unit already in hand does nothing more: the turn starts with
## one in hand, and a click meant to pick it up must not spend it.
func click_cell(cell: Vector2i) -> void:
	if not _persons_turn():
		return
	var occupant: Unit = state.unit_at(cell)
	_last_event = ""
	_confirming_end = false
	if occupant != null and occupant.faction == state.current_faction:
		_pick_up(occupant)
	elif occupant != null and state.unit_by_id(_selected_id) != null:
		attack(occupant)
	elif occupant != null:
		_last_refusal = "%s is %s's %s -- you can pick up only your own pieces" % [
			cell, TacticalStatus.side_name(occupant.faction), occupant.type.type_name]
	else:
		_walk_to(cell)
	_refresh()


## The unit in hand attacks `target`: once a turn, before or after its walk.
## An attack cannot be taken back, and nothing before it can either: Z after a
## fight would let a player read the dice and choose again.
func attack(target: Unit) -> void:
	if not _persons_turn():
		return
	if _turn.has_attacked(_selected_id):
		_refuse("this unit has attacked this turn; Z takes the attack back")
		return
	var strike := Attack.new(_selected_id, target.id)
	var before: BoardState = state
	if _act(TacticalCombat.apply(state, strike), TacticalCombat.why_refused(state, strike)):
		_note(TacticalDecision.strike(strike.attacker_id, target, ""), before)
		_last_event = TacticalCombat.told(before, strike, state)
		_turn.attacked(strike.attacker_id)
		_turn.seal()
		winner = TacticalVictory.winner(state)
		_select_next_unspent()
	_refresh()


## Build the `index`th buildable type at the workshop in hand, on the first
## free cell beside it the new unit could stand on. A workshop builds once a
## turn, and the build can be taken back like a move.
func build(index: int) -> void:
	if not _persons_turn():
		return
	_confirming_end = false
	var kind: UnitType = _types[TacticalRules.BUILDABLE[index]]
	var workshop: Unit = state.unit_by_id(_selected_id)
	if workshop != null and not workshop.type.produces.is_empty() and _turn.is_spent(workshop.id):
		_refuse("the workshop has already built this turn; Z takes the build back")
		return
	var order := ProductionOrder.new(_selected_id, kind, TacticalRules.free_cell_beside(state, workshop, kind))
	var before: BoardState = state
	if _act(state.produce(order), state.why_production_refused(order)):
		_note(TacticalDecision.build(order.producer_id, order, ""), before)
		_turn.spend(_selected_id)
		_last_event = "built a %s at %s; it moves next turn" % [kind.type_name, order.cell]
	_refresh()


## The unit in hand waits where it stands, and is spent. Taken back by undo.
func wait() -> void:
	if not _persons_turn():
		return
	_confirming_end = false
	var unit: Unit = state.unit_by_id(_selected_id)
	if unit == null or not unit.id in _turn.unspent(state):
		_refuse("nothing in hand that can still move")
		return
	_turn.remember(state)
	_note(TacticalDecision.hold(unit.id, "", unit.cell), state)
	_turn.spend(unit.id)
	_last_event = "the %s waits at %s" % [unit.type.type_name, unit.cell]
	_last_refusal = ""
	_select_next_unspent()
	_refresh()


## Buy the forge for the person's side. Taken back by undo like anything else.
func buy_forge() -> void:
	if not _persons_turn():
		return
	_confirming_end = false
	var forge: Upgrade = TacticalRules.forge()
	var before: BoardState = state
	if _act(state.buy(forge), state.why_upgrade_refused(forge)):
		_note(TacticalDecision.buy(_selected_id, forge, "", Vector2i.ZERO), before)
		_last_event = "bought the forge: rams can be built"
	_refresh()


## Take back the last thing the person did this turn: the unit goes back to its cell
## and is no longer spent, a build is unbuilt and paid back.
func undo() -> void:
	if not _persons_turn():
		return
	_confirming_end = false
	var spent_before: Array[int] = _turn.spent_ids()
	var before: BoardState = _turn.undo()
	if before == null:
		_refuse("nothing to take back this turn")
		return
	state = before
	# Every action undo can take back remembered one state and wrote one row.
	if not _recorded.is_empty():
		_recorded.pop_back()
	_last_refusal = ""
	_last_event = "taken back"
	_hold_what_was_taken_back(spent_before)
	_refresh()


# Put back in hand the unit whose action was just taken back, so the next
# click acts on it; failing that, keep the hand unless its unit is gone.
func _hold_what_was_taken_back(spent_before: Array[int]) -> void:
	for unit_id: int in spent_before:
		if not _turn.is_spent(unit_id) and state.unit_by_id(unit_id) != null:
			_selected_id = unit_id
			return
	if state.unit_by_id(_selected_id) == null:
		_select_next_unspent()


## End the person's turn. With units still unspent the first press only
## asks; the second ends it.
func end_turn() -> void:
	if not _persons_turn():
		return
	var waiting: int = _turn.unspent(state).size()
	if waiting > 0 and not _confirming_end:
		_confirming_end = true
		_refuse("%d unit(s) have not moved. End the turn anyway? Press space or the button again" % waiting)
		return
	_hand_to_computer()


## One decision by the computer: on the person's turn, that turn ends -- the
## decision being waited on is the computer's -- and on the computer's turn,
## it plays the decision on screen and shows the next. The step every example
## offers (T21).
func step_decision() -> void:
	if winner != TacticalVictory.NOBODY:
		return
	if _persons_turn():
		_hand_to_computer()
	elif _computer_turn.finished():
		_start_persons_turn()
	else:
		_play_computer_decision()


# Play the decision on screen, and walk the unit along the route it was
# drawn with, so what the pink line promised is what a person sees happen.
func _play_computer_decision() -> void:
	var decision: TacticalDecision = _computer_turn.next
	var walker: Unit = state.unit_by_id(decision.unit_id)
	var before: BoardState = state
	state = _computer_turn.play(state)
	if decision in _computer_turn.played:
		_note(decision, before)
	if decision.attack != null and decision in _computer_turn.played:
		_last_event = TacticalCombat.told(before, decision.attack, state)
		_computer_news.append(_last_event)
	winner = TacticalVictory.winner(state)
	# A refused decision is not in `played`, and a hold or a build is no walk.
	if decision.move != null and decision in _computer_turn.played:
		_units.walk(decision.unit_id, walker.cell, decision.move.path)
	_refresh()


## Play the computer's turn to its end, every decision still drawn and
## recorded, and hand the board back to the person -- for the many holds a
## long game brings.
func play_rest_of_computer_turn() -> void:
	while _computer_thinking():
		step_decision()
	if winner == TacticalVictory.NOBODY and not _persons_turn():
		step_decision()


## What the computer is reasoning with: who is playing it, the decision about
## to be played and why, and what it has done this turn -- for
## `test/demo_overlays.gd` to check is there.
func decision_overlay() -> Dictionary:
	var overlay: Dictionary = {"controller": computer.controller_name(), "to_move": TacticalStatus.side_name(state.current_faction)}
	if _computer_thinking():
		overlay["next"] = _described(_computer_turn.next)
	if not _computer_turn.played.is_empty():
		overlay["played"] = _computer_turn.played.map(_described)
	if not computer.plan_lines().is_empty():
		overlay["plan"] = computer.plan_lines()
	overlay["threatened cells"] = threat().size()
	return overlay


## Where the side not to move could strike on its next turn: `ThreatMap`,
## as the board draws it. Empty once the game is over.
func threat() -> Dictionary[Vector2i, int]:
	if winner != TacticalVictory.NOBODY:
		return {}
	return ThreatMap.of(state, TacticalScenario.FACTIONS - 1 - state.current_faction)


## True while the computer's turn is on and it still has a decision to play
## -- and only while the game is on, which is what keeps a game that ended at
## the hand-off from drawing its next move over the result.
func _computer_thinking() -> bool:
	return (winner == TacticalVictory.NOBODY and state.current_faction != person_side
		and _computer_turn.next != null)


## True while it is the person's turn and the game is still on.
func _persons_turn() -> bool:
	return winner == TacticalVictory.NOBODY and state.current_faction == person_side


func _press(keycode: Key) -> void:
	if keycode == KEY_R:
		new_game()
	elif keycode == KEY_SPACE and _persons_turn():
		end_turn()
	elif keycode == KEY_SPACE:
		step_decision()
	elif keycode >= KEY_1 and keycode <= KEY_5:
		build(keycode - KEY_1)
	elif keycode == KEY_U:
		buy_forge()
	elif keycode == KEY_Z:
		undo()
	elif keycode == KEY_W:
		wait()
	elif keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
		play_rest_of_computer_turn()
	elif keycode == KEY_C:
		swap_controller()
	elif keycode == KEY_S:
		swap_sides()
	elif keycode == KEY_T:
		_showing_threat = not _showing_threat
		_refresh()


## Hand the computer's side to the next controller -- rules, planner,
## learned, each difficulty level, then the four T15 techniques (T25), and
## round again -- and start again: a
## controller swapped mid-game would inherit a board it did not play.
func swap_controller() -> void:
	computer = next_controller(computer)
	new_game()


## The controller after `playing` in the order C cycles through. A level is
## seeded afresh each time, from the engine's own random numbers -- its
## noise is its own, never the board's dice.
static func next_controller(playing: BlueController) -> BlueController:
	var levels: Array[Difficulty] = Difficulty.presets()
	if playing is LeveledBlue:
		var at: int = levels.map(func(level: Difficulty) -> String: return level.name).find(playing.controller_name())
		return LeveledBlue.new(levels[at + 1], randi()) if at + 1 < levels.size() else MachineTeam.new()
	if playing is PlannedBlue:
		return LearnedBlue.new()
	if playing is LearnedBlue:
		return LeveledBlue.new(levels[0], randi())
	if playing is MachineTeam:
		return TreeTeam.new()
	if playing is TreeTeam:
		return GoapTeam.new()
	if playing is GoapTeam:
		return HtnTeam.new()
	if playing is HtnTeam:
		return RuleBasedBlue.new()
	var planner := PlannedBlue.new()
	planner.verbose = true
	return planner


## The person takes the other side, and a new game starts: the same board,
## the same controller on the computer's side, at the same level.
func swap_sides() -> void:
	person_side = TacticalScenario.FACTIONS - 1 - person_side
	new_game()


func _pick_up(unit: Unit) -> void:
	_selected_id = unit.id
	_last_refusal = ""
	if _turn.is_spent(unit.id) and unit.type.mobile:
		# Held, so the status describes it, but with nothing lit: a spent unit
		# has nowhere to go until next turn -- though one that has walked may
		# still attack from where it stopped.
		var still: String = "" if _turn.has_attacked(unit.id) else "; it can still attack an enemy in reach"
		var back: String = "; Z takes the move back" if _turn.can_undo() else ""
		_last_refusal = "this %s has moved this turn%s%s" % [unit.type.type_name, still, back]


# Walk the unit in hand along the cheapest route the highlight offered, or,
# for a cell it did not offer, try one step so the board says why not.
func _walk_to(cell: Vector2i) -> void:
	var unit: Unit = state.unit_by_id(_selected_id)
	if unit != null and _turn.is_spent(unit.id):
		_refuse("this %s has moved this turn; Z takes the move back" % unit.type.type_name)
		return
	var walks: Dictionary = TacticalReach.walks_for(state, unit) if unit != null else {}
	var path: Array[Vector2i] = [cell]
	if walks.has(cell):
		path = walks[cell]
	var move := Move.new(_selected_id, path)
	var before: BoardState = state
	if _act(state.apply(move), _explained(state.why_refused(move), cell)):
		_note(TacticalDecision.walk(move.unit_id, path, "", cell), before)
		_units.walk(unit.id, unit.cell, path)
		_turn.spend(_selected_id)
		_select_next_unspent()


# Keep the new state and remember the old one for undo, or keep the reason it
# was refused -- never neither. True when it was kept.
func _act(next: BoardState, refusal: String) -> bool:
	if next == null:
		_last_refusal = refusal
		return false
	_turn.remember(state)
	state = next
	_last_refusal = ""
	return true


func _refuse(reason: String) -> void:
	_last_refusal = reason
	_refresh()


# The board says a cell is blocked; the game knows what it is blocked *by*.
func _explained(refusal: String, cell: Vector2i) -> String:
	if not refusal.ends_with("is blocked") or not state.graph.contains(cell):
		return refusal
	match TacticalScenario.MAP[cell.y][cell.x]:
		TacticalRules.WATER:
			return refusal + ": water, which only waders cross"
		TacticalRules.ROCK:
			return refusal + ": rock, which nothing crosses"
	return refusal


func _hand_to_computer() -> void:
	_open_turn()
	_begin_computer_turn()


# The computer's turn on a board whose turn has already opened: the first
# turn of a game the computer moves first in, or after `_open_turn`.
func _begin_computer_turn() -> void:
	_computer_news.clear()
	_confirming_end = false
	_last_refusal = ""
	_selected_id = -1
	if winner == TacticalVictory.NOBODY:
		_computer_turn.begin(state)
	_refresh()


func _start_persons_turn() -> void:
	_last_event = ""
	if state.current_faction != person_side:
		_open_turn()
		_last_event = _with_computer_news(_last_event)
	_turn.begin()
	_last_refusal = ""
	_confirming_end = false
	_select_next_unspent()
	_refresh()


# The next side's turn: income and the points it holds, fresh movement, then
# its towers fire, and what happened is the first thing that side reads.
func _open_turn() -> void:
	var opened: Array = TurnStart.open(state)
	state = opened[0]
	_last_event = "\n".join(opened[1])
	winner = TacticalVictory.winner(state)


# What the person reads first: the computer's attacks of the turn just
# played, then what the person's own towers did.
func _with_computer_news(towers: String) -> String:
	if _computer_news.is_empty():
		return towers
	var lines: Array[String] = ["%s's attacks:" % TacticalStatus.side_name(TacticalScenario.FACTIONS - 1 - person_side)]
	lines.append_array(_computer_news)
	if towers != "":
		lines.append(towers)
	return "\n".join(lines)


# The next of the person's units that can still walk, or nothing when none can.
func _select_next_unspent() -> void:
	var waiting: Array[int] = _turn.unspent(state)
	_selected_id = waiting[0] if not waiting.is_empty() else -1


func _described(decision: TacticalDecision) -> Dictionary:
	return {"unit": decision.unit_id, "kind": decision.kind(), "why": decision.reason, "target": decision.target}


func _refresh() -> void:
	# The computer's turn draws neither the person's reach nor their spent
	# units: what is on screen then is the computer's decision.
	var reach: Array[Vector2i] = []
	_units.spent.clear()
	if _persons_turn():
		reach = _steps_in_reach()
		_units.spent = _turn.spent_ids()
	_board.draw_board(state.graph, reach, TacticalScenario.POINTS, _terrain())
	_units.show_state(state, _board, _selected_id)
	_intent.show_decision(_computer_turn.next if _computer_thinking() else null, state, _board)
	var marks: Dictionary[Vector2i, String] = {}
	if _computer_thinking():
		marks = computer.plan_marks(state)
	_intent.show_plan(marks)
	_intent.show_threat(threat() if _showing_threat else {} as Dictionary[Vector2i, int])
	_header.text = "%s\n%s\nyou play %s; %s is played by %s" % [WHAT_THIS_IS, TacticalVictory.rule(),
		TacticalStatus.side_name(person_side), TacticalStatus.side_name(TacticalScenario.FACTIONS - 1 - person_side), computer.describe()]
	_keep_if_over()
	_end_button.disabled = not _persons_turn()
	_undo_button.disabled = not (_persons_turn() and _turn.can_undo())
	_status.text = _status_text()
	if recording:
		_status.text += "\nrecording: %d game(s) kept in data/tactical/" % games_kept


# Write `decision`, played on `before`, into this game's rows -- when
# recording, and only then.
func _note(decision: TacticalDecision, before: BoardState) -> void:
	if recording:
		_recorded.append(TacticalRecording.row_of(decision, before))


# When recording, write this game to `data/tactical/` once it is over: only a
# game played to its end is kept, so a restart is not a game.
func _keep_if_over() -> void:
	if not recording or _kept or winner == TacticalVictory.NOBODY:
		return
	_kept = true
	var rounds: int = mini(state.turn_number / TacticalScenario.FACTIONS + 1, TacticalVictory.ROUND_LIMIT)
	var kept: Dictionary = TacticalRecording.made(_recorded.duplicate(), _starting_seed, TacticalRecording.PERSON,
		person_side, computer.controller_name(), winner, rounds)
	if TacticalRecording.save(kept, recordings_folder) != "":
		games_kept += 1


func _status_text() -> String:
	if winner != TacticalVictory.NOBODY:
		return TacticalVictory.announcement(winner, state)
	if not _persons_turn():
		return TacticalStatus.computer_text(state, _computer_turn, computer, _last_event) + "\n\n" + CONTROLLERS_TO_COME
	var unit: Unit = state.unit_by_id(_selected_id)
	var news: String = _last_event
	if unit == null and _turn.unspent(state).is_empty():
		news = (news + "\n" if news != "" else "") + "every unit has moved: space ends the turn"
	return TacticalStatus.text(state, unit, _last_refusal, news, unit != null and not _turn.has_attacked(unit.id))


# Every cell the unit in hand can walk to this turn; nothing for a spent one.
func _steps_in_reach() -> Array[Vector2i]:
	var unit: Unit = state.unit_by_id(_selected_id)
	var found: Array[Vector2i] = []
	if unit != null and not _turn.is_spent(unit.id):
		found.assign(TacticalReach.walks_for(state, unit).keys())
	return found


# The ground the board's costs alone would draw wrong: trees as rough ground,
# water as a wall, the bridge as open ground.
func _terrain() -> Dictionary:
	var tiles: Dictionary = {}
	var kinds: Dictionary = {
		TacticalRules.TREES: BoardView.TREES, TacticalRules.WATER: BoardView.WATER,
		TacticalRules.BRIDGE: BoardView.BRIDGE, TacticalRules.FORD: BoardView.ROUGH,
	}
	for letter: String in kinds:
		for cell: Vector2i in TacticalRules.cells_of(TacticalScenario.MAP, letter):
			tiles[cell] = kinds[letter]
	return tiles
