## The XCOM-style mode as a game a search can read (T87): the squad's side
## of `GakAdversarialGame`, so that `MonteCarloSearch` from `ai_adversarial`
## plays this mode without learning anything about squads.
##
## A position is one question, T84's one-unit decision: the board, the piece
## about to act, whether it is about to walk or to shoot, and the pieces of
## its side still to act after it, in the order `BlueTurn` asks them. Its
## answers (`actions`):
##
## - **a walk question**: hold, then every cell the piece can reach this
##   turn, row by row -- `["hold", id]`, `["walk", id, cell, cost]`;
## - **a shot question**: hold, then every enemy it may shoot, by id --
##   `["shoot", id, target id]`.
##
## A question with one answer, hold, is not asked: a piece that dashed, or
## sees nobody, goes straight to the next. After the last piece the turn
## passes, and the other side's pieces are asked in their turn.
##
## A shot has two `outcomes`, hit and miss, with the hit chance T84 shows
## the person (`SquadCombat`); `result` is the likelier, for a search with
## no dice. `evaluate` is +1, -1 or 0 once the game is over, and before
## that each side's health left, the difference over a full squad's: in
## [-1, 1], as the addon asks. Python's `gameaikit.squad.search_game` is the
## same game, and `spec/squad/positions.json` holds the two to one tree.
##
## The board it is handed is the whole truth to it. Fog is not its business:
## `MctsSquad` hands it the board its side believes in.
##
## Complexity: a walk question floods the piece's reach, a uniform-cost
## flood over at most the 126 cells; a shot question draws a line to each
## enemy. When not to use it: overwatch, or anything else that acts in the
## other side's turn -- a position here has one side to move.
class_name SquadSearchGame
extends GakAdversarialGame

const WALK: int = 0
const SHOOT: int = 1
## The answers' first words.
const HOLD_WORD: String = "hold"
const WALK_WORD: String = "walk"
const SHOOT_WORD: String = "shoot"
## A cell no walk reaches, in `reach`.
const UNREACHED: int = 1 << 30
# A cell a piece stands on, while `reach` floods: below any cost, so no
# walk improves on it.
const TAKEN: int = -2

## How many graphs' costs `reach` keeps at once: a game has two, the
## ground's and the wader's.
const COSTS_KEPT: int = 8

static var _full_health: int = 0
# A graph's instance id -> what entering each of its cells costs.
static var _costs_by_graph: Dictionary = {}


## One question: who is about to act on `board`, and how. Never changed
## once a search holds it -- `SquadSearchGame` builds a new one each time.
class Position extends RefCounted:
	var board: BoardState
	## The piece about to act; -1 once the game is over.
	var unit_id: int
	## `WALK` or `SHOOT`.
	var phase: int
	## Its side's pieces still to act after it, in order.
	var waiting: Array[int]
	var _answers: Array = []

	func _init(on: BoardState, acting_id: int, asking: int, after: Array[int]) -> void:
		board = on
		unit_id = acting_id
		phase = asking
		waiting = after

	## Every answer to this question, worked out once.
	func answers() -> Array:
		if _answers.is_empty():
			_answers = SquadSearchGame.answers(board, unit_id, phase)
		return _answers

	## Forgets the answers, for a position still being built.
	func forget_answers() -> void:
		_answers = []


## The question `unit_id` is asked on `board`, `phase` first, with `after`
## to act after it -- or the next question worth asking, when this one has
## only one answer.
static func question(board: BoardState, unit_id: int, phase: int, after: Array[int]) -> Position:
	var asked := Position.new(board, unit_id, phase, after.duplicate())
	if SquadVictory.winner(board) != TacticalVictory.NOBODY or asked.answers().size() > 1:
		return asked
	return _next_question(asked)


## The side of the piece about to act.
func to_move(position: RefCounted) -> int:
	return (position as Position).board.current_faction


## Hold, then the walks or the shots, in their fixed order; none once the
## game is over.
func actions(position: RefCounted) -> Array:
	if is_terminal(position):
		return []
	return (position as Position).answers()


## The position after `action`; a shot as the likelier of its outcomes.
func result(position: RefCounted, action: Variant) -> RefCounted:
	var at: Position = position
	if action[0] == SHOOT_WORD:
		var possible: Array = outcomes(at, action)
		# Of equal chances the first, the hit.
		return possible[1]["state"] if possible.size() > 1 and possible[1]["probability"] > possible[0]["probability"] else possible[0]["state"]
	var board: BoardState = at.board
	if action[0] == WALK_WORD:
		board = walked(board, at.unit_id, action[2], action[3])
	return _next_question(Position.new(board, at.unit_id, at.phase, at.waiting.duplicate()))


