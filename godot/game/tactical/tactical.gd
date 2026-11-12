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
## All of that is the Advance Wars mode. What a walk, an attack, a turn's
## opening and a win mean, and the roster C cycles, are asked of `ruleset`
## (T84), which is `AdvanceWarsRuleset` unless whoever opens the scene hands
## it another -- the XCOM-style `SquadRuleset`, from module `squad`, which
## this scene never names. What the screen shows of a mode -- its words, the
## tint, the fog, the dash, the odds, the status, the legend -- is asked of
## the ruleset's `TacticalModeView` (T126), `view()`.
##
## The opener may hand it several (T85): the menu opens the tactical card in
## Advance Wars or in XCOM, and gives the scene both. M then plays the next
## mode, a new game with that mode's first controller, as C changes the
## controller. A mode with fog is drawn as its side sees it -- the hidden
## cells dark, a faded picture where an enemy was last seen -- and the
## pieces drawn are only the ones that side sees. On the computer's turn the
## board shows what the computer sees, with every option it weighed for the
## piece about to act; V turns that off, and the board is the person's again.
##
## A key the scene does not use is the mode's (`TacticalModeView.pressed`):
## the XCOM-style mode's N builds a new map by wave function collapse, and B
## shows one being built, a cell a press (T96). While a mode builds, the board
## shows what it is building (`TacticalModeView.building`), and a click does
## nothing.
##
## Opened with `-- --record` (`make record-tactical`), every game played to
## its end is kept in `data/tactical/` -- the decisions both sides played,
## the person's taken back with Z dropped with them (`TacticalRecording`) --
## and the status says how many. Nothing is kept otherwise (ADR 0017).
class_name TacticalGame
extends Node2D

## The sides as the overlay names them, in English whatever the language on
## screen, as every reason in it is (T104).
const SIDES: Array[String] = ["red", "blue"]  # not shown: the overlay's

@onready var _board: BoardView = $BoardView
@onready var _units: UnitView = $UnitView
@onready var _intent: IntentView = $IntentView
@onready var _status: Label = $Interface/Status
@onready var _header: Label = $Interface/Header
@onready var _keys: Label = $Interface/Keys
@onready var _legend: Legend = $Interface/Legend
@onready var _end_button: Button = $Interface/EndTurn
@onready var _undo_button: Button = $Interface/Undo

## The game as it stands. Public so tests can set a scene up directly.
var state: BoardState
## The rules the scene plays by (T84): Advance Wars unless whoever opens the
## scene hands it another before it enters the tree, as with `computer`. The
## scene asks it everything a walk, an attack, a turn and a win mean, and
## never names a mode itself; what it draws of them it asks `view()`.
var ruleset: TacticalRuleset = AdvanceWarsRuleset.new()
## Every mode M cycles through, `ruleset` among them, in the order the
## opener gave them (T85); empty when the scene was handed one ruleset only,
## and M then does nothing.
var modes: Array[TacticalRuleset] = []
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
# What the last action did, so a build is confirmed and not only visible as
# a smaller number: one `Sentence` a line, worded where it is shown (T110),
# so a language switched before the next event rewords it.
var _last_event: Array[Array] = []
# What the computer's attacks did this turn, kept for the person to read
# when their turn starts: shown only while they were played, they were gone
# by the time the person looked -- and enter played them without showing them
# at all. A `Sentence` each, as the news is.
var _computer_news: Array[Array] = []
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
# What each side sees now, in a mode with fog; null in a mode without (T85).
var _person_fog: TacticalFog
var _computer_fog: TacticalFog
## The argument that opens the teaching view (T124).
const TEACHING_VIEW: String = "--view=teach"
## True when the scene was opened in the teaching view, `--view=teach` after
## `--`, as `make demo-tactical MODE=squad VIEW=teach` opens it (T124): a
## mode with fog then starts with V on, the computer's reasoning on the
## board. In play it starts off, or the computer's turn would show the
## whole enemy squad once a round. A test sets it before the scene enters
## the tree.
var teaching: bool = teaching_asked(OS.get_cmdline_user_args())
# Whether the computer's turn shows what it sees and what it weighed (V);
# each mode's view says how it starts (`shows_the_computer_at_start`).
var _showing_decision: bool = true
# The cell under the mouse, for T's odds in a mode that tints by cursor.
var _cursor: Vector2i = Vector2i(-1, -1)
# True once a walk this turn showed an enemy: the turn is sealed, and Z says
# why rather than that there is nothing to take back.
var _sealed_by_a_reveal: bool = false
# The view of `ruleset` last asked for, so the many calls of one refresh
# share one. The header builds the next mode's view too, for its title only.
var _view: TacticalModeView


