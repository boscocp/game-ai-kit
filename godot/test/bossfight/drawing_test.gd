# The boss fight's drawing (wave 195): with the reasoning hidden, no bolt
# in the air and no lock-on there is nothing to draw, and drawing nothing
# must not ask the engine for an empty surface -- it printed "No vertices
# were added" every frame it happened. gdUnit4 only prints an engine error
# and passes the test (measured on v6.2.2), so the refresh runs inside
# `assert_error(...).is_success()`, which fails on one; run on the code
# before the fix, it did. With the reasoning shown, the lines are still
# drawn.
extends GdUnitTestSuite


func _fresh_fight() -> BossFight:
	return BossFight.new(BossFightRules.read(), BossTable.from_file(), 1)


func _drawn(fight: BossFight, thinking: bool) -> ImmediateMesh:
	var drawing: BossfightDrawing = auto_free(BossfightDrawing.new())
	drawing.build(fight)
	await assert_error(func() -> void: drawing.refresh(fight, thinking)).is_success()
	var lines: MeshInstance3D = drawing.find_children("", "MeshInstance3D", false, false).filter(
			func(node: Node) -> bool: return node.mesh is ImmediateMesh)[0]
	return lines.mesh


func test_nothing_to_draw_draws_no_surface() -> void:
	var fight: BossFight = _fresh_fight()
	assert_bool(fight.bolts.is_empty()).is_true()
	assert_str(fight.player.locked).is_empty()
	assert_int((await _drawn(fight, false)).get_surface_count()).is_equal(0)


# One surface of whole segments, a colour on every vertex: a segment that
# lost a point or a colour would leave the two counts apart, or odd.
func test_the_reasoning_is_still_drawn() -> void:
	var lines: ImmediateMesh = await _drawn(_fresh_fight(), true)
	assert_int(lines.get_surface_count()).is_equal(1)
	var arrays: Array = lines.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	assert_int(vertices.size()).is_greater(0)
	assert_int(vertices.size() % 2).is_equal(0)
	assert_int(colours.size()).is_equal(vertices.size())
