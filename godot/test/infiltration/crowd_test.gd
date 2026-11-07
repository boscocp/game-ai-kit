# T152: a crowd to hide in. Only the market has civilians; they walk in
# groups on the floor, never through a wall, apart from each other, the same
# way twice; walking in step inside a group blends in and lowers a guard's
# certainty, sprinting or crouching stands out and raises it; the reading is
# the figure sign of the intruder network, where it lowers or raises the
# belief -- and a noise alone, or a figure standing out alone, still sends
# no guard; and the view says why, in English and in Portuguese.
extends GdUnitTestSuite

## How close two civilians may come, their middles, in metres: under the
## separation radius, over two bodies' shoulders touching (0.25 each).
const CLOSEST: float = 0.5

var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func _market() -> InfiltrationWorld:
	return InfiltrationWorld.make(InfiltrationLevel.read(InfiltrationLevel.MARKET), InfiltrationRules.read(), 1)


func test_only_the_market_has_a_crowd() -> void:
	for path: String in InfiltrationLevel.HAND_MADE:
		var world: InfiltrationWorld = InfiltrationWorld.make(InfiltrationLevel.read(path), InfiltrationRules.read(), 1)
		assert_object(world.crowd).override_failure_message("%s has a crowd" % path).is_null()
	var market: InfiltrationWorld = _market()
	assert_object(market.crowd).is_not_null()
	assert_int(market.crowd.people.size()).is_equal(16)
	assert_int(market.crowd.loops.size()).is_equal(3)


func test_the_crowd_walks_the_floor_apart_and_on_its_loops() -> void:
	var world: InfiltrationWorld = _market()
	var closest: float = INF
	var turned: Dictionary[int, bool] = {}
	for step: int in range(600):
		world.step(PlayerIntent.new())
		closest = minf(closest, _closest_on_the_floor(world))
		for group: int in range(world.crowd.loops.size()):
			turned[group] = turned.get(group, false) or world.crowd.heading_to[group] != 0
	print("  closest two civilians in %.0f s on the market: %.2f m" % [world.time, closest])
	assert_float(world.time).override_failure_message("the run ended before the crowd had walked").is_greater(30.0)
	assert_float(closest).is_greater(CLOSEST)
	assert_bool(turned.values().has(false)).override_failure_message("a group never reached its first point").is_false()


# The distance between the two closest civilians in `world` now, every one
# asserted on a walk cell.
func _closest_on_the_floor(world: InfiltrationWorld) -> float:
	var closest: float = INF
	for person: int in range(world.crowd.people.size()):
		var place: Vector2 = world.crowd.people[person].position
		assert_bool(world.level.walkable(world.level.cell_of(place))).override_failure_message(
			"civilian %d off the floor at %s, %.1f s" % [person, place, world.time]).is_true()
		for other: int in range(person + 1, world.crowd.people.size()):
			closest = minf(closest, place.distance_to(world.crowd.people[other].position))
	return closest


func test_two_runs_from_one_start_agree() -> void:
	var first: InfiltrationWorld = _market()
	var second: InfiltrationWorld = _market()
	for step: int in range(200):
		first.step(PlayerIntent.new())
		second.step(PlayerIntent.new())
	for person: int in range(first.crowd.people.size()):
		assert_vector(first.crowd.people[person].position).is_equal(second.crowd.people[person].position)


# The market a few seconds in, the player moved into the middle of group
# `group` and stepped once by `intent`, its cover read.
func _cover_after(intent: PlayerIntent, group: int = 2) -> InfiltrationCrowd.Cover:
	var world: InfiltrationWorld = _market()
	for step: int in range(30):
		world.step(PlayerIntent.new())
	world.player.position = world.crowd.middle_of(group)
	if intent.direction == Vector2.INF:
		intent.direction = world.crowd.heading_of(group)
	world.player.move(intent, world.level, world.rules, world.rules.step_seconds)
	return world.crowd.read_cover(world.player, world.rules, world.rules.step_seconds)


func _intent(stance: String, sprint: bool, direction: Vector2 = Vector2.INF) -> PlayerIntent:
	var intent := PlayerIntent.new()
	intent.stance = stance
	intent.sprint = sprint
	intent.direction = direction
	return intent


