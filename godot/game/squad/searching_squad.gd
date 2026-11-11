## What the XCOM-style mode's two enemies that search have in common (T88):
## they perceive the same way, ask a search the same question, and show
## and play its answer the same way. `MctsSquad` (T87) searches with Monte
## Carlo tree search, `ExpectiSquad` (T88) with expectiminimax; this is
## everything that is not the search, so the two are compared on the same
## information and nothing else.
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
## Decide: the piece's whole question -- hold, walk to each cell, or shoot
## each target -- is the root of a `SquadSearchGame` position on that
## board, and the subclass searches it. Anytime both ways: built for the
## scene (`spread_over_frames`), one frame's count of work when asked and
## the rest a frame at a time (`keep_thinking`) -- each frame a share of
## the wall clock when the subclass names one (T117), its count otherwise;
## built for T88's duel (`think_for`), a fixed time on the wall clock;
## built anywhere else, its whole budget at once. The decision the scene
## draws is rewritten in place after each frame: space plays what it
## believes now.
##
## When not to use it: a controller that does not search one piece's
## question. `WeighedSquad` perceives the same way and weighs one action.
@abstract
class_name SearchingSquad
extends BlueController

## How much work a share of the wall clock is, in `think_for`: one unit --
## an iteration, a position -- between two looks at the clock.
const CLOCK_SHARE: int = 1
## The budget a search has under `think_for`: none but the clock.
const UNLIMITED: int = 1 << 30

static var _starting: Array[Unit] = []

## The wall clock each `keep_thinking` frame may search, in microseconds,
## once `spread_over_frames` set it; 0 counts work a frame instead. Only
## how many frames a decision takes depends on it, never what is decided:
## the budget in work is the same either way.
var frame_share_usec: int = 0

var _seed_number: int
# Work a frame once `spread_over_frames` is called; 0 runs it all at once.
var _per_frame: int = 0
# Milliseconds a decision once `think_for` is called; 0 counts work instead.
var _clock_msec: int = 0
# What its side saw at its last look, and every enemy it has seen, as it was
# when last seen; forgotten when a new game starts.
var _memory: SideView
var _known: Dictionary[int, Unit] = {}
var _last_turn: int = -1
var _decisions: int = 0
var _work: int = 0
# Questions it held on because it believed the game already over.
var _held_on_a_game_over: int = 0
# The decision the scene holds, and the board and routes it was made on.
var _pending: TacticalDecision
var _believed: BoardState
var _routes: Dictionary = {}


func _init(seed_number: int = 0) -> void:
	_seed_number = seed_number


## The scene's way of running it: one frame's count of work when a
## decision is asked, the rest by `keep_thinking`, frame after frame, each a
## share of the wall clock when the subclass names one.
func spread_over_frames() -> void:
	_per_frame = _work_per_frame()
	frame_share_usec = _frame_share_usec()


## T88's duel's way of running it: every decision searched for
## `milliseconds` of the wall clock, whatever that buys on this machine --
## the budget in work is lifted. The answers then depend on the machine and
## its load: a measurement, never a replay.
func think_for(milliseconds: int) -> void:
	_clock_msec = maxi(milliseconds, 1)


## A turn numbered no later than the last one it saw is a new game: what it
## remembered belongs to the old one.
func begin_turn(state: BoardState) -> void:
	if state.turn_number <= _last_turn:
		_memory = null
		_known.clear()
	_last_turn = state.turn_number
	_stop_search()


## A squad has no workshop: it never builds.
func decide_build(state: BoardState, workshop_id: int) -> TacticalDecision:
	return TacticalDecision.hold(workshop_id, [], state.unit_by_id(workshop_id).cell)


## The walk -- holding is one -- that `unit_id`'s search prefers.
func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
	var believed: BoardState = believe(state)
	var cell: Vector2i = believed.unit_by_id(unit_id).cell
	_pending = TacticalDecision.hold(unit_id, Sentence.of("has nowhere to walk"), cell)  # shown through tr()
	_begin(believed, unit_id, SquadSearchGame.WALK)
	return _pending


## The shot `unit_id`'s search prefers, a hold when holding its fire is
## preferred; null when it has nobody to shoot.
func decide_attack(state: BoardState, unit_id: int) -> TacticalDecision:
	var believed: BoardState = believe(state)
	if SquadSearchGame.shots(believed, believed.unit_by_id(unit_id)).is_empty():
		_drop_search()
		return null
	_pending = TacticalDecision.hold(unit_id, [], believed.unit_by_id(unit_id).cell)
	_begin(believed, unit_id, SquadSearchGame.SHOOT)
	return _pending


## One more frame of the search under way, the decision rewritten from it;
## false when there is none, or its budget is spent.
func keep_thinking() -> bool:
	if not _has_work_left():
		return false
	if frame_share_usec > 0:
		_search_for(frame_share_usec)
	else:
		_search_more(_per_frame)
	_show()
	return true


## After a walk the board refused -- it ran into a piece its side does not
## see -- the walk its search prefers most that crosses none of the refused
## route's cells, or holding. Null for anything but a walk.
func after_refusal(_state: BoardState, refused: TacticalDecision) -> TacticalDecision:
	if refused.move == null or _chosen() == null:
		return null
	var unit: Unit = _believed.unit_by_id(refused.unit_id)
	var instead := TacticalDecision.hold(unit.id, Sentence.of("its walk was refused, and it holds"), unit.cell)  # shown through tr()
	var most: float = -INF
	for option: Dictionary in _options():
		var action: Array = option["action"]
		if action[0] != SquadSearchGame.WALK_WORD or option["preference"] <= most:
			continue
		var path: Array[Vector2i] = _routes.get(action[2], [] as Array[Vector2i])
		if not path.any(func(step: Vector2i) -> bool: return step in refused.move.path):
			most = option["preference"]
			instead = TacticalDecision.walk(unit.id, path, _refused_walk_reason(), action[2])
	_stop_search()
	return instead


