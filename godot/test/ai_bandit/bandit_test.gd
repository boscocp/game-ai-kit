# The bandit's rules the vectors cannot show: the settings it refuses, that a
# mean is a sum over a count, that choosing counts nothing, and the draws'
# hand-worked first number.
extends GdUnitTestSuite


func test_settings_that_cannot_work_are_named() -> void:
	assert_str(Bandit.new(0).problem()).contains("one arm")
	assert_str(Bandit.new(2, "softmax").problem()).contains("policy")
	assert_str(Bandit.new(2, Bandit.UCB1, -1.0).problem()).contains("exploration")
	assert_str(Bandit.new(2, Bandit.EPSILON_GREEDY, Bandit.EXPLORATION, 1.5).problem()).contains("epsilon")
	assert_str(Bandit.new(3).problem()).is_empty()


func test_every_arm_is_tried_once_first_in_order() -> void:
	for policy: String in [Bandit.UCB1, Bandit.EPSILON_GREEDY]:
		var bandit := Bandit.new(4, policy, Bandit.EXPLORATION, 1.0)
		var tried: Array[int] = []
		for pull: int in range(4):
			var arm: int = bandit.choose()
			tried.append(arm)
			bandit.reward(arm, 1.0 if arm == 3 else 0.0)
		assert_array(tried).is_equal([0, 1, 2, 3])


func test_a_mean_is_a_sum_over_pulls_read_when_asked() -> void:
	var bandit := Bandit.new(2)
	assert_float(bandit.mean(0)).is_equal(0.0)
	for payoff: float in [1.0, 0.0, 0.5]:
		bandit.reward(0, payoff)
	assert_int(bandit.pulls[0]).is_equal(3)
	assert_float(bandit.sums[0]).is_equal(1.5)
	assert_float(bandit.mean(0)).is_equal(0.5)


func test_the_bound_is_the_mean_plus_the_confidence_term() -> void:
	var bandit := Bandit.new(2)
	assert_float(bandit.bound(0)).is_equal(INF)
	bandit.reward(0, 1.0)
	bandit.reward(1, 0.0)
	bandit.reward(1, 0.5)
	assert_float(bandit.bound(0)).is_equal_approx(1.0 + sqrt(2.0 * log(3.0)), 1e-12)
	assert_float(bandit.bound(1)).is_equal_approx(0.25 + sqrt(2.0 * log(3.0) / 2.0), 1e-12)


func test_a_payoff_outside_zero_to_one_is_kept_to_it() -> void:
	var bandit := Bandit.new(1)
	bandit.reward(0, 3.0)
	bandit.reward(0, -1.0)
	assert_float(bandit.sums[0]).is_equal(1.0)


func test_choosing_changes_no_count() -> void:
	var bandit := Bandit.new(3, Bandit.EPSILON_GREEDY)
	for ask: int in range(5):
		bandit.choose()
	assert_array(Array(bandit.pulls)).is_equal([0, 0, 0])
	assert_array(Array(bandit.sums)).is_equal([0.0, 0.0, 0.0])


# Seed 1's first draw, worked in the README: 1 xor (1 << 13) is 8193, which
# 17 places to the right is 0, and 8193 xor (8193 << 5) is 270369.
func test_the_draws_start_where_the_readme_works_them() -> void:
	assert_int(BanditDraws.new(1).next()).is_equal(270369)
	assert_int(BanditDraws.new(0).next()).is_equal(270369)
