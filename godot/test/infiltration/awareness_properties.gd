# T69's properties: what a guard perceives, how aware it grows and what it
# knows, held over seeded generated levels, every guard type in
# guard_types.json, and the honest techniques -- each claim first shown a
# planted case it must reject (invariant 4):
#
#   1. nothing known that was not perceived -- planted: an update that
#      reads where the target really is;
#   2. awareness follows exposure, and the rate's rules leave no hole --
#      planted: the light input inverted;
#   3. the phases follow the thresholds -- planted: a threshold read from
#      the wrong row;
#   4. sound goes round, not through -- planted: Euclidean distance;
#   5. off-screen halving only lowers -- planted: a factor above 1;
#   6. the belief is honest -- planted: diffusion through a wall;
#   7. portable: every claim runs on generated levels; no guard type's row
#      names a cell, and a noise posted at a cell of one level is broken by
#      them -- planted: a row with a `post_cell`, for each half.
#
# Engine errors are counted (`PerceptionErrors`): a SCRIPT ERROR aborts the
# function it is in and the script would still print "0 failure(s)".
#
#     ./scripts/godot --headless --path godot -s res://test/infiltration/awareness_properties.gd
#
# Exit codes: 0 every claim held and every planted case was caught; 1 not.
extends SceneTree

const SEEDS: int = 150

var _errors := PerceptionErrors.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	var failures: Array[String] = []
	var counter: String = _errors.self_check()
	if counter != "":
		failures.append(counter)
	var data: Dictionary = GuardType.read_file()
	var types: Dictionary[String, GuardType] = GuardType.all_in(data)
	if types.size() < 2:
		failures.append("guard_types.json gives %d guard type(s); the claims need at least two" % types.size())
	else:
		failures.append_array(_every_claim(types, data))
	if _errors.count > 0:
		failures.append("%d engine error(s) during the claims" % _errors.count)
	for failure: String in failures:
		print(failure)
	print("awareness properties: %d failure(s)" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _every_claim(types: Dictionary[String, GuardType], data: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var other: Dictionary[String, String] = _another_type(types)
	for type_name: String in types:
		var type: GuardType = types[type_name]
		failures.append_array(_pair("%s: nothing known not perceived" % type_name,
			KnowledgeClaims.knows_only_perceived(type, KnowledgeClaims.honest_update, SEEDS),
			KnowledgeClaims.knows_only_perceived(type, KnowledgeClaims.cheating_update, SEEDS)))
		failures.append_array(_pair("%s: awareness follows exposure" % type_name,
			SensesClaims.follows_exposure(type, func(light: float) -> float: return light) + SensesClaims.rate_has_no_hole(type),
			SensesClaims.follows_exposure(type, func(light: float) -> float: return 1.0 - light)))
		var wrong_row: Dictionary = types[other[type_name]].awareness
		failures.append_array(_pair("%s: phases follow the thresholds" % type_name,
			KnowledgeClaims.phases_follow(type.awareness, Awareness.phase),
			KnowledgeClaims.phases_follow(type.awareness, func(number: float, _row: Dictionary) -> int: return Awareness.phase(number, wrong_row))))
	failures.append_array(_sound_claims(types, data))
	failures.append_array(_pair("the belief is honest", BeliefClaims.is_honest(BeliefClaims.honest_step, SEEDS),
		BeliefClaims.is_honest(BeliefClaims.through_a_wall, SEEDS)))
	return failures


func _sound_claims(types: Dictionary[String, GuardType], data: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_pair("sound goes round, not through",
		SoundClaims.goes_round(SoundClaims.along_the_level, SoundClaims.anywhere, SEEDS),
		SoundClaims.goes_round(SoundClaims.through_walls, SoundClaims.anywhere, SEEDS)))
	failures.append_array(_pair("off-screen halving only lowers",
		SoundClaims.halving_only_lowers(types, PathHearing.loudness, SEEDS),
		SoundClaims.halving_only_lowers(types, SoundClaims.amplified, SEEDS)))
	var planted_row: Dictionary = (data["guards"].values()[0] as Dictionary).duplicate(true)
	planted_row["post_cell"] = [7, 3]
	var post := Vector2i(int(planted_row["post_cell"][0]), int(planted_row["post_cell"][1]))
	failures.append_array(_pair("portable: no guard type names a cell",
		_rows_name_no_cell(data["guards"]), _rows_name_no_cell({"planted": planted_row})))
	failures.append_array(_pair("portable: generated levels break a noise posted on one",
		SoundClaims.goes_round(SoundClaims.along_the_level, SoundClaims.anywhere, SEEDS),
		SoundClaims.goes_round(SoundClaims.along_the_level, func(_level: GridGraph, _rng: RandomNumberGenerator) -> Vector2i: return post, SEEDS)))
	return failures


# A claim held: no findings for the honest run, at least one for the planted.
func _pair(claim: String, honest: Array[String], planted: Array[String]) -> Array[String]:
	print("%s: %s; planted %s" % [claim, "holds" if honest.is_empty() else "FAILS", "caught" if not planted.is_empty() else "NOT CAUGHT"])
	var failures: Array[String] = []
	for finding: String in honest:
		failures.append("%s: %s" % [claim, finding])
	if planted.is_empty():
		failures.append("%s: the planted case passed" % claim)
	return failures


# Every row's key that names a place on one level -- a cell, a position --
# is a finding: a guard type must cope on any level. It matches by name
# only (`*cell`, `*position`, `*place`): a key called "spawn": [7, 3] would
# pass it, and only the generated levels would catch that one.
func _rows_name_no_cell(rows: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for type_name: String in rows:
		for key: String in _keys_naming_a_place(rows[type_name]):
			found.append("guard type %s names a place on one level: %s" % [type_name, key])
	return found


func _keys_naming_a_place(row: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key: String in row:
		if key.ends_with("cell") or key.ends_with("position") or key.ends_with("place"):
			keys.append(key)
	return keys


# Each type paired with another one, whose row is the wrong one to read.
func _another_type(types: Dictionary[String, GuardType]) -> Dictionary[String, String]:
	var names: Array = types.keys()
	var pairs: Dictionary[String, String] = {}
	for index: int in range(names.size()):
		pairs[names[index]] = names[(index + 1) % names.size()]
	return pairs
