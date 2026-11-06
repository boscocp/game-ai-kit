# T88: `ExpectiSquad`, the XCOM-style mode's enemy that works out the odds,
# and the hand-written evaluation it cuts off on.
#
# The squad's gate on expectiminimax: on each of the 30 positions of
# `spec/squad/duel.json`, every answer's expected value at the file's depth
# is the file's, within 1e-9 -- Python's `test_squad_duel.py` reads the
# same file -- and a planted game that sees no dice misses most of the shot
# positions.
#
# It does not cheat: T85's check (`SquadUnseenCheck`) holds it as it holds
# the other two, and catches two planted searchers. It plays the answer
# worth most, shows every answer with its expected value and a shot's two
# branches, thinks a frame at a time to the answer it would give at once,
# answers a refused walk with another, and a seeded game replays to its
# digest.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const POSITIONS: int = 24
## The positions a decision in these checks: past depth 1 of a walk
## question (43 answers at most at the start) and into depth 2, so the
## guess is searched below the root; few enough for the suite.
const BUDGET: int = 200
## The shares the planted searchers must be caught on, floors under what
## was measured in wave 136 (searching the whole board 20, believing the
## unseen health 20, of the 24) -- the same floors as `MctsSquad`'s.
const AT_LEAST_ALL: int = 14
const AT_LEAST_HEALTH: int = 14
## The seeded game's digest, as `SquadMatch.play` writes it. Measured in
## wave 136: the weighed enemy, blue, wins in round 9, no walk refused.
const SEEDED_GAME_DIGEST: String = "b03b3f45a9da070a944322f78d43cc5737205d3fbc583511746dc62a40f23700"
const TOLERANCE: float = 1e-9


## A searcher that believes the whole board.
class SearchesTheWholeBoard extends ExpectiSquad:
	func believe(state: BoardState) -> BoardState:
		return state.duplicate_state()


## A searcher that believes as it should, except that every enemy it
## guesses at has the health the whole board gives it.
class BelievesUnseenHealth extends ExpectiSquad:
	func believe(state: BoardState) -> BoardState:
		var believed: BoardState = super.believe(state)
		for unit: Unit in believed.units:
			var truth: Unit = state.unit_by_id(unit.id)
			if truth != null:
				unit.health = truth.health
		return believed


## A searcher asked on a board it believes won: the state T87's crash came
## from, built on purpose. In play it came from a turn that went on asking
## after its shot ended the game (T134, `squad_game_over_test.gd`).
class BelievesNoEnemy extends ExpectiSquad:
	func believe(state: BoardState) -> BoardState:
		var believed: BoardState = super.believe(state)
		believed.units.assign(believed.units.filter(func(unit: Unit) -> bool: return unit.faction == state.current_faction))
		return believed


## The same belief in the enemy that samples, whose `_chosen` crashed on it.
class SamplesNoEnemy extends MctsSquad:
	func believe(state: BoardState) -> BoardState:
		var believed: BoardState = super.believe(state)
		believed.units.assign(believed.units.filter(func(unit: Unit) -> bool: return unit.faction == state.current_faction))
		return believed


## The planted game: every shot is its likelier outcome, certain -- what a
## search with no dice sees.
class NoDice extends SquadEvaluatedGame:
	func outcomes(position: RefCounted, action: Variant) -> Array:
		var possible: Array = super.outcomes(position, action)
		var likelier: Dictionary = possible[0]
		for outcome: Dictionary in possible:
			if outcome["probability"] > likelier["probability"]:
				likelier = outcome
		return [{"probability": 1.0, "state": likelier["state"]}]


var _rules := SquadRuleset.new()
var _check: SquadUnseenCheck


func before() -> void:
	_check = SquadUnseenCheck.new(POSITIONS)


func test_every_duel_position_has_the_files_expected_values() -> void:
	var duel: Dictionary = _duel()
	assert_int(duel["positions"].size()).is_equal(30)
	for position: Dictionary in duel["positions"]:
		var wrong: String = _differs(position, SquadEvaluatedGame.new())
		if wrong != "":
			fail(wrong)
			return


func test_a_search_that_sees_no_dice_misses_most_shot_positions() -> void:
	var shots: Array = _duel()["positions"].filter(func(position: Dictionary) -> bool: return position["phase"] == "shoot")
	var missed: int = 0
	for position: Dictionary in shots:
		if _differs(position, NoDice.new()) != "":
			missed += 1
	assert_int(missed).is_greater(shots.size() / 2)


