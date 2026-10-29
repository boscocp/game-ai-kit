# The ai_teamwork page's minimal example, loaded into an empty scene and
# asked twice: of three fighters wanting to flank only the best goes round
# and the others shoot; and when the only one who can shoot asks to flank,
# it is kept shooting. The page shows the file's text, held equal by
# check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/ai_teamwork/squad_example.gd")


func _squad() -> Node:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var example: Node = EXAMPLE.new()
	scene.add_child(example)
	return example


func _fighter(name: String, wants_to_flank: bool, flank_score: float, can_shoot: bool = true) -> Dictionary:
	return {"name": name, "wants_to_flank": wants_to_flank, "flank_score": flank_score, "can_shoot": can_shoot}


func test_one_flanker_and_the_rest_shoot() -> void:
	var squad: Node = _squad()
	var fighters: Array[Dictionary] = [_fighter("ana", true, 0.4), _fighter("bia", true, 0.9),
			_fighter("caio", false, 0.0), _fighter("davi", true, 0.6)]
	var roles: Dictionary = squad.roles(fighters)
	assert_dict(roles).is_equal({"ana": "shooter", "bia": "flanker", "caio": "shooter", "davi": "shooter"})


func test_someone_always_shoots() -> void:
	var squad: Node = _squad()
	var fighters: Array[Dictionary] = [_fighter("ana", true, 0.9), _fighter("bia", true, 0.5, false)]
	var roles: Dictionary = squad.roles(fighters)
	assert_dict(roles).is_equal({"ana": "shooter", "bia": "none"})
