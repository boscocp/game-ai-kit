# T100's measurement, not a gate: a stand-in in the person's place -- bot 0,
# blue, driven by its own list like every bot, aiming with an error of its
# own -- at three skills, each over the same seeds with the model on and
# off. For each: the row the model settles on, how often it changed and
# turned back, the share the knob reads (the team's, since T123) and the
# stand-in's own, and the score difference its team ends with. Printed for
# docs/godot/botmatch.md.
#
#     ./scripts/godot --headless --path godot -s res://test/botmatch/player_model_measure.gd \
#         [-- 4.0 3.5 3.0 2.5 2.0] [band=0.45-0.55]
#
# The numbers after `--`, when given, replace the table's aim errors row by
# row, and `band=FROM-TO` its band, to measure another table without
# editing `rules.json`.
#
# Exit 0 when every match was played; 1 only when no match changed the row
# at all, which would mean nothing was measured.
extends SceneTree

## The stand-ins: how far off each aims, in degrees, against the team's 3.
const SKILLS: Dictionary = {"poor": 8.0, "even": 3.0, "sharp": 1.0}
const SEEDS: Array[int] = [1, 2, 3, 4, 5]
const PERSON: int = 0

## The rows' aim errors asked for on the command line, or none; and the
## band asked for, or none.
var _aims: PackedFloat64Array = PackedFloat64Array()
var _band: PackedFloat64Array = PackedFloat64Array()


func _init() -> void:
	for word: String in OS.get_cmdline_user_args():
		if word.begins_with("band="):
			_band = PackedFloat64Array(word.trim_prefix("band=").split_floats("-"))
		else:
			_aims.append(float(word))
	var changed_anywhere: int = 0
	print("stand-in | model | rows read, by seed (settled = the last) | changes | turns back | team share | own share | blue - red")
	for skill: String in SKILLS:
		for model_on: bool in [false, true]:
			var row: Dictionary = _measure(float(SKILLS[skill]), model_on)
			changed_anywhere += int(row["changes"]) if model_on else 0
			print(_line(skill, model_on, row))
	quit(0 if changed_anywhere > 0 else 1)


static func _line(skill: String, model_on: bool, row: Dictionary) -> String:
	return "%s | %s | %s | %d | %d | %.2f | %.2f | %+.0f" % [skill, "on" if model_on else "off", row["rows"],
			row["changes"], row["turns"], row["share"], row["own"], row["lead"]]


# Every seed at one skill, the model on or off: the rows each read, as
# 1-based row numbers, and the sums the table prints.
func _measure(degrees: float, model_on: bool) -> Dictionary:
	var rows: Array[String] = []
	var changes: int = 0
	var turns: int = 0
	var share: float = 0.0
	var own: float = 0.0
	var lead: float = 0.0
	for seed_value: int in SEEDS:
		var world: BotMatch = _played(seed_value, degrees, model_on)
		var read: Array[int] = world.difficulty.rows_read()
		changes += _changes(read)
		turns += _turns(read)
		rows.append("".join(read.map(func(index: int) -> String: return str(index + 1))))
		var prior: float = float(world.rules.difficulty["prior_points"])
		var model: PlayerModel = world.difficulty.model
		share += model.damage_share(prior)
		own += (float(model.dealt) + prior) / (float(model.dealt + model.taken) + 2.0 * prior)
		lead += world.score[BotMatch.BLUE] - world.score[BotMatch.RED]
	return {"rows": " ".join(rows), "changes": changes, "turns": turns, "share": share / SEEDS.size(),
			"own": own / SEEDS.size(), "lead": lead / SEEDS.size()}


# One whole match, the stand-in in bot 0's place. With the model off, the
# difficulty is still read -- the rows it would have set, and the
# stand-in's share -- but never answers: red keeps the knobs' aim.
func _played(seed_value: int, degrees: float, model_on: bool) -> BotMatch:
	var rules := MatchRules.new()
	for index: int in range(_aims.size()):
		rules.difficulty["rows"][index]["aim_error_degrees"] = _aims[index]
	if _band.size() == 2:
		rules.difficulty["band"] = {"from": _band[0], "to": _band[1]}
	var world := BotMatch.new(seed_value, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)
	world.bots[PERSON].own_aim_error = deg_to_rad(degrees)
	world.difficulty = MatchDifficulty.new(world)
	world.difficulty.answers = model_on
	world.seat_person(PERSON)
	return _play_out(world)


func _play_out(world: BotMatch) -> BotMatch:
	while not world.over():
		world.step()
	return world


static func _changes(read: Array[int]) -> int:
	var count: int = 0
	for index: int in range(1, read.size()):
		count += 1 if read[index] != read[index - 1] else 0
	return count


# How often the row turned back: up after down, or down after up.
static func _turns(read: Array[int]) -> int:
	var count: int = 0
	var last_way: int = 0
	for index: int in range(1, read.size()):
		var way: int = signi(read[index] - read[index - 1])
		if way != 0:
			count += 1 if last_way != 0 and way != last_way else 0
			last_way = way
	return count
