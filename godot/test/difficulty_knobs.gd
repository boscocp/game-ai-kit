# T12's never-cheat check, and it is an allowlist: a list of forbidden names
# misses a cheat that is simply renamed, and a list of what is allowed does
# not.
#
#     ./scripts/godot --headless --path godot -s res://test/difficulty_knobs.gd
#
# What it holds, for every preset:
#
# 1. **The level sets the documented knobs and nothing else.** Every field the
#    level's script declares is `name` or one of `KNOBS` -- the list written
#    here, not read from the file it audits: a cheat added to
#    `Difficulty.KNOBS` beside its field would otherwise allow itself. The
#    ladder is the three levels `LEVELS` names, and an empty one fails. And
#    `LeveledBlue` reads a level's name only to say it: a level that played
#    differently because it is called "hard" would be a fourth knob.
# 2. **The same resources.** The level is handed the board and answers it;
#    it never changes it. Every question it is asked in a game is asked on a
#    board whose pieces, health, funds, upgrades, point-turns and dice are
#    compared before and after the answer -- a level that paid itself, healed
#    a piece or rerolled the dice would show.
# 3. **The same vision.** What it decides does not depend on the board's next
#    roll: the same board with the dice seeded five ways gets the same
#    answers -- what the workshop builds, where each walker walks, and whom it
#    then attacks, which is when the board's seed is the very fight's.
#    Nothing else on the board is hidden from the person -- the tactical
#    board has no fog -- so the dice are what a level could see that the
#    person cannot.
# 4. **The same command interface.** Every decision it makes is played by
#    `BlueTurn`, through the board's own judgement -- the one a person's
#    click gets -- and over a game none is refused.
#
# Each check is first run on a planted cheat it must refuse: a level with an
# `extra_vision` field, one that pays itself, one that peeks at the dice, and
# one that plays each fight on a copy of the board before choosing it.
# A check that passes its planted cheat is reported, and fails the run.
#
# Exit codes: 0 every preset passes and every planted cheat is caught, 1
# otherwise.
extends SceneTree

const GAMES: int = 2
## The knobs T12 documents, written here and compared with `Difficulty.KNOBS`.
const KNOBS: Array[String] = ["plan_horizon", "search_depth", "evaluation_noise"]
## The ladder, weakest first.
const LEVELS: Array[String] = ["easy", "normal", "hard"]
## The board's dice for check 3.
const DICE: Array[int] = [2, 3, 5, 7, 11]


## A level with one field more than the allowlist: check 1's planted case.
class _SeeingFurther extends Difficulty:
	var extra_vision: int = 2


## A level that pays itself at the start of each turn: check 2's.
class _PayingItself extends LeveledBlue:
	## The level's start of turn, and five funds it was never paid.
	func begin_turn(state: BoardState) -> void:
		super.begin_turn(state)
		state.funds[state.current_faction] = state.funds_of(state.current_faction) + 5


## A level that holds when the next roll is even: check 3's.
class _PeekingAtTheDice extends LeveledBlue:
	## The level's walk -- unless the board's next roll is even.
	func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
		if state.dice_seed % 2 == 0:
			return TacticalDecision.hold(unit_id, "the next roll is even", state.unit_by_id(unit_id).cell)
		return super.decide_move(state, unit_id)


## A level that plays each fight on a copy of the board first, and attacks
## only when the copy says it wins: check 3's second, the cheat a lookahead
## falls into.
class _PlayingTheFightFirst extends LeveledBlue:
	## The level's attack, if the board's own dice say it wins.
	func decide_attack(state: BoardState, unit_id: int) -> TacticalDecision:
		var decision: TacticalDecision = super.decide_attack(state, unit_id)
		if decision == null:
			return null
		var after: BoardState = TacticalCombat.apply(state, decision.attack)
		return decision if after != null and after.unit_by_id(unit_id) != null else null


