# T80: the infiltration level shows its identifiers through
# `InfiltrationWords`, which lists every one so the table holds it, and
# translates the eye's reasons the perception addon writes in English by
# copying their shapes. Both copies can drift: every name the data writes
# must be listed, and every reason the addon writes must match a shape.
extends GdUnitTestSuite

var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_every_name_the_level_can_show_is_listed() -> void:
	var names: Array[String] = []
	var actions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(InfiltrationRules.ACTIONS))
	for row: Dictionary in actions["actions"]:
		names.append(str(row["name"]))
	var types: Dictionary = GuardType.read_file()
	names.append_array(types["guards"].keys())
	names.append_array(types["events"].keys())
	for guard: Dictionary in types["guards"].values():
		for phase: Dictionary in guard["awareness"]["phases"]:
			names.append(str(phase["name"]))
		for zone: Dictionary in guard["vision"]["zones"]:
			names.append(str(zone["name"]))
	names.append_array(InfiltrationRules.read().stances.keys())
	names.append_array([RoleArbiter.SHOOTER, RoleArbiter.FLANKER, "sight", "body"])
	assert_int(names.size()).override_failure_message("read no name from the data").is_greater_equal(30)
	for name: String in names:
		var listed: bool = name in InfiltrationWords.SHOWN or InfiltrationWords.SAID_AS.has(name)
		assert_bool(listed).override_failure_message("\"%s\" is shown but not in InfiltrationWords" % name).is_true()


func test_every_reason_the_eye_writes_reads_in_portuguese() -> void:
	TranslationServer.set_locale("pt_BR")
	var row: Dictionary = GuardType.read_file()["guards"]["patrol"]["vision"]
	var shape: VisionShape = VisionShape.from_row(row)
	var reasons: Array[String] = [
		shape.percept(100.0, 0.0, [true, true, true] as Array[bool], 1, 1.0, false, 0.0).why,
		shape.percept(3.0, 0.0, [false, false, true] as Array[bool], 2, 1.0, false, 0.0).why,
		shape.percept(3.0, 0.0, [true, true, true] as Array[bool], 1, 1.0, false, 0.0).why,
	]
	assert_str(reasons[0]).is_equal("outside every zone")
	assert_int(reasons.size()).override_failure_message("the eye writes a reason this test does not make").is_equal(
		_reasons_in_the_addon())
	for zone: Dictionary in row["zones"]:
		reasons.append("in " + str(zone["name"]))
	for reason: String in reasons:
		assert_str(InfiltrationWords.eye(reason)).override_failure_message(
			"no shape in InfiltrationWords for the eye's \"%s\"" % reason).is_not_equal(reason)
	assert_str(InfiltrationWords.eye(reasons[2])).is_equal("na zona à frente")


# How many reasons `VisionShape.percept` can write, read from its source: a
# new one is a reason with no shape until this test makes it.
static func _reasons_in_the_addon() -> int:
	var source: String = FileAccess.get_file_as_string("res://addons/ai_perception/vision_shape.gd")
	return RegEx.create_from_string("seen\\.why = \"").search_all(source).size()


func test_in_english_the_reasons_and_names_are_left_as_written() -> void:
	TranslationServer.set_locale("en")

	assert_str(InfiltrationWords.eye("in ahead")).is_equal("in ahead")
	assert_str(InfiltrationWords.word("raise the alarm")).is_equal("raise the alarm")
	assert_str(InfiltrationWords.level("generated 7")).is_equal("generated level 7")
