# T84's property check: 300 seeded positions on the tactical map, each
# reached by seeded random legal actions from the start, and at each one --
#
# - every legal action leaves a legal state: every piece alive, on its own
#   ground, alone on its cell, with movement between none and two actions,
#   and the same side to move;
# - no listed shot names an enemy outside its side's view;
# - a shot or a dash spends the piece: after any action, a piece has either
#   a whole action left or nothing;
# - no side's view holds an enemy it cannot see, and it holds every enemy
#   it can.
#
# And a seeded game, the random squad against itself through `BlueTurn` as
# the scene plays it, replays to the digest written below. A change to the
# rules that moves a single die moves the digest; that is the point of it,
# and the digest is then written again, in the same commit, on purpose.
extends GdUnitTestSuite

const POSITIONS: int = 300
const MOST_ACTIONS_BEFORE: int = 40
## The seeded game's digest: sha256 of every turn's pieces, as `_game_digest`
## writes them. Measured in wave 113: forty turns to the round limit, a piece
## lost on each side, blue winning on health 25 to 19.
const SEEDED_GAME_DIGEST: String = "d68ad8bafa69c86c65d32d9166ed65ba2dd53209024a1757233daeffb0b6a8f2"

var _rules := SquadRuleset.new()
# The positions, reached once for the whole suite: reaching them is most of
# what the checks cost.
var _positions: Array[BoardState] = []


func before() -> void:
	for seed_number: int in range(POSITIONS):
		_positions.append(_position(seed_number))


func test_every_legal_action_leaves_a_legal_state_and_spends_what_it_should() -> void:
	for seed_number: int in range(POSITIONS):
		var broken: String = _first_broken_action(_positions[seed_number])
		if broken != "":
			fail("position %d, %s" % [seed_number, broken])
			return


func test_no_view_holds_an_enemy_it_cannot_see_nor_misses_one_it_can() -> void:
	var rows: Array[String] = SquadScenario.rows()
	for index: int in range(POSITIONS * TacticalScenario.FACTIONS):
		var side: int = index % TacticalScenario.FACTIONS
		var wrong: int = _misseen_enemy(_positions[index / TacticalScenario.FACTIONS], rows, side)
		if wrong != -1:
			fail("position %d: side %d's view and its sight disagree about unit %d" % [index / TacticalScenario.FACTIONS, side, wrong])
			return


func test_the_positions_are_not_all_the_start() -> void:
	var shots: int = 0
	var moved: int = 0
	for seed_number: int in range(0, POSITIONS, 10):
		var state: BoardState = _positions[seed_number]
		moved += 1 if JSON.stringify(_pieces(state)) != JSON.stringify(_pieces(_rules.start())) else 0
		for action: Object in _rules.actions(state):
			shots += 1 if action is Attack else 0
	assert_int(moved).is_greater(POSITIONS / 20)
	assert_int(shots).is_greater(0)


func test_a_seeded_game_replays_to_its_digest() -> void:
	var digest: String = _game_digest(11)
	assert_str(_game_digest(11)).is_equal(digest)
	assert_str(digest).is_equal(SEEDED_GAME_DIGEST)


# The position seed `seed_number` reaches: up to `MOST_ACTIONS_BEFORE`
# random legal actions from the start, a turn passing now and then.
func _position(seed_number: int) -> BoardState:
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_number
	var state: BoardState = _rules.start()
	state.dice_seed = seed_number
	for _step: int in range(dice.randi_range(0, MOST_ACTIONS_BEFORE)):
		if _rules.winner(state) != TacticalVictory.NOBODY:
			break
		var actions: Array = _rules.actions(state)
		if actions.is_empty() or dice.randi_range(0, 5) == 0:
			state = _rules.open_turn(state)[0]
		else:
			state = _rules.play(state, actions[dice.randi_range(0, actions.size() - 1)])
	return state


# The first of `state`'s legal actions that leaves an illegal state, or a
# shot that leaves its shooter movement, said with why; "" for none.
func _first_broken_action(state: BoardState) -> String:
	for action: Object in _rules.actions(state):
		var after: BoardState = _rules.play(state, action)
		var broken: String = _why_illegal(after, state.current_faction)
		if broken == "" and action is Attack:
			broken = _why_shot_wrong(state, after, action as Attack)
		if broken != "":
			return "%s: %s" % [_named(action), broken]
	return ""


# Why a listed shot is wrong, or "": one at an enemy its side's view does
# not hold (wave 113's review: a mortar reached what it could not see), or
# one that left its shooter movement.
func _why_shot_wrong(before: BoardState, after: BoardState, strike: Attack) -> String:
	if not strike.target_id in _rules.view(before, before.current_faction).seen_enemies():
		return "the shot names an enemy its side's view does not hold"
	var shooter: Unit = after.unit_by_id(strike.attacker_id)
	return "the shot left its shooter movement" if shooter != null and shooter.movement_points != 0 else ""


# The id of an enemy that `side`'s view and its sight disagree about -- held
# though unseen, or seen and not held -- or -1.
func _misseen_enemy(state: BoardState, rows: Array[String], side: int) -> int:
	var held: Array[int] = _rules.view(state, side).seen_enemies()
	for enemy: Unit in state.units_of(TacticalScenario.FACTIONS - 1 - side):
		if SideView.is_seen(state, rows, side, enemy.cell) != (enemy.id in held):
			return enemy.id
	return -1


# Why `state` is not one a legal action can leave, or "".
func _why_illegal(state: BoardState, to_move: int) -> String:
	if state == null:
		return "a listed action was refused"
	if state.current_faction != to_move:
		return "the side to move changed"
	var taken: Dictionary = {}
	for unit: Unit in state.units:
		if taken.has(unit.cell):
			return "two pieces on %s" % unit.cell
		taken[unit.cell] = true
		if state.graph_for(unit).is_blocked(unit.cell):
			return "unit %d stands on ground it cannot" % unit.id
		var action: int = SquadTable.action(unit.type.type_name)
		if unit.movement_points != 0 and (unit.movement_points < action or unit.movement_points > 2 * action):
			return "unit %d has %d movement, neither nothing nor a whole action" % [unit.id, unit.movement_points]
	return ""


# A whole game, the random squad on both sides through `BlueTurn` and the
# ruleset, as the scene plays it; the digest of every turn's pieces.
func _game_digest(seed_number: int) -> String:
	var turns: Array[BlueTurn] = [BlueTurn.new(RandomSquad.new(seed_number), _rules),
		BlueTurn.new(RandomSquad.new(seed_number + 1), _rules)]
	var state: BoardState = _rules.start()
	state.dice_seed = seed_number
	var written: Array = []
	while _rules.winner(state) == TacticalVictory.NOBODY:
		var turn: BlueTurn = turns[state.current_faction]
		turn.begin(state)
		while not turn.finished():
			state = turn.play(state)
		written.append(_pieces(state))
		state = _rules.open_turn(state)[0]
	written.append(_rules.winner(state))
	return JSON.stringify(written).sha256_text()


func _pieces(state: BoardState) -> Array:
	var found: Array = []
	for unit: Unit in state.units:
		found.append([unit.id, unit.cell.x, unit.cell.y, unit.health, unit.movement_points])
	return found


func _named(action: Object) -> String:
	if action is Move:
		return "unit %d walks %s" % [(action as Move).unit_id, (action as Move).path]
	return "unit %d shoots unit %d" % [(action as Attack).attacker_id, (action as Attack).target_id]
