# A reading of the code a driver decides with, for what would let it know
# its track. Read, not run, so it holds less than it might seem to: a
# decision could still be tuned to one track through its numbers, and no
# reading sees that. **The real defence of portability is the race on the
# kidney** (`racing3d_ladder.gd`), a track nobody tuned the driver on. This
# holds the half a reading can:
#
#   * the decision's files name, of all the project's global classes, only
#     an allow-list: what it sees (`RaceView3D`), its knobs (`RaceLevel3D`),
#     its traffic (`RaceTraffic3D`) and the two techniques it takes from
#     ai_steering (`PidController`, `HeatLine`) -- not the track, the race,
#     the cars, the senses or anything else a later wave adds;
#   * they use nothing that reaches the world by another door: the engine
#     singletons, `load` and `preload`, the scene tree's `get_*` accessors,
#     positions on the map (`Vector2(`, `Vector3(`), the input;
#   * they never read a level's `title`, so a level cannot be told apart by
#     its name;
#   * and no track's title or file name, read from `tracks/*.json` when the
#     test runs, appears in them, even in a string.
#
# Comments are taken out first. Each rule is shown a planted line it must
# catch, and an allowed class it must let through.
extends GdUnitTestSuite

## Every script the decision runs.
const DECISION: Array[String] = [
	"res://game3d/racing/race_driver_3d.gd",
	"res://game3d/racing/race_traffic_3d.gd",
	"res://game3d/racing/race_view_3d.gd",
	"res://addons/ai_steering/pid_controller.gd",
	"res://addons/ai_steering/heat_line.gd",
]
## The global classes those scripts may name.
const ALLOWED: Array[String] = ["RaceDriver3D", "RaceView3D", "RaceLevel3D", "RaceTraffic3D", "PidController", "HeatLine"]
## What reaches the world without naming a class of this project.
const DOORS: Array[String] = [
	"Engine.", "load(", "preload(", "get_tree", "get_node", "get_parent", "get_viewport", "get_window",
	"get_world_3d", "Vector2(", "Vector3(", "Input.", "PhysicsServer3D", "ProjectSettings", ".title",
]
const TRACKS: String = "res://game3d/racing/tracks/"


func test_the_decision_reaches_nothing_of_the_world() -> void:
	var forbidden: Array[String] = forbidden_words()
	for path: String in DECISION:
		var found: Array[String] = reaches(_code(FileAccess.get_file_as_string(path)), forbidden)
		assert_array(found).override_failure_message("%s reaches %s" % [path, found]).is_empty()


func test_the_track_names_are_read_from_the_tracks() -> void:
	var forbidden: Array[String] = forbidden_words()
	assert_array(forbidden).contains(["The loop", "the_loop", "The kidney", "the_kidney"])


func test_every_door_and_every_other_class_is_caught_when_planted() -> void:
	var forbidden: Array[String] = forbidden_words()
	var planted: Array[String] = ["RaceTrack3D", "Race3D", "RaceCar3D", "RaceSenses3D", "AssetShelf", "the_kidney"]
	planted.append_array(DOORS)
	for word: String in planted:
		var line: String = "func decide() -> void:\n\tvar hint = \"%s\" if true else %s\n" % [word, word]
		assert_array(reaches(_code(line), forbidden)).override_failure_message("missed %s" % word).is_not_empty()


func test_an_allowed_class_and_a_comment_are_let_through() -> void:
	var forbidden: Array[String] = forbidden_words()
	assert_array(reaches(_code("var line := HeatLine.new()\nvar seen: RaceView3D\n"), forbidden)).is_empty()
	assert_array(reaches(_code("## Uses RaceTrack3D's line.\nvar speed: float = 0.0  # not Race3D\n"), forbidden)).is_empty()


## Every word the decision may not contain: each global class of the
## project not in ALLOWED, every door, and every track's title and file
## name.
static func forbidden_words() -> Array[String]:
	var words: Array[String] = []
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		var name: String = str(entry["class"])
		if not (name in ALLOWED):
			words.append(name)
	words.append_array(DOORS)
	for file: String in DirAccess.get_files_at(TRACKS):
		words.append_array(_track_names(file))
	return words


# A track file's name and its title; nothing for a file that is not one.
static func _track_names(file: String) -> Array[String]:
	if not file.ends_with(".json"):
		return []
	var track: Variant = JSON.parse_string(FileAccess.get_file_as_string(TRACKS + file))
	var names: Array[String] = [file.get_basename()]
	if track is Dictionary:
		names.append(str(track["title"]))
	return names


## The words of `forbidden` that `code` contains: a class or a track name as
## a whole word, a door anywhere.
static func reaches(code: String, forbidden: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for word: String in forbidden:
		var door: bool = word in DOORS
		if (door and word in code) or (not door and _whole_word(code, word)):
			found.append(word)
	return found


static func _whole_word(code: String, word: String) -> bool:
	var pattern := RegEx.create_from_string("(?<![A-Za-z0-9_])" + _escaped(word) + "(?![A-Za-z0-9_])")
	return pattern.search(code) != null


static func _escaped(word: String) -> String:
	var escaped: String = ""
	for character: String in word:
		escaped += ("\\" + character) if character in ".()[]{}*+?^$|\\" else character
	return escaped


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
