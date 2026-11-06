# T128: a fighting squad's focus ring when its target walks out of the
# side's sight. The ring stays, where the side was last told of the target
# -- the handed view under the clock, its memory otherwise -- and is
# recorded as stale; a target it was never told of gets no ring at all.
extends GdUnitTestSuite

const TARGET: int = 5
const MEMBER: int = 10


# A side that decides nothing: under the clock, only the view it is handed
# matters here.
class Idle:
	extends GakRtsController

	func decide(_view: RtsSnapshot) -> Array[RtsCommand]:
		return []


func test_a_focus_in_sight_is_ringed_where_it_stands_now() -> void:
	var thinking: RtsThinking = _fighting_thinking()
	thinking.view = _view_at(0, Vector2(4.5, 1.5))

	await _drawn(thinking)

	assert_array(thinking.drawn_focus).is_equal([_ring(Vector2(4.5, 1.5), false)])


func test_a_focus_out_of_sight_is_ringed_where_the_side_last_saw_it() -> void:
	var thinking: RtsThinking = _fighting_thinking()
	thinking.side.belief.update(_view_at(0, Vector2(4.5, 1.5)))
	# The runner has walked out of sight; the squad still holds it.
	thinking.view = _view_at(30, Vector2.INF)

	await _drawn(thinking)

	assert_dict(thinking.side.squads[0].focus).is_not_empty()
	assert_array(thinking.drawn_focus).is_equal([_ring(Vector2(4.5, 1.5), true)])


func test_under_the_clock_the_ring_falls_back_to_the_handed_place() -> void:
	var thinking: RtsThinking = _fighting_thinking()
	var clock := RtsHumanClock.new(Idle.new(), 350.0, 0)
	thinking.clock = clock
	clock.decide(_view_at(0, Vector2(4.5, 1.5)))
	clock.decide(_view_at(30, Vector2.INF))
	# Its memory says elsewhere: the handed view is what the side decided on.
	thinking.side.belief.update(_view_at(15, Vector2(6.5, 1.5)))
	thinking.view = _view_at(30, Vector2.INF)

	await _drawn(thinking)

	assert_array(clock.last_handed().enemies().map(func(unit: Dictionary) -> int: return unit["id"])).is_equal([TARGET])
	assert_array(thinking.drawn_focus).is_equal([_ring(Vector2(4.5, 1.5), true)])


func test_a_focus_the_side_was_never_told_of_gets_no_ring() -> void:
	var thinking: RtsThinking = _fighting_thinking()
	thinking.view = _view_at(30, Vector2.INF)

	await _drawn(thinking)

	assert_array(thinking.drawn_focus).is_empty()


# A thinking view in the tree for a fresh east commander with one squad,
# fighting, focused on the west runner `TARGET`.
func _fighting_thinking() -> RtsThinking:
	var thinking: RtsThinking = auto_free(RtsThinking.new())
	var side := RtsCommander.new(RtsScenario.EAST, RtsLevels.named("normal"), 1, BuildOrder.Planner.STRIPS)
	var squad := Squad.new(1, RtsScenario.EAST)
	squad.members.append(MEMBER)
	squad.machine.current = Squad.FIGHT
	squad.centre = Vector2(2.5, 1.5)
	squad.focus_scores.append({"id": TARGET, "kind": RtsKinds.RUNNER, "score": 0.9, "why": []})
	squad.focus = squad.focus_scores[0]
	side.squads.append(squad)
	thinking.side = side
	add_child(thinking)
	return thinking


# East's view at `tick`: its runner `MEMBER` on (2.5, 1.5), and the west
# runner `TARGET` at `seen` -- none when `seen` is INF.
static func _view_at(tick: int, seen: Vector2) -> RtsSnapshot:
	var view := RtsSnapshot.new()
	view.side = RtsScenario.EAST
	view.tick = tick
	view.graph = GakGridGraph.new(8, 4)
	view.units.append(_runner(MEMBER, RtsScenario.EAST, Vector2(2.5, 1.5)))
	if seen != Vector2.INF:
		view.units.append(_runner(TARGET, RtsScenario.WEST, seen))
	return view


static func _runner(id: int, side: int, position: Vector2) -> Dictionary:
	return {"id": id, "side": side, "kind": RtsKinds.RUNNER, "position": position,
		"health": RtsKinds.of(RtsKinds.RUNNER, "health"), "complete": true}


# The one ring the squad's chosen focus should leave, as `drawn_focus` keeps it.
static func _ring(at: Vector2, stale: bool) -> Dictionary:
	return {"id": TARGET, "at": at, "stale": stale, "chosen": true}


func _drawn(thinking: RtsThinking) -> void:
	thinking.queue_redraw()
	await get_tree().process_frame