func _ready() -> void:
	var unknown: String = unknown_view(OS.get_cmdline_user_args())
	if unknown != "":
		push_error("%s: the only view is %s; opened in play" % [unknown, TEACHING_VIEW])
	_showing_decision = view().shows_the_computer_at_start(teaching)
	_set_words()
	_end_button.pressed.connect(end_turn)
	_undo_button.pressed.connect(undo)
	new_game()
	# The status takes the whole left column, from the header's top edge: the
	# header sits over the board and the legend only. Begun level with the
	# board, the planner's turn in a played game -- a strike's news, a long
	# reason, six plan steps -- ran to y=834 of 720 in pt-BR (T102's review).
	BoardLayout.lay_out(self, state.graph, _status, _legend, _header.position.y)
	Language.apply_if_opened_alone(self)


# A controller that thinks over several frames (T87) thinks one more, and
# what it believes now is drawn: the board keeps drawing while it searches.
func _process(_delta: float) -> void:
	if _computer_thinking() and computer.keep_thinking():
		_refresh()


# The words are rebuilt in the language just chosen (T79): text set from code
# keeps the words it was given. The notification also comes on entering the
# tree, before _ready, when there is nothing to rebuild yet.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_set_words()
		_refresh()


func _set_words() -> void:
	_legend.set_entries(view().legend())
	_end_button.text = tr("End turn (space)")
	_undo_button.text = tr("Undo (Z)")
	_keys.text = controllers_to_come(ruleset)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		_press(key.keycode)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and view().building().is_empty():
		click_cell(_board.cell_at(_board.to_local(click.global_position)))
	var motion := event as InputEventMouseMotion
	if motion != null:
		point_at(_board.cell_at(_board.to_local(motion.global_position)))


## The mouse is over `cell`: in a mode whose T tint answers about the cell
## under the cursor, it is drawn again for that cell.
func point_at(cell: Vector2i) -> void:
	if cell == _cursor:
		return
	_cursor = cell
	if _showing_threat and state != null and view().building().is_empty():
		_intent.show_threat(_tint(), view().tint_is_a_chance())


## What the screen shows of the mode playing (T126): `ruleset`'s own view,
## asked again whenever the ruleset is not the one it was asked of -- M, or
## an opener or a test setting `ruleset` -- so the two are never out of step.
func view() -> TacticalModeView:
	if _view == null or _view.rules != ruleset:
		_view = ruleset.mode_view()
	return _view


## True when `arguments`, the ones after `--`, ask for the teaching view.
## A function of its own so a test can ask it without a command line.
static func teaching_asked(arguments: PackedStringArray) -> bool:
	return arguments.has(TEACHING_VIEW)


## The `--view=` in `arguments` that names no view this scene has, or "":
## `VIEW=teaching` would otherwise open in play with no word why (wave
## 191's review).
static func unknown_view(arguments: PackedStringArray) -> String:
	for argument: String in arguments:
		if argument.begins_with("--view=") and argument != TEACHING_VIEW:
			return argument
	return ""


## Play in each of `rulesets` -- a `TacticalRuleset` each -- starting in the
## one at `chosen`, so M can move between them, against that mode's first
## controller unless the computer is already one of its roster. Called by
## the opener before the scene enters the tree, as `ruleset` and `computer`
## are set (T85).
func play_in_modes(rulesets: Array, chosen: int) -> void:
	modes.assign(rulesets)
	ruleset = modes[clampi(chosen, 0, modes.size() - 1)]
	if not computer.controller_name() in ruleset.roster_names():
		computer = ruleset.build_controller(ruleset.roster_names()[0], randi())


## Play the next of `modes`, round to the first: a new game, with that
## mode's first controller -- a controller of one mode cannot play another.
func swap_mode() -> void:
	if modes.size() < 2:
		return
	ruleset = modes[(modes.find(ruleset) + 1) % modes.size()]
	computer = ruleset.build_controller(ruleset.roster_names()[0], randi())
	_showing_decision = view().shows_the_computer_at_start(teaching)
	_set_words()
	new_game()