## Every root answer of the last search, for the board: where it goes or
## whom it shoots, the search's own number for it as the score, the hit
## chance of a shot, the one it would play chosen -- and whatever else the
## search keeps of it besides.
func weighed() -> Array[Dictionary]:
	var shown: Array[Dictionary] = []
	if _believed == null:
		return shown
	for option: Dictionary in _options():
		var action: Array = option["action"]
		var entry: Dictionary = {"cell": _cell_of(action), "chance": _chance_of(action)}
		entry.merge(option)
		entry.erase("action")
		entry.erase("preference")
		shown.append(entry)
	return shown


## How much it has searched since it was made, in `work_unit`s.
func work_done() -> int:
	return _work


## How many questions it held on because the board it believed was already
## won or lost. In play, none: a side is not asked once a game is over
## (T134), and T88's duel fails a match where this is above zero.
func held_on_a_game_over() -> int:
	return _held_on_a_game_over


## What its search did, as lines for the status, in the language on
## screen; none before a search has begun.
@abstract func search_lines() -> Array[String]


## How to read its search on the board, in the language on screen.
@abstract func board_said() -> String


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


# How much work a frame is, for the scene, from the rules.
@abstract func _work_per_frame() -> int


# The wall clock a `keep_thinking` frame may search, in microseconds; 0, a
# count of work a frame instead, unless the subclass names a share.
func _frame_share_usec() -> int:
	return 0


# A new search from `root`, for the decision `_pending` holds. Searches
# nothing yet.
@abstract func _start_search(root: SquadSearchGame.Position) -> void


# `count` more units of work on the search under way, never past its budget.
@abstract func _search_more(count: int) -> void


# True while the search under way has budget left.
@abstract func _has_work_left() -> bool


# Stop the search under way, keeping what it found: the board may still
# draw it, and a refused walk still be answered from it.
@abstract func _stop_search() -> void


# Forget the search under way and what it found.
@abstract func _drop_search() -> void


# Every root answer of the search, in the game's order: `{"action",
# "preference", "chosen"}` -- `preference` what makes one better than
# another to this search -- and whatever else it shows of each.
@abstract func _options() -> Array[Dictionary]


# The chosen answer, and why, in the search's numbers; null before the
# search has one.
@abstract func _chosen() -> Variant


# Why the walk after a refusal was taken: a `Sentence`, worded where shown.
@abstract func _refused_walk_reason() -> Array


# A new search for `unit_id`'s `phase` question on `believed`, run for one
# frame's share -- the clock's, or all of it -- when it has more than one
# answer.
func _begin(believed: BoardState, unit_id: int, phase: int) -> void:
	_believed = believed
	_drop_search()
	# A board it believes already won or lost has nothing to search: the
	# root would have no answer, and T87's `_chosen` crashed on one in wave
	# 136's duel. The belief was right -- its shot had just destroyed the
	# last enemy, and `BlueTurn` asked the next piece anyway; since T134
	# `BlueTurn` asks nobody once a game is over. Kept for a caller that
	# asks directly: it holds, says why, and is counted.
	if SquadVictory.winner(believed) != TacticalVictory.NOBODY:
		_held_on_a_game_over += 1
		_pending.reason = Sentence.of("believes no enemy is left, and holds", {})  # shown through tr()
		return
	if SquadSearchGame.answers(believed, unit_id, phase).size() <= 1:
		return
	var after: Array[int] = []
	var asked_already: bool = true
	for piece: Unit in believed.units_of(believed.current_faction):
		if not asked_already:
			after.append(piece.id)
		asked_already = asked_already and piece.id != unit_id
	_decisions += 1
	_routes = TacticalReach.walks_for(believed, believed.unit_by_id(unit_id)) if phase == SquadSearchGame.WALK else {}
	_start_search(SquadSearchGame.Position.new(believed, unit_id, phase, after))
	if _clock_msec > 0:
		_search_for(_clock_msec * 1000)
	else:
		_search_more(_per_frame if _per_frame > 0 else UNLIMITED)
	_show()


# Work, `CLOCK_SHARE` at a time, until `microseconds` of the wall clock are
# spent or the budget is -- and at least once, so that a frame always moves
# the search on. Past the deadline by one unit at most: the clock is read
# between units, never inside one.
func _search_for(microseconds: int) -> void:
	var deadline: int = Time.get_ticks_usec() + microseconds
	_search_more(CLOCK_SHARE)
	while Time.get_ticks_usec() < deadline and _has_work_left():
		_search_more(CLOCK_SHARE)


# `_pending` made to say what the search would play now: its walk, its
# shot or its hold, and why.
func _show() -> void:
	var chosen: Variant = _chosen()
	if chosen == null:
		return
	var action: Array = chosen["action"]
	_pending.move = null
	_pending.attack = null
	_pending.target = _cell_of(action)
	_pending.reason = chosen["reason"]
	if action[0] == SquadSearchGame.WALK_WORD:
		_pending.move = Move.new(_pending.unit_id, _routes[action[2]])
	elif action[0] == SquadSearchGame.SHOOT_WORD:
		_pending.attack = Attack.new(_pending.unit_id, action[2])


# The seed a decision's search draws from: a new one each decision.
func _decision_seed() -> int:
	return _seed_number * 7919 + _decisions


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