## True once a squad has no piece left or the round limit has come.
func is_terminal(position: RefCounted) -> bool:
	return SquadVictory.winner((position as Position).board) != TacticalVictory.NOBODY


## +1, -1 or 0 once the game is over; before that, `player`'s health left
## less the other side's, over a full squad's.
func evaluate(position: RefCounted, player: int) -> float:
	var board: BoardState = (position as Position).board
	var won: int = SquadVictory.winner(board)
	if won == TacticalVictory.DRAW:
		return 0.0
	if won != TacticalVictory.NOBODY:
		return 1.0 if won == player else -1.0
	var other: int = TacticalScenario.FACTIONS - 1 - player
	return float(SquadVictory.health_left(board, player) - SquadVictory.health_left(board, other)) / full_health()


## A shot hits with its chance and misses with the rest; an outcome that
## cannot happen is left out. Anything else is certain.
func outcomes(position: RefCounted, action: Variant) -> Array:
	var at: Position = position
	if action[0] != SHOOT_WORD:
		return [{"probability": 1.0, "state": result(at, action)}]
	var shooter: Unit = at.board.unit_by_id(at.unit_id)
	var chance: int = SquadCombat.chance_of(SquadScenario.rows(), shooter, at.board.unit_by_id(action[2]))
	var found: Array = []
	if chance > 0:
		found.append({"probability": chance / 100.0, "state": _after_shot(at, action[2], true)})
	if chance < 100:
		found.append({"probability": 1.0 - chance / 100.0, "state": _after_shot(at, action[2], false)})
	return found


## Hold, then `unit_id`'s walks or shots on `board`.
static func answers(board: BoardState, unit_id: int, phase: int) -> Array:
	var found: Array = [[HOLD_WORD, unit_id]]
	var unit: Unit = board.unit_by_id(unit_id)
	if unit == null:
		return found
	if phase == WALK:
		found.append_array(walks(board, unit))
	else:
		found.append_array(shots(board, unit))
	return found


## `["walk", id, cell, cost]` for every cell `unit` can reach this turn, row by
## row: the same cells and costs as `TacticalReach.walks_for`, without the
## routes, which a search never needs.
static func walks(board: BoardState, unit: Unit) -> Array:
	var spent: PackedInt32Array = reach(board, unit)
	var width: int = board.graph.width
	var found: Array = []
	for index: int in range(spent.size()):
		var goal := Vector2i(index % width, index / width)
		if spent[index] != UNREACHED and goal != unit.cell:
			found.append([WALK_WORD, unit.id, goal, spent[index]])
	return found


## The cheapest walk's cost to each cell, row by row (`UNREACHED` where
## `unit` cannot get with the movement it has left), going round every
## piece, its own cell at 0: the costs `TacticalReach` floods to.
##
## Dijkstra's algorithm with a bucket for each cost instead of a priority
## queue (Dial's): a walk costs a small whole number, at most the piece's
## movement, so the cells reached at cost 0, then 1, then 2 can each be
## taken in turn. Kept in arrays by cell, not in dictionaries, because a
## search floods thousands of times a decision and this is where its time
## went: 750 microseconds a flood with `TacticalReach`, about 50 here
## (wave 125, the opening's runner).
static func reach(board: BoardState, unit: Unit) -> PackedInt32Array:
	var ground: GakGridGraph = board.graph_for(unit)
	var spent := PackedInt32Array()
	spent.resize(ground.width * ground.height)
	spent.fill(UNREACHED)
	for piece: Unit in board.units:
		spent[piece.cell.y * ground.width + piece.cell.x] = TAKEN
	var start: int = unit.cell.y * ground.width + unit.cell.x
	spent[start] = 0
	var buckets: Array[PackedInt32Array] = []
	buckets.resize(unit.movement_points + 1)
	buckets[0].append(start)
	var costs: PackedInt32Array = _entry_costs(ground)
	for cost: int in range(buckets.size()):
		# A cell put in a dearer bucket and reached more cheaply since is
		# relaxed twice; the second time finds nothing cheaper.
		for here: int in buckets[cost]:
			_relax(ground, costs, here, spent, buckets)
	for piece: Unit in board.units:
		if piece != unit:
			spent[piece.cell.y * ground.width + piece.cell.x] = UNREACHED
	return spent


## `["shoot", id, target id]` for every enemy `unit` may shoot now, by
## target id.
static func shots(board: BoardState, unit: Unit) -> Array:
	var targets: Array[int] = []
	for enemy: Unit in board.units:
		if SquadCombat.why_refused(board, SquadScenario.rows(), Attack.new(unit.id, enemy.id)) == BoardState.LEGAL:
			targets.append(enemy.id)
	targets.sort()
	return targets.map(func(target_id: int) -> Array: return [SHOOT_WORD, unit.id, target_id])


