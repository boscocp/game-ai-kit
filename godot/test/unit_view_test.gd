# T33: units that walk. A figure with a sheet draws a different frame as time
# passes, a unit without one keeps its still picture, and a unit sent to a cell
# goes along its route rather than appearing there. Headless nothing is drawn,
# so what is held is what `_draw` would be handed: the frame, and the point.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE

var _generated_before: String


# Judged on the committed sheets, never on a person's own generated ones.
func before_test() -> void:
	_generated_before = Art.generated
	Art.generated = Art.ROOT + "no-such-folder/"


func after_test() -> void:
	Art.generated = _generated_before


# --- frames ----------------------------------------------------------------

func test_a_unit_with_a_sheet_draws_a_different_frame_at_two_different_times() -> void:
	var scene: TacticalGame = _mounted_scene()
	var view: UnitView = _view_of(scene)
	var shield: Unit = _first_of(scene.state, RED, TacticalRules.SHIELD)
	var first: Rect2 = view.frame_of(shield)

	view.advance(1.0 / UnitView.MARCH_RATE)

	assert_bool(first.has_area()).is_true()
	assert_that(view.frame_of(shield)).is_not_equal(first)
	assert_object(view.pictures()[shield.id]).is_same(Art.texture(Art.sheet_path(RED, TacticalRules.SHIELD)))


func test_a_unit_without_a_sheet_draws_its_still_picture() -> void:
	var scene: TacticalGame = _mounted_scene()
	var view: UnitView = _view_of(scene)
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)

	view.advance(1.0 / UnitView.MARCH_RATE)

	assert_that(view.frame_of(runner)).is_equal(Rect2())
	assert_object(view.pictures()[runner.id]).is_same(Art.texture(Art.unit_path(RED, TacticalRules.RUNNER)))


# Advance Wars' convention, kept: a unit that has acted stops marching.
func test_a_spent_figure_stands_still() -> void:
	var scene: TacticalGame = _mounted_scene()
	var view: UnitView = _view_of(scene)
	var shield: Unit = _first_of(scene.state, RED, TacticalRules.SHIELD)
	scene.click_cell(shield.cell)
	scene.wait()
	var first: Rect2 = view.frame_of(shield)

	view.advance(1.0 / UnitView.MARCH_RATE)

	assert_that(view.frame_of(shield)).is_equal(first)
	assert_that(first).is_equal(Art.sheet_for(RED, TacticalRules.SHIELD).standing(Vector2i.RIGHT))


func test_a_figure_faces_the_other_side_until_it_walks() -> void:
	var scene: TacticalGame = _mounted_scene()
	var view: UnitView = _view_of(scene)
	var red: Unit = _first_of(scene.state, RED, TacticalRules.SHIELD)
	var sheet: UnitSheet = Art.sheet_for(RED, TacticalRules.SHIELD)
	assert_that(view.frame_of(red)).is_equal(sheet.walking(Vector2i.RIGHT, 0))


# --- moving -------------------------------------------------------------------

func test_a_moving_unit_is_drawn_between_cells_partway_and_at_its_destination_after() -> void:
	var scene: TacticalGame = _mounted_scene()
	var view: UnitView = _view_of(scene)
	var board: BoardView = scene.get_node("BoardView")
	var shield: Unit = _first_of(scene.state, RED, TacticalRules.SHIELD)
	var start: Vector2i = shield.cell
	var path: Array[Vector2i] = _longest_walk(scene.state, shield)
	scene.click_cell(start)
	scene.click_cell(path[path.size() - 1])
	var moved: Unit = scene.state.unit_by_id(shield.id)

	view.advance(UnitWalk.SECONDS_PER_CELL / 2.0)
	var halfway: Vector2 = board.centre_of(start).lerp(board.centre_of(path[0]), 0.5)
	assert_vector(view.position_of(moved)).is_equal_approx(halfway, Vector2(0.01, 0.01))

	view.advance(UnitWalk.SECONDS_PER_CELL * path.size())
	assert_bool(view.is_walking(shield.id)).is_false()
	assert_vector(view.position_of(moved)).is_equal(board.centre_of(path[path.size() - 1]))


func test_a_walking_figure_faces_the_step_it_is_taking() -> void:
	var scene: TacticalGame = _mounted_scene()
	var view: UnitView = _view_of(scene)
	var shield: Unit = _first_of(scene.state, RED, TacticalRules.SHIELD)
	var path: Array[Vector2i] = _longest_walk(scene.state, shield)
	scene.click_cell(shield.cell)
	scene.click_cell(path[path.size() - 1])
	var moved: Unit = scene.state.unit_by_id(shield.id)

	view.advance(UnitWalk.SECONDS_PER_CELL / 2.0)

	var first_step: Vector2i = path[0] - shield.cell
	var sheet: UnitSheet = Art.sheet_for(RED, TacticalRules.SHIELD)
	assert_float(view.frame_of(moved).position.y).is_equal(sheet.walking(first_step, 0).position.y)