## A controller that compares the board before and after every answer of
## another, and keeps what changed.
class _Watching extends BlueController:
	var inner: BlueController
	var changed: Array[String] = []

	func _init(watched: BlueController) -> void:
		inner = watched

	## The inner start of turn, watched.
	func begin_turn(state: BoardState) -> void:
		var before: String = fingerprint(state)
		inner.begin_turn(state)
		_compare(before, state, "begin_turn")

	## The inner name.
	func controller_name() -> String:
		return inner.controller_name()

	## The inner line.
	func describe() -> String:
		return inner.describe()

	## The inner build, watched.
	func decide_build(state: BoardState, workshop_id: int) -> TacticalDecision:
		var before: String = fingerprint(state)
		var decision: TacticalDecision = inner.decide_build(state, workshop_id)
		_compare(before, state, "decide_build")
		return decision

	## The inner walk, watched.
	func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
		var before: String = fingerprint(state)
		var decision: TacticalDecision = inner.decide_move(state, unit_id)
		_compare(before, state, "decide_move")
		return decision

	## The inner attack, watched.
	func decide_attack(state: BoardState, unit_id: int) -> TacticalDecision:
		var before: String = fingerprint(state)
		var decision: TacticalDecision = inner.decide_attack(state, unit_id)
		_compare(before, state, "decide_attack")
		return decision

	func _compare(before: String, state: BoardState, asked: String) -> void:
		if fingerprint(state) != before and changed.size() < 3:
			changed.append("%s changed the board on turn %d" % [asked, state.turn_number])

	## Everything on the board a level could give itself: every piece, its
	## health and movement, and its type's reach, speed and price; both sides'
	## funds and upgrades; the point-turns that count at the round limit; the
	## dice; and the rules a fight is rolled by.
	static func fingerprint(state: BoardState) -> String:
		var pieces: Array[String] = []
		for unit: Unit in state.units:
			pieces.append("%d:%d:%s:%d:%d:%s:%d:%d:%d" % [unit.id, unit.faction, unit.cell, unit.health, unit.movement_points,
				unit.type.type_name, unit.type.movement, unit.type.attack_range, unit.type.cost])
		return "%s %s %s %s %d %d %d" % [" ".join(pieces), state.funds, state.upgrades, state.tally, state.dice_seed,
			state.turn_number, TacticalCombat.rules().hash()]


func _init() -> void:
	quit(_run())


func _run() -> int:
	var failures: int = 0
	failures += _planted("a level with an extra_vision field", _field_problems(_SeeingFurther.new("seeing", 0, 1, 0.0)))
	failures += _planted("a level that pays itself", _resource_problems(_PayingItself.new(Difficulty.named("hard"), 1)))
	failures += _planted("a level that peeks at the dice", _vision_problems(_PeekingAtTheDice.new(Difficulty.named("hard"), 1), Difficulty.named("hard")))
	failures += _planted("a level that plays the fight first", _vision_problems(_PlayingTheFightFirst.new(Difficulty.named("hard"), 1), Difficulty.named("hard")))
	failures += _planted("a ladder with no levels", _ladder_problems([]))
	var ladder: Array[String] = _ladder_problems(Difficulty.presets())
	print("%s: the ladder is %s, with the knobs %s%s" % ["ok" if ladder.is_empty() else "FAIL", ", ".join(LEVELS), ", ".join(KNOBS),
		"" if ladder.is_empty() else " -- " + "; ".join(ladder)])
	failures += 0 if ladder.is_empty() else 1
	for level: Difficulty in Difficulty.presets():
		var problems: Array[String] = _field_problems(level)
		problems.append_array(_resource_problems(LeveledBlue.new(level, 1)))
		problems.append_array(_vision_problems(LeveledBlue.new(level, 1), level))
		print("%s: %s -- %s" % ["ok" if problems.is_empty() else "FAIL", level.describe(),
			"the documented knobs, the same board, the same dice, the same orders" if problems.is_empty() else "; ".join(problems)])
		failures += 0 if problems.is_empty() else 1
	print("difficulty knobs: %d failure(s)" % failures)
	return 1 if failures > 0 else 0


# 0 when a planted cheat was caught -- said so -- and 1 when it passed.
static func _planted(what: String, problems: Array[String]) -> int:
	print("%s: planted, %s -- %s" % ["ok" if not problems.is_empty() else "FAIL", what,
		"caught: " + problems[0] if not problems.is_empty() else "not caught"])
	return 0 if not problems.is_empty() else 1


