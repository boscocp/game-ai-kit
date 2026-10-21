# The half of portability a reading can hold: the code a driver decides
# with reaches nothing of a track. It reads a `RaceView3D` -- the road in its
# own frame -- and nothing else, so on another track there is nothing in it
# to be wrong. `racing3d_ladder.gd` holds the other half, by driving the
# kidney, a track nobody tuned it on.
#
# Read, not run: comments are taken out, then each file is searched for what
# would reach the world -- the track, the race, the cars, the physics, a
# position on the map. Each name is first shown a planted line it must
# catch.
extends GdUnitTestSuite

## Every script the decision runs: the driver, what it asks about traffic,
## what it sees, and the two techniques it takes from ai_steering.
const DECISION: Array[String] = [
	"res://game3d/racing/race_driver_3d.gd",
	"res://game3d/racing/race_traffic_3d.gd",
	"res://game3d/racing/race_view_3d.gd",
	"res://addons/ai_steering/pid_controller.gd",
	"res://addons/ai_steering/heat_line.gd",
]
## What a decision that knew its track, its race or its world would name.
const WORLD: Array[String] = [
	"RaceTrack3D", "Race3D", "RaceCar3D", "RaceSenses3D", "CarPhysics3D", "RaceGround3D",
	"tracks/", ".json", "Vector2(", "Vector3(", "global_position", "PhysicsServer3D",
	"get_tree", "get_node", "get_world_3d",
]


func test_the_decision_names_nothing_of_the_world() -> void:
	for path: String in DECISION:
		var found: Array[String] = reaches(_code(FileAccess.get_file_as_string(path)))
		assert_array(found).override_failure_message("%s reaches %s" % [path, found]).is_empty()


func test_every_name_is_caught_when_planted() -> void:
	for name: String in WORLD:
		var planted: String = "var hint: int = 0\nfunc decide() -> void:\n\tvar x = %s\n" % name
		assert_array(reaches(_code(planted))).contains([name])


func test_a_name_in_a_comment_is_not_reach() -> void:
	assert_array(reaches(_code("## Uses RaceTrack3D's line.\nvar speed: float = 0.0  # not Race3D\n"))).is_empty()


## The names of WORLD that `code` contains.
static func reaches(code: String) -> Array[String]:
	var found: Array[String] = []
	for name: String in WORLD:
		if name in code:
			found.append(name)
	return found


# `source` without its comments: whole comment lines, and what follows a
# `#` outside a string on the others.
static func _code(source: String) -> String:
	var kept: PackedStringArray = []
	for line: String in source.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("#"):
			continue
		var hash: int = line.find("#")
		var quoted: bool = hash > 0 and line.substr(0, hash).count("\"") % 2 == 1
		kept.append(line if hash < 0 or quoted else line.substr(0, hash))
	return "\n".join(kept)
