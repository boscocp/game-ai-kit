# The art table is the contract T31 swaps files behind. So every path must be a
# file the engine can load, every kind of piece in the game must have a file of
# its own, and pictures a reader must tell apart must differ in shape, not only
# in colour -- the reason T9 exists.
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


# Two kinds sharing one file would be one picture under two names.
func test_no_two_kinds_share_a_file() -> void:
	var files: Array = Art.UNIT_FILES.values()
	for file: String in files:
		assert_int(files.count(file)).override_failure_message(file + " is shared").is_equal(1)


# The silhouette is where a picture is not see-through. Two kinds whose
# silhouettes match are told apart by colour alone, which a colour-blind
# reader cannot do. Every pair of kinds on a side must differ in at least
# `SILHOUETTE_APART` of their pixels.
#
# This is a floor, not the claim. Measured on the pack's 16-pixel tiles, the
# closest pair -- runner and wader -- differs in 13 of 256 pixels, about 5%:
# Tiny Battle draws every unit on a filled plate, and the shapes differ inside
# it. Whether five kinds read apart at a glance is the manual check's.
const SILHOUETTE_APART: float = 0.04


func test_every_kind_on_each_side_is_its_own_silhouette() -> void:
	for faction: int in range(Art.SIDES.size()):
		_assert_every_kind_apart(faction)


# Each atlas column is the file named for it: a wall drawn as mud would pass
# every test about the tiles being different.
func test_each_kind_of_ground_is_the_file_named_for_it() -> void:
	var expected: Dictionary = {
		BoardView.PLAIN: "plain.png", BoardView.ROUGH: "rough.png", BoardView.WALL: "wall.png",
		BoardView.NODE: "node.png", BoardView.WATER: "water.png", BoardView.BRIDGE: "bridge.png",
		BoardView.TREES: "trees.png",
	}
	assert_int(expected.size()).is_equal(Art.TERRAIN.size())
	for column: Vector2i in expected:
		assert_str(Art.TERRAIN[column.x]).is_equal(Art.ROOT + "terrain/" + expected[column])


func test_a_red_man_and_a_white_man_are_different_pictures() -> void:
	var red: Image = Art.texture(Art.RED_MAN).get_image()
	var white: Image = Art.texture(Art.WHITE_MAN).get_image()
	assert_bool(red.get_data() == white.get_data()).is_false()


# A crown on a man must read as a crown, and an X as an X: shapes, not tints.
func test_the_cross_the_nought_and_the_crown_are_three_shapes() -> void:
	_assert_apart(Art.CROSS, Art.NOUGHT)
	_assert_apart(Art.CROSS, Art.CROWN)
	_assert_apart(Art.NOUGHT, Art.CROWN)
	# Drawn on a man, a crown shaped like a man would vanish into it.
	_assert_apart(Art.CROWN, Art.RED_MAN)
	_assert_apart(Art.CROWN, Art.WHITE_MAN)


func test_a_king_is_its_man_with_a_crown_on() -> void:
	assert_array(CheckersView.pictures_of(CheckersBoard.RED_MAN)).is_equal([Art.RED_MAN])
	assert_array(CheckersView.pictures_of(CheckersBoard.WHITE_MAN)).is_equal([Art.WHITE_MAN])
	assert_array(CheckersView.pictures_of(CheckersBoard.RED_KING)).is_equal([Art.RED_MAN, Art.CROWN])
	assert_array(CheckersView.pictures_of(CheckersBoard.WHITE_KING)).is_equal([Art.WHITE_MAN, Art.CROWN])


func test_an_x_is_drawn_as_the_cross_and_an_o_as_the_nought() -> void:
	assert_str(TicTacToeView.picture_of(TicTacToeBoard.CROSS)).is_equal(Art.CROSS)
	assert_str(TicTacToeView.picture_of(TicTacToeBoard.NOUGHT)).is_equal(Art.NOUGHT)
	assert_str(TicTacToeView.picture_of(TicTacToeBoard.EMPTY)).is_empty()


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


func _assert_every_kind_apart(faction: int) -> void:
	var names: Array = Art.UNIT_FILES.keys()
	for first: int in range(names.size()):
		for second: int in range(first + 1, names.size()):
			_assert_apart(Art.unit_path(faction, names[first]), Art.unit_path(faction, names[second]))


func _assert_apart(first: String, second: String) -> void:
	var one: PackedByteArray = _silhouette(first)
	var other: PackedByteArray = _silhouette(second)
	var differing: int = 0
	for index: int in range(one.size()):
		differing += 1 if one[index] != other[index] else 0
	assert_float(float(differing) / one.size()).override_failure_message(
			"%s and %s: %d pixels apart" % [first, second, differing]).is_greater_equal(SILHOUETTE_APART)


# One byte per pixel: opaque or not, on a common 16-pixel grid so pictures
# drawn at different sizes compare. A copy, because a kept texture hands back
# the same image every time.
func _silhouette(path: String) -> PackedByteArray:
	var image: Image = Art.texture(path).get_image().duplicate() as Image
	image.convert(Image.FORMAT_RGBA8)
	image.resize(16, 16, Image.INTERPOLATE_NEAREST)
	var mask := PackedByteArray()
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			mask.append(1 if image.get_pixel(x, y).a > 0.5 else 0)
	return mask
