# T87: `MctsSquad`, the XCOM-style mode's enemy that searches.
#
# It does not cheat: T85's check (`SquadUnseenCheck`) holds it as it holds
# `WeighedSquad`, with what its side cannot see changed and every decision
# kept -- and catches two planted searchers, one that searches the whole
# board and one that believes the board about the health it cannot see.
# The budget here is small: the check is about what it reads, not how well
# it plays.
#
# It believes as it says: an enemy out of sight where it was last seen, as
# hurt as it was then, moved off a cell its side now sees empty; an enemy
# never seen where the scenario starts it; a destroyed one nowhere. It
# plays the most visited answer, shows every answer, thinks a frame at a
# time to its budget and plays then what it would have played at once, and
# answers a refused walk with another. A seeded game replays to its digest.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE
const POSITIONS: int = 24
## The iterations a decision in these checks: more than a walk question's
## answers (43 at most at the start), so the tree grows past the root and
## the guess is searched below it, and few enough for the suite.
const BUDGET: int = 50
## The shares the planted searchers must be caught on, floors under what
## was measured in wave 125 (searching the whole board 20, believing the
## unseen health 20, of the 24).
const AT_LEAST_ALL: int = 14
const AT_LEAST_HEALTH: int = 14
## The seeded game's digest, as `SquadMatch.play` writes it. Measured in
## wave 125: the weighed enemy, blue, wins in round 11, no walk refused.
const SEEDED_GAME_DIGEST: String = "1b6efb9e0f69314d8a6a902466090a1c73f96a26de1c9ed41635dddc6be231b8"


## A searcher that believes the whole board: the planted case for an AI that
## searches what its side does not see.
class SearchesTheWholeBoard extends MctsSquad:
	func believe(state: BoardState) -> BoardState:
		return state.duplicate_state()


## A searcher that believes as it should, except that every enemy it
## guesses at has the health the whole board gives it.
class BelievesUnseenHealth extends MctsSquad:
	func believe(state: BoardState) -> BoardState:
		var believed: BoardState = super.believe(state)
		for unit: Unit in believed.units:
			var truth: Unit = state.unit_by_id(unit.id)
			if truth != null:
				unit.health = truth.health
		return believed


var _rules := SquadRuleset.new()
var _check: SquadUnseenCheck


func before() -> void:
	_check = SquadUnseenCheck.new(POSITIONS)


func test_changing_what_it_cannot_see_changes_none_of_its_decisions() -> void:
	for index: int in range(POSITIONS):
		var changed: String = _check.first_changed_decision(index, func() -> BlueController: return MctsSquad.new(5, BUDGET))
		if changed != "":
			fail("position %d: %s" % [index, changed])
			return


func test_the_check_catches_a_searcher_that_sees_everything() -> void:
	var make: Callable = func() -> BlueController: return SearchesTheWholeBoard.new(5, BUDGET)
	assert_int(_check.caught(make)).is_greater_equal(AT_LEAST_ALL)


func test_the_check_catches_a_searcher_that_believes_unseen_health() -> void:
	var make: Callable = func() -> BlueController: return BelievesUnseenHealth.new(5, BUDGET)
	assert_int(_check.caught(make)).is_greater_equal(AT_LEAST_HEALTH)


func test_an_enemy_out_of_sight_is_believed_where_last_seen_as_hurt_as_it_was() -> void:
	var seen: BoardState = _rules.start()
	_put(seen, 1, Vector2i(5, 4))
	_put(seen, 5, Vector2i(7, 4)).health = 5
	var searcher := MctsSquad.new(1, BUDGET)
	searcher.begin_turn(seen)
	assert_object(searcher.believe(seen).unit_by_id(5).cell).is_equal(Vector2i(7, 4))
	var gone: BoardState = seen.duplicate_state()
	_put(gone, 5, Vector2i(12, 6)).health = 2
	var believed: BoardState = searcher.believe(gone)
	var guess: Unit = believed.unit_by_id(5)
	assert_int(guess.health).is_equal(5)
	# Its side sees (7, 4) empty now, so it stands on a cell unseen.
	assert_bool(SideView.is_seen(gone, SquadScenario.rows(), RED, guess.cell)).is_false()
	assert_object(guess.cell).is_not_equal(Vector2i(7, 4))
	# With the runner back out of sight of (7, 4), it stands there again.
	var away: BoardState = gone.duplicate_state()
	_put(away, 1, Vector2i(1, 2))
	assert_object(searcher.believe(away).unit_by_id(5).cell).is_equal(Vector2i(7, 4))
	for enemy_id: int in [6, 7, 8]:
		assert_object(believed.unit_by_id(enemy_id).cell).is_equal(_rules.start().unit_by_id(enemy_id).cell)