# Check 1, the ladder: the documented knobs, the documented levels, and a
# level's name read only where `LeveledBlue` says it.
static func _ladder_problems(levels: Array[Difficulty]) -> Array[String]:
	var problems: Array[String] = []
	if Difficulty.KNOBS != KNOBS:
		problems.append("Difficulty.KNOBS is %s, and T12 documents %s" % [Difficulty.KNOBS, KNOBS])
	var names: Array[String] = []
	for level: Difficulty in levels:
		names.append(level.name)
	if names != LEVELS:
		problems.append("the levels are %s, not %s" % [names, LEVELS])
	var code: String = FileAccess.get_file_as_string("res://game/tactical/leveled_blue.gd")
	var reads: int = 0
	for line: String in code.split("\n"):
		reads += line.split("#")[0].count("level.name")
	if reads != 1:
		problems.append("leveled_blue.gd reads level.name %d times; once, to say it, is allowed" % reads)
	return problems


# Check 1: every field the level's script declares, against the allowlist.
static func _field_problems(level: Difficulty) -> Array[String]:
	var allowed: Array[String] = ["name"]
	allowed.append_array(KNOBS)
	var problems: Array[String] = []
	for property: Dictionary in level.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and not property["name"] in allowed:
			problems.append("sets %s, which is not a knob" % property["name"])
	return problems


# Checks 2 and 4: `GAMES` games against the rules from each seat, the board
# compared around every answer, and no decision refused.
static func _resource_problems(controller: LeveledBlue) -> Array[String]:
	var problems: Array[String] = []
	for game: int in range(GAMES):
		var watched := _Watching.new(controller)
		var seat: int = game % TacticalScenario.FACTIONS
		var seats: Array[BlueController] = [RuleBasedBlue.new(), RuleBasedBlue.new()]
		seats[seat] = watched
		var result: Dictionary = TacticalMatch.play(seats[0], seats[1], game)
		problems.append_array(watched.changed)
		for refused: TacticalDecision in result["refused"]:
			problems.append("the board refused %s" % refused.reason)
	return problems


# Check 3: on boards from a game, the same answers with the dice seeded each
# of `DICE` ways. A fresh controller each time, with the same seed, so its
# own noise is the same.
static func _vision_problems(controller: LeveledBlue, level: Difficulty) -> Array[String]:
	var boards: Array[BoardState] = []
	TacticalMatch.play(RuleBasedBlue.new(), RuleBasedBlue.new(), 4, func(state: BoardState) -> void:
		if state.turn_number in [6, 15, 24, 31]:
			boards.append(state.duplicate_state()))
	var fresh: Callable = func() -> LeveledBlue: return controller.get_script().new(level, 1)
	for board: BoardState in boards:
		if not _the_same_whatever_the_dice(fresh, board):
			return ["decides differently when only the next roll differs, on turn %d" % board.turn_number]
	return []


# True when a fresh controller from `fresh` answers the same on `board` with
# the dice seeded each of `DICE` ways.
static func _the_same_whatever_the_dice(fresh: Callable, board: BoardState) -> bool:
	var first: Array[String] = _answers(fresh.call(), board, DICE[0])
	for dice_seed: int in DICE.slice(1):
		if _answers(fresh.call(), board, dice_seed) != first:
			return false
	return true


# Everything `controller` decides for the side to move on `board` with the
# dice seeded `dice_seed`: the build, then each walk -- played, on a board
# whose dice are put back to `dice_seed` -- and the attack asked after it.
static func _answers(controller: LeveledBlue, board: BoardState, dice_seed: int) -> Array[String]:
	var seeded: BoardState = board.duplicate_state()
	seeded.dice_seed = dice_seed
	controller.begin_turn(seeded)
	var said: Array[String] = []
	for unit: Unit in seeded.units_of(seeded.current_faction):
		if not unit.type.produces.is_empty():
			said.append(controller.decide_build(seeded, unit.id).reason)
	for unit: Unit in seeded.units_of(seeded.current_faction):
		if unit.type.mobile:
			said.append_array(_walk_and_attack(controller, seeded, unit.id, dice_seed))
	return said


# One walker's walk and the attack after it, as words.
static func _walk_and_attack(controller: LeveledBlue, board: BoardState, unit_id: int, dice_seed: int) -> Array[String]:
	var walk: TacticalDecision = controller.decide_move(board, unit_id)
	var walked: BoardState = walk.played_on(board)
	if walked == null:
		return [walk.reason, "refused"]
	walked.dice_seed = dice_seed
	var attack: TacticalDecision = controller.decide_attack(walked, unit_id)
	return [walk.reason, attack.reason if attack != null else "no attack"]
