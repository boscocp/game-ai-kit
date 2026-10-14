# The art table is the contract T31 swaps files behind: a person drops their
# own picture at a path here and nothing else changes. So every path must be a
# file the engine can load, every kind of piece in the game must have a path of
# its own, and the five kinds a player builds must differ in shape, not only in
# colour -- the reason T9 exists.
extends GdUnitTestSuite


func test_every_path_in_the_art_table_is_a_picture() -> void:
	for path: String in Art.every_path():
		assert_bool(FileAccess.file_exists(path)).override_failure_message(path + " is not a file").is_true()
		assert_object(Art.texture(path)).override_failure_message(path + " does not load").is_not_null()


# A unit type with no entry would draw as the plain soldier, quietly. A type
# added to the rules has to be given a picture.
func test_every_kind_of_tactical_piece_has_its_own_picture() -> void:
	for type_name: String in TacticalRules.unit_types():
		assert_bool(Art.UNIT_FILES.has(type_name)).override_failure_message(type_name + " has no picture").is_true()


# The silhouette is where a picture is not see-through. Two kinds whose
# silhouettes match are told apart by colour alone, which a colour-blind
# reader cannot do.
func test_the_five_kinds_a_player_builds_are_five_silhouettes() -> void:
	var silhouettes: Dictionary = {}
	for type_name: String in TacticalRules.BUILDABLE:
		silhouettes[_silhouette(Art.unit_path(TacticalScenario.RED, type_name))] = type_name
	assert_int(silhouettes.size()).is_equal(TacticalRules.BUILDABLE.size())


func test_each_side_has_its_own_picture_of_each_kind() -> void:
	for type_name: String in Art.UNIT_FILES:
		var red: Image = Art.texture(Art.unit_path(TacticalScenario.RED, type_name)).get_image()
		var blue: Image = Art.texture(Art.unit_path(TacticalScenario.BLUE, type_name)).get_image()
		assert_bool(red.get_data() == blue.get_data()).override_failure_message(type_name).is_false()


# The table keeps what it loads. A texture loaded inside a `_draw` and let go
# when it returns is freed before it is shown, and on screen it was a white
# square. Headless, nothing is drawn, so this holds the cause: a texture asked
# for and let go is still the same texture when asked for again. Comparing two
# held at once would prove nothing -- Godot's own cache returns the one copy
# for as long as anybody holds it.
func test_a_picture_let_go_is_still_kept() -> void:
	var path: String = Art.unit_path(TacticalScenario.BLUE, TacticalRules.WORKSHOP)
	var first: int = Art.texture(path).get_instance_id()
	assert_int(Art.texture(path).get_instance_id()).is_equal(first)


func test_a_side_beyond_the_folders_draws_in_the_last_one() -> void:
	assert_str(Art.unit_path(7, TacticalRules.RAM)).is_equal(Art.unit_path(TacticalScenario.BLUE, TacticalRules.RAM))


func test_a_unit_with_no_type_is_drawn_as_the_soldier() -> void:
	var unit := Unit.new(1, TacticalScenario.RED, Vector2i.ZERO, 10, 3)
	assert_object(UnitView.picture_for(unit)).is_same(Art.texture(Art.unit_path(TacticalScenario.RED, Art.NO_TYPE)))


# One bit per pixel: opaque or not.
func _silhouette(path: String) -> PackedByteArray:
	var image: Image = Art.texture(path).get_image()
	image.convert(Image.FORMAT_RGBA8)
	var mask := PackedByteArray()
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			mask.append(1 if image.get_pixel(x, y).a > 0.5 else 0)
	return mask
