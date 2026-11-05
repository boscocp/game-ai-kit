## The XCOM-style mode's enemy that searches (T87): Monte Carlo tree search
## from `ai_adversarial`, over `SquadSearchGame`, for the piece about to act.
##
## Perceive: its side's view (`SideView`), as `WeighedSquad` perceives, and
## what it remembers of each enemy it has seen -- where, and how much health
## it had then. A search needs a whole board, and the view is not one, so
## it searches the board it *believes* in: every enemy it sees where it is;
## every enemy it has lost sight of where it last saw it, as hurt as it was
## then; every enemy it has never seen where the scenario starts it, whole.
## A believed enemy whose cell its side now sees empty, or is taken, stands
## on the nearest cell its side does not see. One guess -- one
## determinization -- not several sampled and searched in turn: that is
## named in `docs/godot/squad.md` as the step after this one.
##
## Decide: `iterations` iterations of UCT on that board (`rules.json`'s
## `search`), the most visited answer played. The tree is the piece's whole
## question -- hold, walk to each cell, or shoot each target -- and below it
## the rest of the turn, the other side's, and playouts scored on health.
##
## Anytime: built for the scene (`spread_over_frames`), it runs one frame's
## iterations when asked and the rest a frame at a time (`keep_thinking`),
## and the decision the scene draws is rewritten in place each frame: space
## plays what it believes now. Built anywhere else -- a match, a test -- it
## runs the whole budget when asked.
##
## What it shows (invariant 13): every root answer's visits, mean and UCB1
## bound, on the board (`weighed`) and as bars in the status
## (`search_lines`), growing while it thinks; then the line of play it
## expects (`MonteCarloSearch.principal_line`).
##
## O(iterations x playout length x a piece's reach) a decision. When not to
## use it: when one action ahead is enough to see the answer -- `WeighedSquad`
## decides in a millisecond what this takes a second to find, or misses.
class_name MctsSquad
extends BlueController

## How many answers the status draws a bar for, the most visited first.
const LINES_SHOWN: int = 6
## The width of the longest bar, in characters.
const BAR_WIDTH: int = 20
## How many moves of the expected line the status writes.
const LINE_LENGTH: int = 6

## The iterations it searches a decision.
var iterations: int

static var _starting: Array[Unit] = []

var _seed_number: int
var _game := SquadSearchGame.new()
# Iterations a frame once `spread_over_frames` is called; 0 runs them all at once.
var _per_frame: int = 0
# What its side saw at its last look, and every enemy it has seen, as it was
# when last seen; forgotten when a new game starts.
var _memory: SideView
var _known: Dictionary[int, Unit] = {}
var _last_turn: int = -1
var _decisions: int = 0
var _work: int = 0
# The search for the decision being made, what is left of its budget, the
# decision the scene holds, and the board and routes it was made on.
var _search: MonteCarloSearch
var _left: int = 0
var _pending: TacticalDecision
var _found: MctsResult
var _believed: BoardState
var _routes: Dictionary = {}


func _init(seed_number: int = 0, budget: int = -1) -> void:
	_seed_number = seed_number
	iterations = budget if budget > 0 else int(search_rules()["iterations"])


## The scene's way of running it: one frame's iterations when a decision is
## asked, the rest by `keep_thinking`, frame after frame.
func spread_over_frames() -> void:
	_per_frame = int(search_rules()["iterations_per_frame"])


## `rules.json`'s `search`: the numbers this enemy searches with.
static func search_rules() -> Dictionary:
	return SquadTable.rules()["search"]


## UCB1's constant, from the rules.
static func exploration() -> float:
	return float(search_rules()["exploration"])


## How many answers a playout plays before it is scored, from the rules.
static func playout_limit() -> int:
	return int(search_rules()["playout_limit"])


## "mcts".
func controller_name() -> String:
	return "mcts"  # not shown: a roster key


## What it is, for the screen.
func describe() -> String:
	return TranslationServer.translate("Monte Carlo tree search over the piece's options and the turns after, on the board its side believes in")


## A turn numbered no later than the last one it saw is a new game: what it
## remembered belongs to the old one.
func begin_turn(state: BoardState) -> void:
	if state.turn_number <= _last_turn:
		_memory = null
		_known.clear()
	_last_turn = state.turn_number
	_search = null


## A squad has no workshop: it never builds.
func decide_build(state: BoardState, workshop_id: int) -> TacticalDecision:
	return TacticalDecision.hold(workshop_id, [], state.unit_by_id(workshop_id).cell)


## The walk -- holding is one -- that `unit_id`'s search visited most.
func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
	var believed: BoardState = believe(state)
	var cell: Vector2i = believed.unit_by_id(unit_id).cell
	_pending = TacticalDecision.hold(unit_id, Sentence.of("has nowhere to walk"), cell)  # shown through tr()
	_start(believed, unit_id, SquadSearchGame.WALK)
	return _pending


