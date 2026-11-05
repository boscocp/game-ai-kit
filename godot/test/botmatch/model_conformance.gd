## One player model vector against Godot's `PlayerModel` (T100): the
## events replayed through the bot match's table, and the first reading
## that differs from the vector's. Shared by the runner and the suite; it is
## handed the vectors, and reads no file (N14).
class_name ModelConformance
extends RefCounted

## As near as a share must come: the file writes Python's doubles in full,
## and both sides do the same arithmetic.
const CLOSE: float = 1e-12


## What differs between the model and `vector`, at the first reading it
## does, through `rules`' table; nothing when they agree.
static func check_vector(file: String, vector: Dictionary, rules: MatchRules) -> Array[String]:
	var interval_steps: int = roundi(float(rules.difficulty["interval"]) / rules.step)
	var found: Array[Dictionary] = PlayerModel.replay(rules.difficulty, vector["events"], int(vector["last_step"]),
			interval_steps)
	var wanted: Array = vector["readings"]
	if found.size() != wanted.size():
		return ["%s: %d reading(s), the vector has %d" % [file, found.size(), wanted.size()]]
	for index: int in range(found.size()):
		var differs: String = _reading_differs(found[index], wanted[index])
		if differs != "":
			return ["%s: step %d -- %s" % [file, int(wanted[index]["step"]), differs]]
	return []


static func _reading_differs(found: Dictionary, wanted: Dictionary) -> String:
	if int(found["step"]) != int(wanted["step"]):
		return "read at step %d" % found["step"]
	for count: String in wanted["counts"]:
		if int(found["counts"][count]) != int(wanted["counts"][count]):
			return "%s %d, the vector %d" % [count, found["counts"][count], wanted["counts"][count]]
	for share: String in ["share", "hit_rate"]:
		if absf(float(found[share]) - float(wanted[share])) > CLOSE:
			return "%s %.15f, the vector %.15f" % [share, found[share], wanted[share]]
	if int(found["row"]) != int(wanted["row"]) or float(found["aim_error_degrees"]) != float(wanted["aim_error_degrees"]):
		return "row %d (%.1f degrees), the vector %d" % [found["row"], found["aim_error_degrees"], wanted["row"]]
	if bool(found["held"]) != bool(wanted["held"]):
		return "held %s, the vector %s" % [found["held"], wanted["held"]]
	return ""