## Start again: red to move, nobody spent, nobody winning -- and when the
## computer is red, its first decision drawn.
func new_game() -> void:
	state = ruleset.start()
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
	_computer_turn = BlueTurn.new(computer, ruleset)
	_computer_news.clear()
	_recorded.clear()
	_kept = false
	# The last game's last event is not news in this one -- and when the
	# computer moves first, nothing below would clear it.
	_last_event.clear()
	_person_fog = null
	_computer_fog = null
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
	var occupant: Unit = _persons_board().unit_at(cell)
	_last_event.clear()
	_confirming_end = false
	if occupant != null and occupant.faction == state.current_faction:
		_pick_up(occupant)
	elif occupant != null and state.unit_by_id(_selected_id) != null:
		attack(occupant)
	elif occupant != null:
		_last_refusal = tr("{cell} is {side}'s {piece} -- you can pick up only your own pieces").format({
			cell = cell, side = TacticalStatus.side_name(occupant.faction), piece = TacticalStatus.piece(occupant.type.type_name)})
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
		_refuse(tr("this unit has attacked this turn; Z takes the attack back"))
		return
	var strike := Attack.new(_selected_id, target.id)
	var before: BoardState = state
	if _act(ruleset.attack(state, strike), ruleset.why_attack_refused(state, strike)):
		_note(TacticalDecision.strike(strike.attacker_id, target, []), before)
		_tell(ruleset.told(before, strike, state))
		_turn.attacked(strike.attacker_id)
		_turn.seal()
		winner = ruleset.winner(state)
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
		_refuse(tr("the workshop has already built this turn; Z takes the build back"))
		return
	var order := ProductionOrder.new(_selected_id, kind, TacticalRules.free_cell_beside(state, workshop, kind))
	var before: BoardState = state
	if _act(state.produce(order), state.why_production_refused(order)):
		_note(TacticalDecision.build(order.producer_id, order, []), before)
		_turn.spend(_selected_id)
		_tell(Sentence.of("built {piece} at {cell}; it moves next turn", {  # shown through tr()
			piece = TacticalStatus.a_piece_sentence(kind.type_name), cell = order.cell}))
	_refresh()


## The unit in hand waits where it stands, and is spent. Taken back by undo.
func wait() -> void:
	if not _persons_turn():
		return
	_confirming_end = false
	var unit: Unit = state.unit_by_id(_selected_id)
	if unit == null or not unit.id in _turn.unspent(state):
		_refuse(tr("nothing in hand that can still move"))
		return
	_turn.remember(state)
	_note(TacticalDecision.hold(unit.id, [], unit.cell), state)
	_turn.spend(unit.id)
	_tell(Sentence.of("{piece} waits at {cell}", {piece = TacticalStatus.the_piece_sentence(unit.type.type_name), cell = unit.cell}))  # shown through tr()
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
		_note(TacticalDecision.buy(_selected_id, forge, [], Vector2i.ZERO), before)
		_tell(Sentence.of("bought the forge: rams can be built"))  # shown through tr()
	_refresh()


## Take back the last thing the person did this turn: the unit goes back to its cell
## and is no longer spent, a build is unbuilt and paid back.
func undo() -> void:
	if not _persons_turn():
		return
	_confirming_end = false
	var spent_before: Array[int] = _turn.spent_ids()
	var before: BoardState = _turn.undo()
	if before == null and _sealed_by_a_reveal:
		_refuse(tr("a walk that showed an enemy cannot be taken back, nor anything before it this turn"))
		return
	if before == null:
		_refuse(tr("nothing to take back this turn"))
		return
	state = before
	# Every action undo can take back remembered one state and wrote one row.
	if not _recorded.is_empty():
		_recorded.pop_back()
	_last_refusal = ""
	_tell(Sentence.of("taken back"))  # shown through tr()
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
		_refuse(tr("{count} unit(s) have not moved. End the turn anyway? Press space or the button again").format({count = waiting}))
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
		_tell(ruleset.told(before, decision.attack, state))
		_computer_news.append(_last_event[0])
	winner = ruleset.winner(state)
	# A refused decision is not in `played`, and a hold or a build is no walk.
	if decision.move != null and decision in _computer_turn.played:
		_units.walk(decision.unit_id, walker.cell, decision.move.path)
	_refresh()


