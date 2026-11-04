# `Xorshift`, the kit's one seeded generator (T109), one claim per test, and
# the rules `XorshiftVector` holds spec/vectors/core/ to, each with a planted
# case it must refuse. Read from spec/, so these break the day the vectors
# move -- which is when they should.
extends GdUnitTestSuite


## A generator that spends a draw on a pick of one. The maze's own copy did,
## harmlessly, because its ghosts never pick among one way; the shared
## generator does not, and a twin that did would part from it at once.
class SpendsOnOne:
	extends Xorshift

	func _init(from_seed: int) -> void:
		super(from_seed)

	func index(count: int) -> int:
		return next() % count


## A generator that forgets to cut its left shifts to 32 bits: GDScript's
## `int` is 64, so it keeps bits Python's twin would keep too and Marsaglia's
## would not.
class Unmasked:
	extends Xorshift

	var _wide: int

	func _init(from_seed: int) -> void:
		super(from_seed)
		_wide = from_seed if from_seed != 0 else SEED_FOR_ZERO

	func next() -> int:
		_wide ^= _wide << 13
		_wide ^= _wide >> 17
		_wide ^= _wide << 5
		return _wide


# Seed 1's first draw, worked in the README: 1 xor (1 << 13) is 8193, which
# 17 places to the right is 0, and 8193 xor (8193 << 5) is 270369.
func test_it_starts_where_marsaglia_starts_and_zero_is_one() -> void:
	assert_int(Xorshift.new(1).next()).is_equal(270369)
	assert_int(Xorshift.new(0).next()).is_equal(270369)
	assert_int(Xorshift.new().next()).is_equal(270369)


func test_a_seed_is_cut_to_32_bits() -> void:
	assert_int(Xorshift.new(0x1_0000_0001).next()).is_equal(Xorshift.new(1).next())


func test_a_pick_of_one_spends_no_draw() -> void:
	var drawn := Xorshift.new(9)
	for _forced: int in range(5):
		assert_int(drawn.index(1)).is_equal(0)
	assert_int(drawn.next()).is_equal(Xorshift.new(9).next())


func test_a_uniform_is_a_draw_over_its_span() -> void:
	var first := Xorshift.new(86)
	var second := Xorshift.new(86)
	for _draw: int in range(20):
		var uniform: float = first.uniform()
		assert_float(uniform).is_greater(0.0)
		assert_float(uniform).is_less(1.0)
		assert_float(uniform * Xorshift.SPAN).is_equal(float(second.next()))


func test_the_generator_meets_every_claim() -> void:
	var vector: Dictionary = _read()
	assert_str(XorshiftVector.why_not_a_vector(vector)).is_empty()
	assert_array(XorshiftVector.wrong_claims(vector, XorshiftVector.core_generator())).is_empty()


func test_a_generator_spending_a_draw_on_one_choice_fails_the_picks() -> void:
	var planted: Callable = func(from_seed: int) -> Xorshift: return SpendsOnOne.new(from_seed)
	var wrong: Array[String] = XorshiftVector.wrong_claims(_read(), planted)
	assert_array(wrong).is_not_empty()
	for failure: String in wrong:
		assert_str(failure).contains("picked")


func test_a_generator_without_the_mask_fails_the_draws() -> void:
	var planted: Callable = func(from_seed: int) -> Xorshift: return Unmasked.new(from_seed)
	assert_array(XorshiftVector.wrong_claims(_read(), planted)).is_not_empty()


func test_a_broken_vector_is_refused() -> void:
	var vector: Dictionary = _read()
	var first: Dictionary = vector["cases"][0]
	assert_str(XorshiftVector.why_not_a_vector({"cases": vector["cases"]})).starts_with("X1")
	assert_str(XorshiftVector.why_not_a_vector(_with(vector, "cases", []))).starts_with("X2")
	assert_str(XorshiftVector.why_not_a_vector(_with(vector, "cases", [_with(first, "seeds", 1)]))).starts_with("X3")
	assert_str(XorshiftVector.why_not_a_vector(_with(vector, "cases", [_with(first, "picks", [0])]))).starts_with("X4")
	assert_str(XorshiftVector.why_not_a_vector(_with(vector, "cases", [_with(first, "draws", [])]))).starts_with("X5")


func test_a_wrong_claim_is_named_by_its_seed() -> void:
	var vector: Dictionary = _read()
	var first: Dictionary = _with(vector["cases"][0], "uniforms", [0.5])
	var wrong: Array[String] = XorshiftVector.wrong_claims(_with(vector, "cases", [first]), XorshiftVector.core_generator())
	assert_array(wrong).has_size(1)
	assert_str(wrong[0]).starts_with("seed 1: uniforms")


func _read() -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://").path_join("../spec/vectors/core/xorshift.json")
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _with(dictionary: Dictionary, key: String, value: Variant) -> Dictionary:
	var changed: Dictionary = dictionary.duplicate()
	changed[key] = value
	return changed
