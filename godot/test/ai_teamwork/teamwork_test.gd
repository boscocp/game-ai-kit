# ai_teamwork's promises over many random queries, and the vector checker's
# refusals. The vectors pin answers on stated queries; these hold what must
# be true of every answer.
extends GdUnitTestSuite

const TRIALS: int = 200


func _random_candidates(random: RandomNumberGenerator, count: int) -> Array[TacticalPositions.Candidate]:
	var candidates: Array[TacticalPositions.Candidate] = []
	for index: int in range(count):
		var candidate := TacticalPositions.Candidate.new()
		candidate.id = "c%d" % index
		candidate.travel = random.randf_range(0.0, 25.0)
		candidate.threat_distance = random.randf_range(2.0, 40.0)
		candidate.covered_from_main = random.randf() < 0.5
		candidate.fires_on_main = random.randf() < 0.5
		candidate.covered_from_others = random.randf()
		candidate.in_area = random.randf() < 0.9
		candidates.append(candidate)
	return candidates


func test_with_claims_no_two_bots_of_a_team_take_the_same_spot() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 51
	var weights := TacticalPositions.Weights.new()
	for _trial: int in range(TRIALS):
		var chosen: Array[int] = _each_bot_claims(_random_candidates(random, 8), weights, 6)
		var spots: Array[int] = chosen.filter(func(spot: int) -> bool: return spot != -1)
		var distinct: Dictionary = {}
		for spot: int in spots:
			distinct[spot] = true
		assert_int(distinct.size()).override_failure_message("two bots on one spot: %s" % [chosen]).is_equal(spots.size())


# Six bots of one team choose in turn, each claiming what it chose; the spot
# each took, or -1.
func _each_bot_claims(candidates: Array[TacticalPositions.Candidate],
		weights: TacticalPositions.Weights, bots: int) -> Array[int]:
	var chosen: Array[int] = []
	for bot: int in range(bots):
		var choice: TacticalPositions.Choice = TacticalPositions.choose(bot, candidates, weights, true, true)
		chosen.append(choice.chosen)
		if choice.chosen != -1:
			candidates[choice.chosen].claimed_by = bot
	return chosen


func test_a_chosen_spot_always_passed_every_condition_and_scored_best() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 52
	var weights := TacticalPositions.Weights.new()
	for _trial: int in range(TRIALS):
		var candidates: Array[TacticalPositions.Candidate] = _random_candidates(random, 6)
		var threat: bool = random.randf() < 0.8
		var choice: TacticalPositions.Choice = TacticalPositions.choose(0, candidates, weights, threat, true)
		if choice.chosen == -1:
			assert_bool(choice.statuses.has(TacticalPositions.KEPT)).is_false()
			continue
		assert_str(choice.statuses[choice.chosen]).is_equal(TacticalPositions.KEPT)
		var best: float = Array(choice.scores).max()
		assert_float(choice.scores[choice.chosen]).is_equal(best)


func test_the_commander_gives_every_squad_an_order() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 53
	for _trial: int in range(TRIALS):
		var squads: Array[TeamCommander.SquadReport] = []
		for index: int in range(random.randi_range(1, 5)):
			var squad := TeamCommander.SquadReport.new()
			squad.id = "s%d" % index
			squad.position = Vector2(random.randf_range(0, 40), random.randf_range(0, 40))
			squad.size = random.randi_range(1, 3)
			squads.append(squad)
		var objectives: Array[TeamCommander.Objective] = []
		for index: int in range(random.randi_range(1, 3)):
			var objective := TeamCommander.Objective.new()
			objective.id = "o%d" % index
			objective.position = Vector2(random.randf_range(0, 40), random.randf_range(0, 40))
			objective.held_by = random.randi_range(-1, 1)
			objective.influence = random.randf_range(-2.0, 2.0)
			objectives.append(objective)
		var orders: Dictionary = TeamCommander.assign(squads, objectives, TeamCommander.Weights.new())
		assert_int(orders.size()).is_equal(squads.size())


func test_a_retreating_squad_always_has_someone_moving() -> void:
	for size: int in range(1, 7):
		var members: Array[int] = []
		members.assign(range(size))
		for phase: int in [0, 1]:
			var split: SquadConfidence.Waves = SquadConfidence.waves(members, phase)
			assert_int(split.moving.size()).is_greater(0)
			assert_int(split.moving.size() + split.covering.size()).is_equal(size)


func test_influence_is_symmetric_between_two_sides_of_equal_strength() -> void:
	var map := TeamInfluence.new(20, 20, 1.0, Vector2.ZERO, 5.0)
	map.add_source(Vector2(5.5, 10.5), 1.0)
	map.add_source(Vector2(15.5, 10.5), -1.0)
	assert_float(map.value_at(Vector2(10.5, 10.5))).is_equal_approx(0.0, 1e-9)
	assert_float(map.value_at(Vector2(5.5, 10.5))).is_equal_approx(-map.value_at(Vector2(15.5, 10.5)), 1e-9)


func test_the_checker_refuses_a_vector_missing_a_part_or_of_an_unknown_kind() -> void:
	var whole: Dictionary = {"name": "n", "why": "w", "kind": "positions", "query": {}, "expect": {"chosen": 0}}
	assert_str(TeamworkVector.why_not_a_vector(whole)).is_equal("")
	for key: String in ["name", "why", "kind", "query", "expect"]:
		var broken: Dictionary = whole.duplicate(true)
		broken.erase(key)
		assert_str(TeamworkVector.why_not_a_vector(broken)).is_not_equal("")
	var unknown: Dictionary = whole.duplicate(true)
	unknown["kind"] = "telepathy"
	assert_str(TeamworkVector.why_not_a_vector(unknown)).is_not_equal("")
	var empty: Dictionary = whole.duplicate(true)
	empty["expect"] = {}
	assert_str(TeamworkVector.why_not_a_vector(empty)).is_not_equal("")


func test_the_checker_catches_a_wrong_number_a_wrong_word_and_a_missing_key() -> void:
	var found: Array[String] = []
	TeamworkVector.differences({"value": 1.0}, {"value": 1.0 + 10 * TeamworkVector.TOLERANCE}, "n", found)
	TeamworkVector.differences({"state": "hold"}, {"state": "attack"}, "n", found)
	TeamworkVector.differences({"a": 1, "b": 2}, {"a": 1}, "n", found)
	assert_int(found.size()).is_equal(3)
	var none: Array[String] = []
	TeamworkVector.differences({"value": 1.0, "list": [1, "x"]}, {"value": 1.00001, "list": [1.0, "x"]}, "n", none)
	assert_array(none).is_empty()
