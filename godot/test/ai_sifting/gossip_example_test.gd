# The ai_sifting page's minimal example, loaded into an empty scene: the
# keeper tells the theft that was answered by a catch, not the one before
# it, nor a catch somewhere else, and telling changes nothing it was told.
# The page shows the file's text, held equal by check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/ai_sifting/gossip_example.gd")


func _keeper() -> Node:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var example: Node = EXAMPLE.new()
	scene.add_child(example)
	example.happened(1, "theft", "Wren", "baker")
	example.happened(2, "theft", "Wren", "baker")
	example.happened(3, "caught", "Wren", "smith")
	example.happened(4, "caught", "Wren", "baker")
	return example


func test_the_keeper_tells_the_theft_the_catch_answered() -> void:
	var stories: Array[Dictionary] = _keeper().stories()
	assert_int(stories.size()).is_equal(1)
	assert_str(stories[0]["line"]).is_equal("Wren stole from the baker on day 2, and was caught there on day 4.")
	assert_array(stories[0]["events"]).is_equal([1, 3])


func test_telling_twice_tells_the_same() -> void:
	var keeper: Node = _keeper()
	assert_array(keeper.stories()).is_equal(keeper.stories())