## The shot `unit_id`'s search visited most, a hold when holding its fire
## was; null when it has nobody to shoot.
func decide_attack(state: BoardState, unit_id: int) -> TacticalDecision:
	var believed: BoardState = believe(state)
	if SquadSearchGame.shots(believed, believed.unit_by_id(unit_id)).is_empty():
		_search = null
		_found = null
		return null
	_pending = TacticalDecision.hold(unit_id, [], believed.unit_by_id(unit_id).cell)
	_start(believed, unit_id, SquadSearchGame.SHOOT)
	return _pending


## One more frame of the search under way, the decision rewritten from it;
## false when there is none, or its budget is spent.
func keep_thinking() -> bool:
	if _search == null or _left <= 0:
		return false
	_run(_per_frame)
	return true


## After a walk the board refused -- it ran into a piece its side does not
## see -- the most visited walk that crosses none of the refused route's
## cells, or holding. Null for anything but a walk.
func after_refusal(_state: BoardState, refused: TacticalDecision) -> TacticalDecision:
	if refused.move == null or _found == null:
		return null
	var unit: Unit = _believed.unit_by_id(refused.unit_id)
	var instead := TacticalDecision.hold(unit.id, Sentence.of("its walk was refused, and it holds"), unit.cell)  # shown through tr()
	var most: int = -1
	for entry: Dictionary in _found.considered:
		var action: Array = entry["action"]
		if action[0] != SquadSearchGame.WALK_WORD or entry["visits"] <= most:
			continue
		var path: Array[Vector2i] = _routes.get(action[2], [] as Array[Vector2i])
		if not path.any(func(step: Vector2i) -> bool: return step in refused.move.path):
			most = entry["visits"]
			instead = TacticalDecision.walk(unit.id, path, Sentence.of("its walk was refused; the next most visited", {}), action[2])  # shown through tr()
	_search = null
	return instead


## Every root answer of the last search, for the board: where it goes or
## whom it shoots, its mean as the score, the hit chance of a shot, the most
## visited chosen -- and its visits and bound besides.
func weighed() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if _found == null or _believed == null:
		return options
	for entry: Dictionary in _found.considered:
		var action: Array = entry["action"]
		options.append({"cell": _cell_of(action), "score": entry["mean"], "chance": _chance_of(action),
			"chosen": action == _found.action, "visits": entry["visits"], "bound": entry["bound"]})
	return options


## What its search did, as lines for the status: the iterations so far, a
## bar of visits for each of the answers visited most, with the mean and the
## bound, and the line of play it expects. In the language on screen.
func search_lines() -> Array[String]:
	var lines: Array[String] = []
	if _found == null:
		return lines
	lines.append(TranslationServer.translate("searched {done} of {budget} iterations; the bar is each option's visits:").format({
		done = _found.iterations, budget = iterations}))
	var ranked: Array[Dictionary] = _found.considered.duplicate()
	ranked.sort_custom(func(one: Dictionary, other: Dictionary) -> bool: return one["visits"] > other["visits"])
	var most: int = maxi(1, ranked[0]["visits"])
	for entry: Dictionary in ranked.slice(0, LINES_SHOWN):
		lines.append(TranslationServer.translate("{bar} {option}: {visits} visits, mean {mean}, bound {bound}").format({
			bar = "█".repeat(ceili(BAR_WIDTH * float(entry["visits"]) / most)).rpad(BAR_WIDTH, "·"),
			option = answer_said(entry["action"]), visits = entry["visits"], mean = "%+.2f" % entry["mean"],
			bound = "%+.2f" % entry["bound"] if is_finite(entry["bound"]) else "∞"}))
	if ranked.size() > LINES_SHOWN:
		lines.append(TranslationServer.translate("and {count} more").format({count = ranked.size() - LINES_SHOWN}))
	var expected: Array = _search.principal_line(LINE_LENGTH) if _search != null else []
	if not expected.is_empty():
		lines.append(TranslationServer.translate("the line it expects: {line}").format({
			line = ", ".join(expected.map(answer_said))}))
	return lines


## How much it has searched since it was made, in iterations.
func work_done() -> int:
	return _work


## "iterations".
func work_unit() -> String:
	return "iterations"  # not shown: the meter's unit, an identifier


## An answer of `SquadSearchGame` in the language on screen.
static func answer_said(action: Array) -> String:
	if action[0] == SquadSearchGame.WALK_WORD:
		return TranslationServer.translate("{unit} walks to {cell}").format({unit = action[1], cell = action[2]})
	if action[0] == SquadSearchGame.SHOOT_WORD:
		return TranslationServer.translate("{unit} shoots {target}").format({unit = action[1], target = action[2]})
	return TranslationServer.translate("{unit} holds").format({unit = action[1]})


## The board it believes in: its side's view of `state`, with each enemy it
## does not see where it guesses -- the only thing it reads of the board.
func believe(state: BoardState) -> BoardState:
	var side: int = state.current_faction
	_memory = SideView.seen_by(state, SquadScenario.rows(), side, _memory)
	var believed: BoardState = _memory.state.duplicate_state()
	for enemy: Unit in believed.units:
		if enemy.faction != side:
			_known[enemy.id] = enemy.duplicate_unit()
	for guess: Unit in _guessed_enemies(side):
		guess.cell = _nearest_hiding_cell(believed, guess)
		believed.units.append(guess)
	return believed