func test_the_evaluation_is_within_one_below_a_win_and_the_same_from_either_side() -> void:
	var game := SquadEvaluatedGame.new()
	var summed: float = 0.0
	for weight: Variant in SquadTable.rules()["evaluation"].values():
		summed += float(weight)
	assert_float(summed).is_equal_approx(1.0, 1e-12)
	for position: Dictionary in _duel()["positions"]:
		var root: SquadSearchGame.Position = SquadDuel.root(position)
		_assert_within_one(game, root, TacticalScenario.RED)
		_assert_within_one(game, root, TacticalScenario.BLUE)
		assert_float(game.evaluate(root, 0)).is_equal_approx(-game.evaluate(root, 1), 1e-12)


func test_changing_what_it_cannot_see_changes_none_of_its_decisions() -> void:
	for index: int in range(POSITIONS):
		var changed: String = _check.first_changed_decision(index, func() -> BlueController: return ExpectiSquad.new(5, BUDGET))
		if changed != "":
			fail("position %d: %s" % [index, changed])
			return


func test_the_check_catches_a_searcher_that_sees_everything() -> void:
	var make: Callable = func() -> BlueController: return SearchesTheWholeBoard.new(5, BUDGET)
	assert_int(_check.caught(make)).is_greater_equal(AT_LEAST_ALL)


func test_the_check_catches_a_searcher_that_believes_unseen_health() -> void:
	var make: Callable = func() -> BlueController: return BelievesUnseenHealth.new(5, BUDGET)
	assert_int(_check.caught(make)).is_greater_equal(AT_LEAST_HEALTH)


func test_it_plays_the_answer_worth_most_and_shows_every_answer() -> void:
	var searcher := ExpectiSquad.new(2, BUDGET)
	var state: BoardState = _rules.start()
	var decision: TacticalDecision = searcher.decide_move(state, 1)
	var shown: Array[Dictionary] = searcher.weighed()
	assert_int(shown.size()).is_equal(SquadSearchGame.answers(state, 1, SquadSearchGame.WALK).size())
	var chosen: Array = shown.filter(func(option: Dictionary) -> bool: return option["chosen"])
	assert_int(chosen.size()).is_equal(1)
	assert_object(chosen[0]["cell"]).is_equal(decision.target)
	for option: Dictionary in shown:
		assert_float(option["score"]).is_less_equal(chosen[0]["score"])
	var lines: Array[String] = searcher.search_lines()
	assert_str(lines[0]).contains("searched to depth 1, depth 2 under way")
	assert_str(lines[0]).contains("200 positions of 200")
	assert_bool(lines.any(func(line: String) -> bool: return line.contains("█"))).is_true()


func test_a_shot_shows_its_hit_and_its_miss() -> void:
	var position: Dictionary = _duel()["positions"].filter(func(entry: Dictionary) -> bool: return entry["about"] == "flank")[0]
	var board: BoardState = SquadDuel.board_of(position)
	var searcher := ExpectiSquad.new(2, BUDGET)
	searcher.begin_turn(board)
	assert_object(searcher.decide_attack(board, int(position["acting"]))).is_not_null()
	var shot_lines: Array = searcher.search_lines().filter(func(line: String) -> bool: return line.contains("shoots"))
	assert_bool(shot_lines.is_empty()).is_false()
	assert_str(shot_lines[0]).contains("hit ")
	assert_str(shot_lines[0]).contains("miss ")


func test_before_depth_one_is_finished_it_holds_and_says_so() -> void:
	var spread := ExpectiSquad.new(3, BUDGET)
	spread.spread_over_frames()
	var decision: TacticalDecision = spread.decide_move(_rules.start(), 1)
	assert_object(decision.move).is_null()
	assert_str(TacticalStatus.said(decision.reason)).contains("not finished depth 1")


func test_a_frame_at_a_time_it_thinks_to_its_budget_and_plays_what_it_would_at_once() -> void:
	var at_once: TacticalDecision = ExpectiSquad.new(3, BUDGET).decide_move(_rules.start(), 1)
	var spread := ExpectiSquad.new(3, BUDGET)
	spread.spread_over_frames()
	var decision: TacticalDecision = spread.decide_move(_rules.start(), 1)
	var per_frame: int = int(ExpectiSquad.search_rules()["positions_per_frame"])
	var frames: int = 0
	while spread.keep_thinking():
		frames += 1
	assert_int(frames).is_equal(ceili(float(BUDGET - per_frame) / per_frame))
	assert_str(spread.search_lines()[0]).contains("%d positions of %d" % [BUDGET, BUDGET])
	assert_object(decision.target).is_equal(at_once.target)
	assert_str(decision.kind()).is_equal(at_once.kind())