func test_walking_in_step_blends_in_and_the_rest_stands_out() -> void:
	var walking: InfiltrationCrowd.Cover = _cover_after(_intent("standing", false))
	assert_int(walking.group).is_equal(2)
	assert_str(walking.reason).is_equal(InfiltrationCrowd.IN_STEP)
	assert_str(walking.figure).is_equal(InfiltrationCrowd.BLENDS_IN)
	assert_float(walking.scale).is_less(1.0)
	var sprinting: InfiltrationCrowd.Cover = _cover_after(_intent("standing", true))
	assert_str(sprinting.reason).is_equal(InfiltrationCrowd.SPRINTING)
	assert_str(sprinting.figure).is_equal(InfiltrationCrowd.STANDS_OUT)
	assert_float(sprinting.scale).is_greater(1.0)
	assert_str(_cover_after(_intent("crouched", false)).reason).is_equal(InfiltrationCrowd.LOW)
	assert_str(_cover_after(_intent("standing", false, Vector2.ZERO)).reason).is_equal(InfiltrationCrowd.STILL)
	var world: InfiltrationWorld = _market()
	var against: Vector2 = -world.crowd.heading_of(2)
	assert_str(_cover_after(_intent("standing", false, against)).figure).is_equal(InfiltrationCrowd.STANDS_OUT)


# The market, the player put in the spine group's middle a moment in and
# walked with it -- its heading, and back towards its middle -- sprinting
# or not, for `steps` steps or until caught; the first time any guard was
# alert, or -1, and how many steps the player blended in.
func _ride_the_spine(sprint: bool, steps: int) -> Vector2:
	var world: InfiltrationWorld = _market()
	for step: int in range(5):
		world.step(PlayerIntent.new())
	world.player.position = world.crowd.middle_of(2)
	var blended: int = 0
	for step: int in range(steps):
		var intent := PlayerIntent.new()
		intent.direction = (world.crowd.heading_of(2) + (world.crowd.middle_of(2) - world.player.position) * 0.5).limit_length(1.0)
		intent.sprint = sprint
		world.step(intent)
		blended += 1 if world.crowd.cover.figure == InfiltrationCrowd.BLENDS_IN else 0
		if world.outcome != "" or world.guards.any(func(guard: InfiltrationGuard) -> bool: return guard.alert()):
			return Vector2(world.time, blended)
	return Vector2(-1.0, blended)


func test_walking_with_a_group_past_the_sentry_hides_and_sprinting_does_not() -> void:
	var walked: Vector2 = _ride_the_spine(false, 120)
	print("  walking in step down the spine: alert at %.1f s, blended in %d steps of 120" % [walked.x, walked.y])
	assert_float(walked.x).override_failure_message("a guard grew alert at a player walking in step").is_equal(-1.0)
	assert_float(walked.y).is_greater(100.0)
	var sprinted: Vector2 = _ride_the_spine(true, 120)
	print("  sprinting down the spine: alert at %.1f s, blended in %d steps" % [sprinted.x, sprinted.y])
	assert_float(sprinted.x).override_failure_message("no guard noticed a player sprinting through a crowd").is_greater(0.0)
	assert_float(sprinted.y).is_equal(0.0)


func test_footsteps_in_step_are_lost_in_the_crowd() -> void:
	var world: InfiltrationWorld = _market()
	world.player.position = world.crowd.middle_of(2)
	world.crowd.cover = InfiltrationCrowd.Cover.new()
	assert_bool(world._steps_covered()).is_false()
	world.crowd.cover.figure = InfiltrationCrowd.BLENDS_IN
	assert_bool(world._steps_covered()).is_true()
	world.crowd.cover.figure = InfiltrationCrowd.STANDS_OUT
	assert_bool(world._steps_covered()).is_false()


func test_away_from_every_group_there_is_no_cover() -> void:
	var world: InfiltrationWorld = _market()
	world.step(PlayerIntent.new())
	assert_int(world.crowd.cover.group).is_equal(-1)
	assert_str(world.crowd.cover.figure).is_empty()


func test_the_cover_weighs_a_guards_look() -> void:
	var crowd: InfiltrationCrowd = _market().crowd
	var seen := GuardPercept.new()
	seen.sight.certainty = 0.8
	crowd.cover = InfiltrationCrowd.Cover.new()
	crowd.weigh(seen)
	assert_float(seen.sight.certainty).is_equal(0.8)
	assert_str(seen.figure).is_empty()
	crowd.cover.group = 0
	crowd.cover.figure = InfiltrationCrowd.BLENDS_IN
	crowd.cover.reason = InfiltrationCrowd.IN_STEP
	crowd.cover.scale = float(crowd.spec["certainty_scale"][InfiltrationCrowd.BLENDS_IN])
	crowd.weigh(seen)
	assert_float(seen.sight.certainty).is_equal_approx(0.8 * crowd.cover.scale, 0.0001)
	assert_str(seen.figure).is_equal(InfiltrationCrowd.BLENDS_IN)
	var unseen := GuardPercept.new()
	crowd.weigh(unseen)
	assert_float(unseen.sight.certainty).is_equal(0.0)
	assert_str(unseen.figure).is_empty()
	var standing_out := GuardPercept.new()
	standing_out.sight.certainty = 0.9
	crowd.cover.scale = float(crowd.spec["certainty_scale"][InfiltrationCrowd.STANDS_OUT])
	crowd.weigh(standing_out)
	assert_float(standing_out.sight.certainty).is_equal(1.0)


