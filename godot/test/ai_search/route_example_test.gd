# The ai_search page's minimal example, loaded into an empty scene: it must
# find the one gap in its wall. The page shows the file's text and
# check_translations_docs.py holds the two equal, so what the page shows is
# what ran here.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/ai_search/route_example.gd")


func test_the_example_finds_the_route_through_the_gap() -> void:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var example: Node = EXAMPLE.new()
	scene.add_child(example)
	var route: Array[Vector2i] = example.get("route")
	# Down three, across five, up three: the gap is at the bottom of column 3.
	assert_int(route.size()).is_equal(11)
	assert_array(route).contains([Vector2i(3, 3)])
	assert_object(route.back()).is_equal(Vector2i(5, 0))
