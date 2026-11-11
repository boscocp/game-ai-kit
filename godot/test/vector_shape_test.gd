# `VectorShape`, the types every vectors runner checks before it reads a
# file (T121). Each rule below with a planted value it must refuse: a shape
# that only knows how to say "" would let every runner exit 0 again.
extends GdUnitTestSuite

const SHAPE: Dictionary = {
	"seed": VectorShape.NUMBER,
	"draws": [VectorShape.NUMBER],
	"board": [[VectorShape.TEXT]],
	"cases": [{"name": VectorShape.TEXT, "won": VectorShape.FLAG, "note?": VectorShape.TEXT}],
	"chances": {"*": VectorShape.NUMBER},
	"solution": VectorShape.OBJECT_OR_NULL,
	"anything": VectorShape.ANY,
}


func _sound() -> Dictionary:
	return {
		"seed": 7, "draws": [1.0, 2], "board": [["a", "b"], []],
		"cases": [{"name": "first", "won": true}, {"name": "second", "won": false, "note": "a tie"}],
		"chances": {"high": 0.25, "low": 0.75}, "solution": null, "anything": [{"x": 1}],
	}


func test_a_sound_value_is_accepted() -> void:
	assert_str(VectorShape.why_not(_sound(), SHAPE)).is_empty()
	assert_str(VectorShape.why_not(VectorShape.planted(_sound(), ["solution"], {"a": 1}), SHAPE)).is_empty()


func test_a_list_given_as_text_is_refused_and_named_by_its_path() -> void:
	assert_str(VectorShape.why_not(VectorShape.planted(_sound(), ["draws"], "x"), SHAPE)) \
			.is_equal("the file.draws is not a list")
	assert_str(VectorShape.why_not(VectorShape.planted(_sound(), ["board", 1], "x"), SHAPE, "a.json")) \
			.is_equal("a.json.board[1] is not a list")
	assert_str(VectorShape.why_not("x", SHAPE)).is_equal("the file is not an object")


func test_a_leaf_of_the_wrong_type_is_refused() -> void:
	assert_str(VectorShape.why_not(VectorShape.planted(_sound(), ["seed"], "7"), SHAPE)).ends_with("is not a number")
	assert_str(VectorShape.why_not(VectorShape.planted(_sound(), ["draws", 0], "1"), SHAPE)) \
			.is_equal("the file.draws[0] is not a number")
	assert_str(VectorShape.why_not(VectorShape.planted(_sound(), ["board", 0, 1], 2), SHAPE)).ends_with("is not text")
	assert_str(VectorShape.why_not(VectorShape.planted(_sound(), ["cases", 0, "won"], 1), SHAPE)) \
			.ends_with("is not true or false")
	assert_str(VectorShape.why_not(VectorShape.planted(_sound(), ["solution"], "x"), SHAPE)) \
			.ends_with("is not an object or null")


func test_a_missing_key_is_refused_unless_it_is_optional() -> void:
	var missing: Dictionary = _sound()
	missing.erase("seed")
	assert_str(VectorShape.why_not(missing, SHAPE)).is_equal("the file has no seed")
	assert_str(VectorShape.why_not(VectorShape.planted(_sound(), ["cases", 0, "note"], 3), SHAPE)) \
			.is_equal("the file.cases[0].note is not text")


func test_every_key_of_a_table_is_held_to_its_star() -> void:
	assert_str(VectorShape.why_not(VectorShape.planted(_sound(), ["chances", "throw"], "half"), SHAPE)) \
			.is_equal("the file.chances.throw is not a number")
	assert_str(VectorShape.why_not(VectorShape.planted(_sound(), ["chances"], []), SHAPE)) \
			.is_equal("the file.chances is not an object")


func test_planting_leaves_the_original_alone() -> void:
	var sound: Dictionary = _sound()
	var _planted: Dictionary = VectorShape.planted(sound, ["cases", 0, "name"], 1)
	assert_str(sound["cases"][0]["name"]).is_equal("first")