func test_a_refused_walk_is_answered_with_another_round_its_route_or_a_hold() -> void:
	var searcher := ExpectiSquad.new(4, BUDGET)
	var state: BoardState = _rules.start()
	searcher.decide_move(state, 1)
	var refused_path: Array[Vector2i] = TacticalReach.walks_for(state, state.unit_by_id(1))[Vector2i(3, 2)]
	var refused := TacticalDecision.walk(1, refused_path, [], Vector2i(3, 2))
	var instead: TacticalDecision = searcher.after_refusal(state, refused)
	assert_object(instead).is_not_null()
	assert_int(instead.unit_id).is_equal(1)
	assert_object(instead.target).is_not_equal(Vector2i(3, 2))
	if instead.move != null:
		for step: Vector2i in instead.move.path:
			assert_bool(step in refused_path).is_false()


func test_on_the_clock_it_counts_what_it_searched_never_below_zero() -> void:
	var timed := ExpectiSquad.new(1)
	timed.think_for(20)
	timed.decide_move(_rules.start(), 1)
	var line: String = timed.search_lines()[0]
	assert_str(line).contains("of ∞")
	assert_bool(line.contains("-")).is_false()


func test_a_belief_with_no_enemy_left_holds_and_says_so() -> void:
	for searcher: SearchingSquad in [BelievesNoEnemy.new(1, BUDGET), SamplesNoEnemy.new(1, 40)]:
		var decision: TacticalDecision = searcher.decide_move(_rules.start(), 1)
		assert_object(decision.move).is_null()
		assert_object(decision.attack).is_null()
		assert_str(TacticalStatus.said(decision.reason)).contains("believes no enemy is left")
		assert_array(searcher.weighed()).is_empty()
		assert_int(searcher.work_done()).is_equal(0)


func test_a_seeded_game_against_the_weighed_enemy_replays_to_its_digest() -> void:
	var played: Dictionary = SquadMatch.play(ExpectiSquad.new(1, BUDGET), WeighedSquad.new(), 11)
	assert_str(SquadMatch.play(ExpectiSquad.new(1, BUDGET), WeighedSquad.new(), 11)["digest"]).is_equal(played["digest"])
	assert_str(played["digest"]).is_equal(SEEDED_GAME_DIGEST)


# Every term of `side`'s evaluation of `root` within [-1, 1], and the score
# short of a win.
func _assert_within_one(game: SquadEvaluatedGame, root: SquadSearchGame.Position, side: int) -> void:
	for term: float in SquadEvaluatedGame.terms_for(root.board, side).values():
		assert_float(absf(term)).is_less_equal(1.0)
	assert_float(absf(game.evaluate(root, side))).is_less(1.0)


# "" when expectiminimax on `game` gives `position` the file's expected
# values at the file's depth, and the file's decision; otherwise the first
# difference.
func _differs(position: Dictionary, game: SquadEvaluatedGame) -> String:
	var wanted: Dictionary = position["expected"]
	var found: AdversarialResult = ExpectiminimaxSearch.new(game, SquadDuel.root(position)).search_to(int(wanted["depth"]))
	if found.considered.size() != (wanted["values"] as Array).size():
		return "%s: %d answers, the file has %d" % [position["name"], found.considered.size(), wanted["values"].size()]
	for index: int in range(found.considered.size()):
		var answer: String = SquadSearchGame.described(found.considered[index]["action"])
		var value: float = found.considered[index]["value"]
		if answer != wanted["values"][index][0] or absf(value - float(wanted["values"][index][1])) > TOLERANCE:
			return "%s: answer %d is %s at %f, the file has %s" % [position["name"], index, answer, value, wanted["values"][index]]
	if SquadSearchGame.described(found.action) != wanted["decision"]:
		return "%s: decided %s, the file has %s" % [position["name"], SquadSearchGame.described(found.action), wanted["decision"]]
	return ""


func _duel() -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://").path_join("../spec/squad/duel.json")
	return JSON.parse_string(FileAccess.get_file_as_string(path))