## Play the computer's turn to its end, every decision still drawn and
## recorded, and hand the board back to the person -- for the many holds a
## long game brings. A controller that thinks over several frames (T87)
## finishes each decision's thinking first: Enter skips the watching, not
## the search, and the window waits while it thinks.
func play_rest_of_computer_turn() -> void:
	while _computer_thinking():
		while computer.keep_thinking():
			pass
		step_decision()
	if winner == TacticalVictory.NOBODY and not _persons_turn():
		step_decision()


## What the computer is reasoning with: who is playing it, the decision about
## to be played and why, and what it has done this turn -- for
## `test/menu/demo_overlays.gd` to check is there. In English, as the AI
## keeps it, so the same game gives the same overlay in any language.
func decision_overlay() -> Dictionary:
	var overlay: Dictionary = {"controller": computer.controller_name(), "to_move": SIDES[state.current_faction]}
	if _computer_thinking():
		overlay["next"] = _described(_computer_turn.next)
	if not _computer_turn.played.is_empty():
		overlay["played"] = _computer_turn.played.map(_described)
	var plan: Array[String] = computer.plan_lines(Sentence.english)
	if not plan.is_empty():
		overlay["plan"] = plan
	overlay["threatened cells"] = threat().size()
	overlay["mode"] = ruleset.mode_name()
	if not view().building().is_empty():
		overlay["map build"] = view().building()["overlay"]
	if _computer_thinking() and _weighing_drawn() and not computer.weighed().is_empty():
		overlay["weighed"] = computer.weighed().map(_weighed_described)
	return overlay


# One weighed option as the overlay keeps it: where, its score, its chance.
func _weighed_described(option: Dictionary) -> Dictionary:
	return {"cell": option["cell"], "score": option["score"], "chance": option["chance"], "chosen": option["chosen"]}


## Where the side not to move could strike on its next turn: the mode view's
## tint (`ThreatMap` in Advance Wars), as the board draws it. Empty once the game is over.
func threat() -> Dictionary[Vector2i, int]:
	if winner != TacticalVictory.NOBODY:
		return {}
	return view().tint(state, TacticalScenario.FACTIONS - 1 - state.current_faction)


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
	elif keycode == KEY_M:
		swap_mode()
	elif keycode == KEY_V:
		_showing_decision = not _showing_decision
		_refresh()
	elif keycode == KEY_T:
		_showing_threat = not _showing_threat
		_refresh()
	else:
		_mode_key(keycode)


# A key the scene leaves to the mode, and what the mode says to do after it.
func _mode_key(keycode: Key) -> void:
	match view().pressed(keycode):
		TacticalModeView.NEW_GAME:
			new_game()
		TacticalModeView.DRAW:
			_refresh()


## Every controller C cycles through, named on screen under the board on
## either side's turn, so a person knows the computer is a slot and not a
## fixed opponent. Under the board, not in the status: the planner's plan
## filled the status column past the window's bottom (T102). The
## names come from the ruleset's roster -- `TacticalRoster` for Advance
## Wars, the default -- so the sentence cannot fall behind it.
static func controllers_to_come(rules: TacticalRuleset = null) -> String:
	var names: Array[String] = []
	for row_name: String in AdvanceWarsRuleset.or_default(rules).roster_names():
		names.append(TacticalStatus.name_said(row_name))
	return TranslationServer.translate("C hands the computer to the next controller -- {names} -- and S swaps sides; either starts a new game").format({
		names = ", ".join(names)})


## Hand the computer's side to the next row of the ruleset's roster, round to
## the first after the last, and start again: a controller swapped mid-game
## would inherit a board it did not play.
func swap_controller() -> void:
	computer = next_controller(computer, ruleset)
	new_game()


## The controller after `playing`: the next row of the ruleset's roster,
## built fresh. A level is seeded afresh each time, from the engine's own
## random numbers -- its noise is its own, never the board's dice.
static func next_controller(playing: BlueController, rules: TacticalRuleset = null) -> BlueController:
	var table: TacticalRuleset = AdvanceWarsRuleset.or_default(rules)
	return table.build_controller(table.controller_after(playing.controller_name()), randi())


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
		_last_refusal = view().moved_already(unit, _can_still_attack(unit), _turn.can_undo())