# A suspicion that heard `kind` (none when "") and saw a figure reading
# `figure` (none when ""), both at the same place and moment.
func _suspicion(kind: String, figure: String) -> GuardSuspicion:
	var suspicion := GuardSuspicion.new()
	if kind != "":
		suspicion.notice_kind(kind, Vector2(5, 5), 1.0)
	if figure != "":
		suspicion.notice_figure(figure, Vector2(5, 5), 1.0)
	suspicion.reconsider(1.0)
	return suspicion


func test_the_figure_is_evidence_in_the_network() -> void:
	var threshold: float = SuspicionView.threshold(InfiltrationRules.actions())
	var nothing: float = _suspicion("", "").belief
	assert_float(_suspicion("", InfiltrationCrowd.BLENDS_IN).belief).is_less(nothing)
	var standing_out: GuardSuspicion = _suspicion("", InfiltrationCrowd.STANDS_OUT)
	assert_float(standing_out.belief).is_greater(nothing)
	assert_float(standing_out.belief).override_failure_message("a figure standing out alone sends a guard").is_less(threshold)
	assert_str(standing_out.lead).is_equal("figure")
	assert_vector(standing_out.lead_place()).is_equal(Vector2(5, 5))
	var noise: float = _suspicion("footstep", "").belief
	assert_float(noise).override_failure_message("a noise alone sends a guard").is_less(threshold)
	assert_float(_suspicion("footstep", InfiltrationCrowd.BLENDS_IN).belief).is_less(noise)
	assert_float(_suspicion("sprint", InfiltrationCrowd.STANDS_OUT).belief).is_greater_equal(threshold)


func test_the_figure_is_let_go_like_any_sign() -> void:
	var suspicion: GuardSuspicion = _suspicion("", InfiltrationCrowd.STANDS_OUT)
	var kept: float = suspicion.kept_for("figure")
	assert_str(str(suspicion.seen(1.0 + kept)["figure"])).is_equal(InfiltrationCrowd.STANDS_OUT)
	assert_bool(suspicion.seen(1.0 + kept + 0.1).has("figure")).is_false()
	var before: float = suspicion.belief
	suspicion.reconsider(1.0 + kept + 0.1)
	assert_float(suspicion.belief).is_less(before)
	assert_str(str(suspicion.last_change["by"])).is_equal("figure")
	assert_str(str(suspicion.last_change["seen"])).is_empty()


func test_with_no_crowd_the_figure_is_never_evidence() -> void:
	var world: InfiltrationWorld = InfiltrationWorld.make(InfiltrationLevel.read(InfiltrationLevel.WAREHOUSE), InfiltrationRules.read(), 1)
	var intent := PlayerIntent.new()
	intent.direction = Vector2(1, 0)
	for step: int in range(300):
		world.step(intent)
		for guard: InfiltrationGuard in world.guards:
			assert_bool(guard.suspicion.asked.has("figure")).is_false()
			assert_str(guard.percept.figure).is_empty()


func test_the_view_says_why() -> void:
	var world: InfiltrationWorld = _market()
	var guard: InfiltrationGuard = world.guard(0)
	var cover := InfiltrationCrowd.Cover.new()
	TranslationServer.set_locale("en")
	assert_str(SuspicionView.crowd_line(cover, guard)).is_equal("you: in no group; its eye -")
	cover.group = 1
	cover.reason = InfiltrationCrowd.IN_STEP
	guard.percept.sight.certainty = 0.25
	assert_str(SuspicionView.crowd_line(cover, guard)).is_equal("you: in group 2, ringed: walking in step; its eye 0.25")
	var suspicion: GuardSuspicion = _suspicion("", "")
	suspicion.notice_figure(InfiltrationCrowd.BLENDS_IN, Vector2(5, 5), 2.0)
	suspicion.reconsider(2.0)
	assert_str(SuspicionView.last_line(suspicion)).starts_with("last change: figure blends_in, ")
	TranslationServer.set_locale("pt_BR")
	assert_str(SuspicionView.crowd_line(cover, guard)).is_equal("você: no grupo 2, circulado: andando no passo; o olho dele 0.25")
	assert_str(SuspicionView.last_line(suspicion)).starts_with("última mudança: vulto se mistura, ")