## `board` with `unit_id` walked to `goal` for `cost`; a dash spends it, as
## `SquadRuleset.walk` says.
static func walked(board: BoardState, unit_id: int, goal: Vector2i, cost: int) -> BoardState:
	var next: BoardState = board.duplicate_state()
	var walker: Unit = next.unit_by_id(unit_id)
	walker.cell = goal
	walker.movement_points -= cost
	if not SquadCombat.can_shoot(walker):
		walker.movement_points = 0
	return next


## An answer as both languages write it: "1 holds", "1 walks to 5,3 for
## 4" -- the cell, then the walk's cost -- or "3 shoots 6", by ids.
static func described(action: Array) -> String:
	if action[0] == WALK_WORD:
		return "%d walks to %d,%d for %d" % [action[1], action[2].x, action[2].y, action[3]]  # not shown: the vectors' words
	if action[0] == SHOOT_WORD:
		return "%d shoots %d" % [action[1], action[2]]  # not shown: the vectors' words
	return "%d holds" % action[1]  # not shown: the vectors' words


## A full squad's health, summed from the rules: the scale `evaluate`
## divides by.
static func full_health() -> int:
	if _full_health == 0:
		for piece_name: String in SquadTable.squad():
			_full_health += SquadTable.number(piece_name, "health")
	return _full_health


# The position after the shot at `target_id`, hit or missed: the shooter is
# spent either way, and a target left at 0 is gone.
func _after_shot(at: Position, target_id: int, hit: bool) -> Position:
	var next: BoardState = at.board.duplicate_state()
	next.unit_by_id(at.unit_id).movement_points = 0
	if hit:
		var target: Unit = next.unit_by_id(target_id)
		target.health = maxi(0, target.health - SquadTable.number(next.unit_by_id(at.unit_id).type.type_name, "damage"))
		# Built again: a board drops a piece at 0 health only when it is built.
		next = next.duplicate_state()
	return _next_question(Position.new(next, at.unit_id, at.phase, at.waiting.duplicate()))


# From the question `asked` stands on, on to the next one with more than one
# answer -- through the turn's end, when its side has no piece left to ask --
# or to the end of the game.
static func _next_question(asked: Position) -> Position:
	while SquadVictory.winner(asked.board) == TacticalVictory.NOBODY:
		_step_on(asked)
		if SquadVictory.winner(asked.board) == TacticalVictory.NOBODY and asked.answers().size() > 1:
			return asked
	asked.unit_id = -1
	return asked


# One question on: the same piece's shot after its walk, the next piece's
# walk, or -- after the side's last piece -- the other side's turn.
static func _step_on(asked: Position) -> void:
	asked.forget_answers()
	if asked.phase == WALK:
		asked.phase = SHOOT
		return
	asked.phase = WALK
	if asked.waiting.is_empty():
		asked.board = asked.board.end_turn(TacticalScenario.FACTIONS)
		for piece: Unit in asked.board.units_of(asked.board.current_faction):
			asked.waiting.append(piece.id)
	asked.unit_id = asked.waiting.pop_front() if not asked.waiting.is_empty() else -1


# Each neighbour of the cell `here` that a walk through it reaches more
# cheaply than any so far, within the last bucket: its cost -- `costs` is
# what entering each cell of `ground` costs -- written into `spent`, and the
# cell put in the bucket for that cost.
static func _relax(ground: GakGridGraph, costs: PackedInt32Array, here: int, spent: PackedInt32Array,
		buckets: Array[PackedInt32Array]) -> void:
	var cell := Vector2i(here % ground.width, here / ground.width)
	for direction: Vector2i in GakGridGraph.DIRECTIONS:
		var next: Vector2i = cell + direction
		var index: int = next.y * ground.width + next.x
		if not ground.contains(next) or costs[index] == GakGridGraph.BLOCKED:
			continue
		var through: int = spent[here] + costs[index]
		if through < buckets.size() and through < spent[index]:
			spent[index] = through
			buckets[through].append(index)


# What entering each cell of `ground` costs, row by row: read once a graph
# and kept across searches and games, by the graph's id -- a board's terrain
# is built before its state and never changed (`BoardState`) -- the last
# `COSTS_KEPT` graphs at most, so a long session does not pile them up.
static func _entry_costs(ground: GakGridGraph) -> PackedInt32Array:
	var key: int = ground.get_instance_id()
	if _costs_by_graph.has(key):
		return _costs_by_graph[key]
	if _costs_by_graph.size() >= COSTS_KEPT:
		_costs_by_graph.clear()
	var costs := PackedInt32Array()
	for index: int in range(ground.width * ground.height):
		costs.append(ground.cost_at(Vector2i(index % ground.width, index / ground.width)))
	_costs_by_graph[key] = costs
	return costs