# Every enemy its side does not see, as it guesses it: where it was last
# seen and as hurt as it was then, or -- never seen -- as the scenario
# starts it. An enemy it once saw that is neither seen nor remembered now
# was destroyed: a side is told of that (`SideView`).
func _guessed_enemies(side: int) -> Array[Unit]:
	var guessed: Array[Unit] = []
	for start: Unit in _start_units():
		if start.faction == side or _memory.state.unit_by_id(start.id) != null:
			continue
		if _memory.last_seen.has(start.id):
			var last: Unit = _known[start.id].duplicate_unit()
			last.cell = _memory.last_seen[start.id]
			guessed.append(last)
		elif not _known.has(start.id):
			guessed.append(start.duplicate_unit())
	return guessed


# The pieces as the scenario starts them, which every side knows: built
# once, since a search asks for them every decision.
static func _start_units() -> Array[Unit]:
	if _starting.is_empty():
		_starting = SquadScenario.build().units
	return _starting


# Where `guess` is believed to stand on `believed`: its own cell when its
# side does not see that cell and nothing stands there; otherwise the
# nearest cell, in steps, that is free, open to its feet and unseen -- of
# equals the first row by row.
func _nearest_hiding_cell(believed: BoardState, guess: Unit) -> Vector2i:
	var best: Vector2i = guess.cell
	var best_steps: int = SquadSearchGame.UNREACHED
	for cell: Vector2i in SquadRuleset.every_cell():
		var apart: int = SquadSight.steps(cell, guess.cell)
		if apart < best_steps and _can_hide(believed, guess, cell):
			best = cell
			best_steps = apart
	return best


func _can_hide(believed: BoardState, guess: Unit, cell: Vector2i) -> bool:
	var open: bool = believed.unit_at(cell) == null and not believed.graph_for(guess).is_blocked(cell)
	return open and not SideView.is_seen(believed, SquadScenario.rows(), _memory.side, cell)


# A new search for `unit_id`'s `phase` question on `believed`, run for one
# frame's iterations -- or all of them -- when it has more than one answer.
func _start(believed: BoardState, unit_id: int, phase: int) -> void:
	_believed = believed
	_found = null
	_search = null
	if SquadSearchGame.answers(believed, unit_id, phase).size() <= 1:
		return
	var after: Array[int] = []
	var asked_already: bool = true
	for piece: Unit in believed.units_of(believed.current_faction):
		if not asked_already:
			after.append(piece.id)
		asked_already = asked_already and piece.id != unit_id
	var root := SquadSearchGame.Position.new(believed, unit_id, phase, after)
	_decisions += 1
	_search = MonteCarloSearch.new(_game, root, _seed_number * 7919 + _decisions, exploration(), playout_limit())
	_routes = TacticalReach.walks_for(believed, believed.unit_by_id(unit_id)) if phase == SquadSearchGame.WALK else {}
	_left = iterations
	_run(_per_frame if _per_frame > 0 else iterations)


# `count` more iterations, no more than the budget has left, and the
# decision rewritten from where the search now stands.
func _run(count: int) -> void:
	var running: int = mini(count, _left)
	_found = _search.step(running)
	_left -= running
	_work += running
	_rewrite(_pending, _found)


# `decision` made to say what `found` would play now: its walk, its shot or
# its hold, and why, in the search's numbers.
func _rewrite(decision: TacticalDecision, found: MctsResult) -> void:
	var action: Array = found.action
	var best: Dictionary = found.considered.filter(func(entry: Dictionary) -> bool: return entry["action"] == action)[0]
	decision.move = null
	decision.attack = null
	decision.target = _cell_of(action)
	decision.reason = Sentence.of("searched {done} iterations: {count} option(s), this one visited most, {visits} times, mean {mean}", {  # shown through tr()
		done = found.iterations, count = found.considered.size(), visits = best["visits"], mean = "%+.2f" % best["mean"]})
	if action[0] == SquadSearchGame.WALK_WORD:
		decision.move = Move.new(decision.unit_id, _routes[action[2]])
	elif action[0] == SquadSearchGame.SHOOT_WORD:
		decision.attack = Attack.new(decision.unit_id, action[2])


# The cell an answer is about: the walk's goal, the target's cell, or the
# piece's own for a hold.
func _cell_of(action: Array) -> Vector2i:
	if action[0] == SquadSearchGame.WALK_WORD:
		return action[2]
	if action[0] == SquadSearchGame.SHOOT_WORD:
		return _believed.unit_by_id(action[2]).cell
	return _believed.unit_by_id(action[1]).cell


# A shot's hit chance on the board it searched; -1 for anything else.
func _chance_of(action: Array) -> int:
	if action[0] != SquadSearchGame.SHOOT_WORD:
		return -1
	return SquadCombat.chance_of(SquadScenario.rows(), _believed.unit_by_id(action[1]), _believed.unit_by_id(action[2]))