func test_an_enemy_destroyed_in_sight_is_not_believed_in() -> void:
	var seen: BoardState = _rules.start()
	_put(seen, 1, Vector2i(5, 4))
	_put(seen, 5, Vector2i(7, 4))
	var searcher := MctsSquad.new(1, BUDGET)
	searcher.begin_turn(seen)
	searcher.believe(seen)
	var destroyed: BoardState = seen.duplicate_state()
	destroyed.unit_by_id(5).health = 0
	assert_object(searcher.believe(destroyed.duplicate_state()).unit_by_id(5)).is_null()


func test_it_plays_the_most_visited_answer_and_shows_every_answer() -> void:
	var searcher := MctsSquad.new(2, 60)
	var state: BoardState = _rules.start()
	var decision: TacticalDecision = searcher.decide_move(state, 1)
	var shown: Array[Dictionary] = searcher.weighed()
	assert_int(shown.size()).is_equal(SquadSearchGame.answers(state, 1, SquadSearchGame.WALK).size())
	var chosen: Array = shown.filter(func(option: Dictionary) -> bool: return option["chosen"])
	assert_int(chosen.size()).is_equal(1)
	assert_object(chosen[0]["cell"]).is_equal(decision.target)
	for option: Dictionary in shown:
		assert_int(option["visits"]).is_less_equal(chosen[0]["visits"])
	var lines: Array[String] = searcher.search_lines()
	assert_str(lines[0]).contains("60 of 60")
	assert_bool(lines.any(func(line: String) -> bool: return line.contains("█"))).is_true()


func test_a_frame_at_a_time_it_thinks_to_its_budget_and_plays_what_it_would_at_once() -> void:
	var at_once: TacticalDecision = MctsSquad.new(3, 40).decide_move(_rules.start(), 1)
	var spread := MctsSquad.new(3, 40)
	spread.spread_over_frames()
	var decision: TacticalDecision = spread.decide_move(_rules.start(), 1)
	var per_frame: int = int(MctsSquad.search_rules()["iterations_per_frame"])
	assert_str(spread.search_lines()[0]).contains("%d of 40" % per_frame)
	var frames: int = 0
	while spread.keep_thinking():
		frames += 1
	assert_int(frames).is_equal(ceili((40.0 - per_frame) / per_frame))
	assert_str(spread.search_lines()[0]).contains("40 of 40")
	assert_object(decision.target).is_equal(at_once.target)
	assert_str(decision.kind()).is_equal(at_once.kind())


func test_with_nobody_to_shoot_it_is_not_asked_to() -> void:
	assert_object(MctsSquad.new(1, BUDGET).decide_attack(_rules.start(), 1)).is_null()


func test_a_refused_walk_is_answered_with_another_round_its_route_or_a_hold() -> void:
	var searcher := MctsSquad.new(4, 60)
	var state: BoardState = _rules.start()
	searcher.decide_move(state, 1)
	# The walk the board refused: the runner two cells east, through (2, 2).
	var refused_path: Array[Vector2i] = TacticalReach.walks_for(state, state.unit_by_id(1))[Vector2i(3, 2)]
	var refused := TacticalDecision.walk(1, refused_path, [], Vector2i(3, 2))
	var instead: TacticalDecision = searcher.after_refusal(state, refused)
	assert_object(instead).is_not_null()
	assert_int(instead.unit_id).is_equal(1)
	assert_object(instead.target).is_not_equal(Vector2i(3, 2))
	if instead.move != null:
		for step: Vector2i in instead.move.path:
			assert_bool(step in refused_path).is_false()


func test_a_seeded_game_against_the_weighed_enemy_replays_to_its_digest() -> void:
	var played: Dictionary = SquadMatch.play(MctsSquad.new(1, BUDGET), WeighedSquad.new(), 11)
	assert_str(SquadMatch.play(MctsSquad.new(1, BUDGET), WeighedSquad.new(), 11)["digest"]).is_equal(played["digest"])
	assert_str(played["digest"]).is_equal(SEEDED_GAME_DIGEST)


# The piece `unit_id` on `state` moved to `cell`: the piece, to change more.
func _put(state: BoardState, unit_id: int, cell: Vector2i) -> Unit:
	var unit: Unit = state.unit_by_id(unit_id)
	unit.cell = cell
	return unit
