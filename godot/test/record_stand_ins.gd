# T18: record the stand-in players' fights, so the cloning pipeline has
# something to learn from before a person has been recorded.
#
#     ./scripts/godot --headless --path godot -s res://test/record_stand_ins.gd -- /absolute/path/to/data/fights
#
# Each stand-in plays `FIGHTS` fights as player one against the fixed
# opponent at medium, behind the same reaction-time seat, every pairing of
# characters in turn. Seeded, so running it again writes the same files. A
# recording is the input log alone, as the scene writes a person's.
#
# Exit codes: 0 written, 2 the frame data could not be read or no folder given.
extends SceneTree

const FIGHTS: int = 8
## 99 seconds at 60 frames a second, as the levels are measured.
const TIME_LIMIT: int = 5940


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("record_stand_ins: give me the recordings folder after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(folder: String) -> int:
	var data := FightData.read()
	if data.refusal != "":
		printerr("record_stand_ins: the frame data was refused: %s" % data.refusal)
		return 2
	var names: Array[String] = data.character_names()
	for habit: String in StandInPlayer.HABITS:
		for fight: int in range(FIGHTS):
			record(habit, fight, names, folder, data)
	return 0


## Fight `fight` of stand-in `habit`, kept in `folder` under a name that says whose it is.
func record(habit: String, fight: int, names: Array[String], folder: String, data: FightData) -> void:
	var characters: Array[String] = [names[fight % 2], names[(fight / 2) % 2]]
	var inputs: Array = fight_log(habit, characters, fight, data)
	var name: String = "stand-in-%s-%d" % [habit, fight + 1]
	var path: String = FightRecording.save(inputs, characters, "opponent: medium", "stand-in: " + habit, folder, name)
	print("%s: %d frames -> %s" % [name, inputs.size(), path if path != "" else "too short, not kept"])


## One fight's input log: stand-in `habit` as player one against the fixed
## medium opponent, both seated behind their reaction time.
func fight_log(habit: String, characters: Array[String], fight: int, data: FightData) -> Array:
	var seats: Array[FightDelay] = [FightDelay.new(StandInPlayer.new(habit, data, fight * 2), 0),
			FightDelay.new(FightOpponent.new("medium", data, fight * 2 + 1), 1)]
	var state: FightState = FightState.starting(data, characters[0], characters[1])
	var inputs: Array = []
	while state.winner == FightState.NOBODY and state.frame < TIME_LIMIT:
		var pair: Array[int] = [seats[0].input_for(state), seats[1].input_for(state)]
		inputs.append([pair[0], pair[1]])
		state = FightRules.step(state, pair, data)
	return inputs
