# The bandit vector's rules, each refusing a planted case, and two planted
# bandits -- one that breaks ties to the last arm, one that spends a spare
# draw -- each failing the vector it must.
extends GdUnitTestSuite

const NAMES: Array[String] = ["ucb1-two-arms-by-hand.json", "ucb1-settles-on-the-best.json",
		"ucb1-ties-go-to-the-first.json", "ucb1-without-exploration-is-greedy.json", "epsilon-greedy-seeded.json",
		"epsilon-one-is-random.json", "one-arm-draws-nothing.json"]


## Equal scores go to the last arm, not the first.
class LastOfEqual extends Bandit:
	func _highest(score: Callable) -> int:
		var best: int = 0
		for arm: int in range(1, arms()):
			if score.call(arm) >= score.call(best):
				best = arm
		return best


## One draw thrown away before every choice once all arms are tried.
class SpareDraw extends Bandit:
	func choose() -> int:
		if _first_untried() < 0:
			_draws.next()
		return super()


func _vector(name: String) -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://").path_join("../spec/vectors/bandit").path_join(name)
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func test_the_vectors_are_vectors_and_hold() -> void:
	for name: String in NAMES:
		var vector: Dictionary = _vector(name)
		var claims: Array[String] = BanditVector.wrong_claims(vector, BanditVector.bandit_of(vector))
		assert_str(BanditVector.why_not_a_vector(vector)).override_failure_message(name).is_empty()
		assert_array(claims).override_failure_message(name).is_empty()


func test_a_broken_vector_is_refused_by_its_rule() -> void:
	var sound: Dictionary = _vector("ucb1-two-arms-by-hand.json")
	var changes: Array[Array] = [["V1", "chosn", [0]], ["V2", "policy", "softmax"], ["V3", "payoffs", [[1.0]]],
			["V4", "payoffs", [[1.5], [0.0]]], ["V5", "chosen", []], ["V6", "sums", [5.0]], ["V7", "pulls", [5, 3]]]
	for change: Array in changes:
		var broken: Dictionary = sound.duplicate(true)
		broken[change[1]] = change[2]
		assert_str(BanditVector.why_not_a_vector(broken)).starts_with(change[0])


func test_a_bandit_that_breaks_ties_to_the_last_fails() -> void:
	var vector: Dictionary = _vector("ucb1-ties-go-to-the-first.json")
	var planted := LastOfEqual.new(int(vector["arms"]))
	assert_array(BanditVector.wrong_claims(vector, planted)).is_not_empty()


func test_a_bandit_that_spends_a_spare_draw_fails() -> void:
	var vector: Dictionary = _vector("epsilon-greedy-seeded.json")
	var planted := SpareDraw.new(int(vector["arms"]), vector["policy"], float(vector["exploration"]),
			float(vector["epsilon"]), int(vector["seed"]))
	assert_array(BanditVector.wrong_claims(vector, planted)).is_not_empty()