# True when `unit` may still attack this turn: it has not, and the mode
# lets it -- a piece that dashed may not shoot.
func _can_still_attack(unit: Unit) -> bool:
	return not _turn.has_attacked(unit.id) and ruleset.can_still_attack(state, unit)


# Walk the unit in hand along the cheapest route the highlight offered, or,
# for a cell it did not offer, try one step so the board says why not.
func _walk_to(cell: Vector2i) -> void:
	var unit: Unit = state.unit_by_id(_selected_id)
	if unit != null and _turn.is_spent(unit.id):
		_refuse(view().moved_already(unit, false, true))
		return
	var walks: Dictionary = TacticalReach.walks_for(_persons_board(), unit) if unit != null else {}
	var path: Array[Vector2i] = [cell]
	if walks.has(cell):
		path = walks[cell]
	var move := Move.new(_selected_id, path)
	var before: BoardState = state
	if _act(ruleset.walk(state, move), _explained(ruleset.why_walk_refused(state, move), cell)):
		_note(TacticalDecision.walk(move.unit_id, path, [], cell), before)
		_units.walk(unit.id, unit.cell, path)
		_turn.spend(_selected_id)
		# A walk that showed an enemy cannot be taken back: Z would let a
		# person look round a corner for free (T85).
		if view().reveals(before, state, person_side):
			_turn.seal()
			_sealed_by_a_reveal = true
			_tell(Sentence.of("an enemy came into sight: the walk cannot be taken back"))  # shown through tr()
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
	if not refusal.ends_with("is blocked") or not state.graph.contains(cell):  # not shown: the board's English, compared
		return refusal
	match view().rows()[cell.y][cell.x]:
		TacticalRules.WATER:
			return tr("{refusal}: water, which only waders cross").format({refusal = TacticalRefusal.words(refusal)})
		TacticalRules.ROCK:
			return tr("{refusal}: rock, which nothing crosses").format({refusal = TacticalRefusal.words(refusal)})
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
	_last_event.clear()
	if state.current_faction != person_side:
		_open_turn()
		_last_event = _with_computer_news(_last_event)
	_turn.begin()
	_sealed_by_a_reveal = false
	_last_refusal = ""
	_confirming_end = false
	_select_next_unspent()
	_refresh()


# The next side's turn: income and the points it holds, fresh movement, then
# its towers fire, and what happened is the first thing that side reads.
func _open_turn() -> void:
	var opened: Array = ruleset.open_turn(state)
	state = opened[0]
	_last_event.assign(opened[1])
	winner = ruleset.winner(state)


# What the person reads first: the computer's attacks of the turn just
# played, then what the person's own towers did.
func _with_computer_news(towers: Array[Array]) -> Array[Array]:
	if _computer_news.is_empty():
		return towers
	var lines: Array[Array] = [Sentence.of("{side}'s attacks:", {  # shown through tr()
		side = TacticalStatus.side_word(TacticalScenario.FACTIONS - 1 - person_side)})]
	lines.append_array(_computer_news)
	lines.append_array(towers)
	return lines


# The last event becomes `sentence`, the one line of news.
func _tell(sentence: Array) -> void:
	_last_event.clear()
	_last_event.append(sentence)


## The news on the panel in English, one line an event: what the AI and the
## person did, as the game keeps it -- for a test to read whatever the
## language on screen (T110).
func news_in_english() -> String:
	return "\n".join(_last_event.map(Sentence.english))


# The news in the language on screen, worded here, where it is shown, so a
# language switched mid-turn rewords it with the rest of the status -- and
# through the fog on screen, so a piece the person cannot see is not named
# by its own news (T127).
func _news_said() -> String:
	var fog: TacticalFog = _drawn_fog()
	return "\n".join(_last_event.map(func(sentence: Array) -> String: return view().news_said(sentence, fog)))


# The next of the person's units that can still walk, or nothing when none can.
func _select_next_unspent() -> void:
	var waiting: Array[int] = _turn.unspent(state)
	_selected_id = waiting[0] if not waiting.is_empty() else -1


func _described(decision: TacticalDecision) -> Dictionary:
	return {"unit": decision.unit_id, "kind": decision.kind(), "why": decision.english(), "target": decision.target}