func test_a_walk_faces_each_step_in_turn_and_keeps_the_last() -> void:
	var walk := UnitWalk.new(Vector2i(0, 0), [Vector2i(1, 0), Vector2i(1, 1)] as Array[Vector2i])
	assert_vector(walk.facing()).is_equal(Vector2i.RIGHT)
	walk.elapsed = UnitWalk.SECONDS_PER_CELL * 1.5
	assert_vector(walk.facing()).is_equal(Vector2i.DOWN)
	walk.elapsed = walk.duration() + 1.0
	assert_vector(walk.facing()).is_equal(Vector2i.DOWN)
	assert_bool(walk.finished()).is_true()


# A machine has no legs: it bobs on alternate frames while it rolls, and sits
# still on its cell at rest.
func test_a_machine_bobs_as_it_rolls_and_not_at_rest() -> void:
	var scene: TacticalGame = _mounted_scene()
	var view: UnitView = _view_of(scene)
	var board: BoardView = scene.get_node("BoardView")
	var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
	var resting: Unit = _first_of(scene.state, RED, TacticalRules.WORKSHOP)
	scene.click_cell(runner.cell)
	scene.click_cell(runner.cell + Vector2i(-1, 0))
	var moved: Unit = scene.state.unit_by_id(runner.id)
	var row: float = board.centre_of(runner.cell).y
	view.clock = 0.0

	view.advance(0.01)
	var level: float = view.position_of(moved).y
	view.advance(1.0 / UnitView.BOB_RATE)
	var raised: float = view.position_of(moved).y

	assert_float(level).is_equal(row)
	assert_float(raised).is_equal(row - UnitView.BOB_PIXELS)
	assert_vector(view.position_of(resting)).is_equal(board.centre_of(resting.cell))


func test_taking_a_move_back_drops_its_walk() -> void:
	var scene: TacticalGame = _mounted_scene()
	var view: UnitView = _view_of(scene)
	var board: BoardView = scene.get_node("BoardView")
	var shield: Unit = _first_of(scene.state, RED, TacticalRules.SHIELD)
	var path: Array[Vector2i] = _longest_walk(scene.state, shield)
	scene.click_cell(shield.cell)
	scene.click_cell(path[path.size() - 1])

	scene.undo()

	assert_bool(view.is_walking(shield.id)).is_false()
	assert_vector(view.position_of(scene.state.unit_by_id(shield.id))).is_equal(board.centre_of(shield.cell))


# What the pink line promised is what is seen: blue's unit walks the route its
# decision was drawn with.
func test_blue_walks_the_route_its_decision_was_drawn_with() -> void:
	var scene: TacticalGame = _mounted_scene()
	var view: UnitView = _view_of(scene)
	var board: BoardView = scene.get_node("BoardView")
	scene.step_decision()   # red's turn ends
	while scene._blue_turn.next != null and scene._blue_turn.next.kind() != "move":
		scene.step_decision()
	var decision: TacticalDecision = scene._blue_turn.next
	assert_object(decision).is_not_null()
	var start: Vector2i = scene.state.unit_by_id(decision.unit_id).cell

	scene.step_decision()
	view.advance(UnitWalk.SECONDS_PER_CELL / 2.0)

	var halfway: Vector2 = board.centre_of(start).lerp(board.centre_of(decision.move.path[0]), 0.5)
	assert_bool(view.is_walking(decision.unit_id)).is_true()
	assert_vector(view.position_of(scene.state.unit_by_id(decision.unit_id))).is_equal_approx(halfway, Vector2(0.01, 0.01))


# --- helpers -------------------------------------------------------------------

func _mounted_scene() -> TacticalGame:
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	add_child(scene)
	# The clock is the test's: a frame passing mid-test would move it.
	_view_of(scene).set_process(false)
	return scene


func _view_of(scene: TacticalGame) -> UnitView:
	return scene.get_node("UnitView") as UnitView


func _first_of(state: BoardState, faction: int, type_name: String) -> Unit:
	for unit: Unit in state.units_of(faction):
		if unit.type.type_name == type_name:
			return unit
	return null


# The longest route `unit` can walk this turn: at least two steps, so there is
# a between to be drawn at.
func _longest_walk(state: BoardState, unit: Unit) -> Array[Vector2i]:
	var longest: Array[Vector2i] = []
	var walks: Dictionary = TacticalReach.walks_for(state, unit)
	for cell: Vector2i in walks:
		if (walks[cell] as Array).size() > longest.size():
			longest.assign(walks[cell])
	assert_int(longest.size()).is_greater_equal(2)
	return longest
