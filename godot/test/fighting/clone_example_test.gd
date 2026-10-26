# The behaviour-cloning page's minimal example, loaded into an empty scene
# with the cloned player the kit published: in a situation the recorded
# player met, the ghost must answer what it did there and the clone one of
# its answers; and a missing file must be refused, not half played. The
# page shows the file's text, held equal by check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/fighting/clone_example.gd")


func _opponent() -> Node:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var example: Node = EXAMPLE.new()
	scene.add_child(example)
	return example


# The published file, read directly, to compare the example against.
func _published() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FightCloneOpponent.PUBLISHED_PATH))


func test_the_example_plays_what_the_recorded_player_did() -> void:
	var opponent: Node = _opponent()
	assert_str(opponent.load_player(FightCloneOpponent.PUBLISHED_PATH)).is_empty()
	var published: Dictionary = _published()
	var key: String = published["cases"].keys()[0]
	var words: PackedStringArray = key.split(CaseTable.JOINER)
	var situation: Dictionary = {}
	for index: int in range(words.size()):
		situation[published["features"][index]] = words[index]
	var counts: Dictionary = opponent.ghost_counts(situation)
	var recorded: Dictionary = published["cases"][key]
	assert_int(counts.size()).is_equal(recorded.size())
	for answer: String in recorded:
		assert_float(float(counts.get(answer, -1))).is_equal(float(recorded[answer]))
	assert_array(published["classes"]).contains([opponent.clone_answer(situation)])
	var total: float = 0.0
	for chance: float in opponent.clone_chances(situation).values():
		total += chance
	assert_float(total).is_equal_approx(1.0, 0.0001)


func test_the_example_refuses_a_missing_file() -> void:
	var opponent: Node = _opponent()
	assert_str(opponent.load_player("res://test/fighting/no_such_clone.json")).starts_with("C1")