func _refresh() -> void:
	if state == null:
		return
	_look()
	# The computer's turn draws neither the person's reach nor their spent
	# units: what is on screen then is the computer's decision.
	var reach: Array[Vector2i] = []
	_units.spent.clear()
	if _persons_turn():
		reach = _steps_in_reach()
		_units.spent = _turn.spent_ids()
	var built: Dictionary = view().building()
	if not built.is_empty():
		_draw_building(built)
	else:
		_board.draw_board(state.graph, reach, view().points(), _terrain())
		_draw_what_is_seen()
	_header.text = "\n".join(_header_lines())
	_keep_if_over()
	_end_button.disabled = not _persons_turn()
	_undo_button.disabled = not (_persons_turn() and _turn.can_undo())
	_status.text = _status_text()
	if _records():
		_status.text += "\n" + tr("recording: {count} game(s) kept in data/tactical/").format({count = games_kept})


# The pieces, the fog, the computer's decision and what it weighed, the
# dash, the odds and the tint -- the pieces from the view of whoever's
# board is on screen (`_drawn_fog`), the whole board in a mode without fog.
func _draw_what_is_seen() -> void:
	var fog: TacticalFog = _drawn_fog()
	var shown: BoardState = fog.seen if fog != null else state
	_units.show_state(shown, _board, _selected_id)
	_intent.show_fog(fog)
	var next: TacticalDecision = _computer_turn.next if _computer_thinking() else null
	_intent.show_decision(TacticalFog.clipped(fog, next), state, _board)
	var marks: Dictionary[Vector2i, String] = {}
	var weighed: Array[Dictionary] = []
	if _computer_thinking():
		marks = computer.plan_marks(state)
		if _weighing_drawn():
			weighed = computer.weighed()
	_intent.show_plan(marks)
	_intent.show_weighed(weighed)
	var unit: Unit = state.unit_by_id(_selected_id)
	var odds: Dictionary[Vector2i, String] = {}
	if _persons_turn() and unit != null and not _turn.has_attacked(unit.id):
		odds = view().odds(state, _selected_id)
	_intent.show_odds(odds)
	_intent.show_dashes(_dashes_in_reach())
	var tinted: Dictionary[Vector2i, int] = {}
	if _showing_threat:
		tinted = _tint()
	_intent.show_threat(tinted, view().tint_is_a_chance())


# What a mode is building in place of the game (T96): the board drawn from
# its rows, no pieces, its words on the cells, the next cells in the dash's
# tint and where it failed in the threat's.
func _draw_building(built: Dictionary) -> void:
	_board.draw_board(TacticalRules.graphs_from(view().rows())[UnitType.GROUND], [], [], _terrain())
	_units.show_state(BoardState.new(state.graph, [] as Array[Unit], state.current_faction), _board, -1)
	_intent.show_fog(null)
	_intent.show_decision(null, state, _board)
	_intent.show_plan({} as Dictionary[Vector2i, String])
	_intent.show_weighed([] as Array[Dictionary])
	_intent.show_odds(built["labels"])
	_intent.show_dashes(built["next"])
	_intent.show_threat(built["stuck"])


# The three lines over the board, and in a game of several modes a fourth
# naming this one and the key that changes it.
func _header_lines() -> Array[String]:
	var lines: Array[String] = [view().what_this_is(), view().rule(), tr("you play {person}; {computer} is played by {controller}").format({
		person = TacticalStatus.side_name(person_side), computer = TacticalStatus.side_name(TacticalScenario.FACTIONS - 1 - person_side),
		controller = computer.describe()})]
	if modes.size() > 1:
		var other: TacticalRuleset = modes[(modes.find(ruleset) + 1) % modes.size()]
		lines.append(tr("mode: {mode}  ·  M plays {other}").format({mode = view().title(), other = other.mode_view().title()}))
	if _person_fog != null:
		lines[lines.size() - 1] += "  ·  " + tr("V shows or hides what the computer sees and weighs")
	return lines


# What each side of a mode with fog sees now, each remembering its last look.
func _look() -> void:
	_person_fog = view().fog(state, person_side, _person_fog)
	_computer_fog = view().fog(state, TacticalScenario.FACTIONS - 1 - person_side, _computer_fog)


# The fog on screen: the computer's while it is thinking with V on, the
# person's otherwise; null in a mode without fog.
func _drawn_fog() -> TacticalFog:
	if _computer_thinking() and _showing_decision and _computer_fog != null:
		return _computer_fog
	return _person_fog


# True when the board may draw what the computer weighed: it is drawn on
# the computer's own view, or on a board with no fog, never over the
# person's fog -- and the overlay holds it only when it is drawn (T124).
func _weighing_drawn() -> bool:
	var fog: TacticalFog = _drawn_fog()
	return fog == null or fog == _computer_fog


# The board the person acts on: what their side sees, or the whole board.
func _persons_board() -> BoardState:
	return _person_fog.seen if _person_fog != null else state


# What T tints: the mode view's, about the cell under the cursor in a mode
# that asks; nothing once the game is over.
func _tint() -> Dictionary[Vector2i, int]:
	if winner != TacticalVictory.NOBODY:
		return {}
	var in_hand: int = _selected_id if _persons_turn() else -1
	return view().tint_at(state, TacticalScenario.FACTIONS - 1 - state.current_faction, _cursor, person_side, in_hand)


# True when this game is being recorded: the scene was opened to record, and
# it is playing Advance Wars. A game of another mode is never written to
# `data/tactical/`: the cloned player learns from those files, and a
# recording replays by the Advance Wars rules (wave 113's review).
func _records() -> bool:
	return recording and ruleset.mode_name() == AdvanceWarsRuleset.MODE


# Write `decision`, played on `before`, into this game's rows -- when
# recording, and only then.
func _note(decision: TacticalDecision, before: BoardState) -> void:
	if _records():
		_recorded.append(TacticalRecording.row_of(decision, before))


# When recording, write this game to `data/tactical/` once it is over: only a
# game played to its end is kept, so a restart is not a game.
func _keep_if_over() -> void:
	if not _records() or _kept or winner == TacticalVictory.NOBODY:
		return
	_kept = true
	var rounds: int = mini(state.turn_number / TacticalScenario.FACTIONS + 1, TacticalVictory.ROUND_LIMIT)
	var kept: Dictionary = TacticalRecording.made(_recorded.duplicate(), _starting_seed, TacticalRecording.PERSON,
		person_side, computer.controller_name(), winner, rounds)
	if TacticalRecording.save(kept, recordings_folder) != "":
		games_kept += 1


func _status_text() -> String:
	if winner != TacticalVictory.NOBODY:
		return view().announcement(winner, state)
	if not _persons_turn():
		return view().computer_status(state, _computer_turn, computer, _news_said(), _drawn_fog())
	var unit: Unit = state.unit_by_id(_selected_id)
	var news: String = _news_said()
	if unit == null and _turn.unspent(state).is_empty():
		news = (news + "\n" if news != "" else "") + tr("every unit has moved: space ends the turn")
	return view().status(state, unit, _last_refusal, news, unit != null and not _turn.has_attacked(unit.id))


# Every cell the unit in hand can walk to this turn, on the board its side
# sees; nothing for a spent one.
func _steps_in_reach() -> Array[Vector2i]:
	var unit: Unit = state.unit_by_id(_selected_id)
	var found: Array[Vector2i] = []
	if unit != null and not _turn.is_spent(unit.id):
		found.assign(TacticalReach.walks_for(_persons_board(), unit).keys())
	return found


# The cells of the reach that only a dash reaches, in a mode with dashes.
func _dashes_in_reach() -> Array[Vector2i]:
	var unit: Unit = state.unit_by_id(_selected_id)
	if not _persons_turn() or unit == null or _turn.is_spent(unit.id):
		return []
	return view().dashes(_persons_board(), unit, TacticalReach.walks_for(_persons_board(), unit))


# The ground the board's costs alone would draw wrong: trees as rough ground,
# water as a wall, the bridge as open ground. The scene draws it, from the
# rows the mode's view says it plays on: the tactical map, or the map the
# XCOM-style mode built or is building (T96).
func _terrain() -> Dictionary:
	var tiles: Dictionary = {}
	var kinds: Dictionary = {
		TacticalRules.TREES: BoardView.TREES, TacticalRules.WATER: BoardView.WATER,
		TacticalRules.BRIDGE: BoardView.BRIDGE, TacticalRules.FORD: BoardView.ROUGH,
	}
	for letter: String in kinds:
		for cell: Vector2i in TacticalRules.cells_of(view().rows(), letter):
			tiles[cell] = kinds[letter]
	return tiles
