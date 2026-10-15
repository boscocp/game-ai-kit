# T18: how often each way of playing like the recorded player beats the
# fixed opponent at medium -- the win-rate column of `compare.py --report`.
#
#     ./scripts/godot --headless --path godot -s res://test/clone_fights.gd -- /absolute/path/to/data/cloning/win_rates.json
#
# Each mode in `MODES` plays `FIGHTS` seeded fights against the fixed
# opponent at medium: half as player one, half as player two, half of them
# as each character, mirrored, as T37's levels are measured. The n-gram is
# T17's learner at medium -- it answers the player rather than imitating
# one, which is the other thing a model of a player can be for. The fixed
# opponent against itself is the reference row: near half -- a draw is no
# win, so a little under -- or the measure leans on the side or the seed.
# When the recorded player is a stand-in, the stand-in itself plays too: a
# copy is measured against what it copies, and only a person cannot be
# seated here.
#
# The file it writes names the sha256 of the clone weights it fought with,
# so `compare.py` can refuse numbers measured on another file.
#
# Exit codes: 0 written; 1 the reference row was not near half; 2 the frame
# data or the cloned player could not be read, or no path was given.
extends SceneTree

const FIGHTS: int = 100
const TIME_LIMIT: int = 5940
## The reference must win between these many of `FIGHTS`, or the measure is
## leaning on something other than the opponent.
const FAIR: Array[int] = [30, 70]
const MODES: Array[String] = ["opponent: medium", "learner: medium", "ghost: exact", "ghost: nearest", "clone"]
## How a stand-in's recordings name their player.
const STAND_IN: String = "stand-in: "


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("clone_fights: give me the win rates file after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(path: String) -> int:
	var data := FightData.read()
	var cloned: ClonedPlayer = ClonedPlayer.load_from()
	if data.refusal != "" or not cloned.is_loaded():
		printerr("clone_fights: cannot fight -- %s%s" % [data.refusal, cloned.error])
		return 2
	var wins: Dictionary = {}
	var modes: Array[String] = MODES.duplicate()
	if str(cloned.trained_on["player"]).begins_with(STAND_IN):
		modes.append(cloned.trained_on["player"])
	for mode: String in modes:
		wins[mode] = wins_of(mode, cloned, data)
		print("%s beats the fixed opponent at medium %d of %d" % [mode, wins[mode], FIGHTS])
	if not WinRateFile.write(path, FileAccess.get_sha256(ClonedPlayer.DEFAULT_PATH), FIGHTS, wins):
		printerr("clone_fights: cannot write %s" % path)
		return 2
	var reference: int = wins["opponent: medium"]
	var fair: bool = reference >= FAIR[0] and reference <= FAIR[1]
	print("%s: the reference won %d, and must be between %d and %d" % ["ok" if fair else "FAIL", reference, FAIR[0],
			FAIR[1]])
	return 0 if fair else 1


## How many of `FIGHTS` the opponent `mode` wins against the fixed one at medium.
func wins_of(mode: String, cloned: ClonedPlayer, data: FightData) -> int:
	var won: int = 0
	var names: Array[String] = data.character_names()
	for fight: int in range(FIGHTS):
		var side: int = fight % 2
		var character: String = names[(fight / 2) % names.size()]
		var fixed := FightOpponent.new("medium", data, fight * 2 + 1 - side)
		var players: Array[FightOpponent] = [opponent_for(mode, cloned, data, fight * 2 + side), fixed]
		if side == 1:
			players.reverse()
		if winner_of(players, character, data) == side:
			won += 1
	return won


## The opponent a mode names, as the scene seats it.
func opponent_for(mode: String, cloned: ClonedPlayer, data: FightData, chance_seed: int) -> FightOpponent:
	if mode.begins_with(FightingExample.LEARNER_MODE):
		return FightModelOpponent.new(mode.trim_prefix(FightingExample.LEARNER_MODE), data, chance_seed)
	if mode in FightCloneOpponent.SOURCES:
		return FightCloneOpponent.new(mode, cloned, data, chance_seed)
	if mode.begins_with(STAND_IN):
		return StandInPlayer.new(mode.trim_prefix(STAND_IN), data, chance_seed)
	return FightOpponent.new(mode.trim_prefix(FightingExample.OPPONENT_MODE), data, chance_seed)


## Who wins one mirror fight of `character`: 0, 1 or `FightState.DRAW`, on
## health at the time limit.
func winner_of(players: Array[FightOpponent], character: String, data: FightData) -> int:
	var seats: Array[FightDelay] = [FightDelay.new(players[0], 0), FightDelay.new(players[1], 1)]
	var state: FightState = FightState.starting(data, character, character)
	while state.winner == FightState.NOBODY and state.frame < TIME_LIMIT:
		state = FightRules.step(state, [seats[0].input_for(state), seats[1].input_for(state)] as Array[int], data)
	if state.winner != FightState.NOBODY:
		return state.winner
	var health: Array[int] = [state.fighters[0].health, state.fighters[1].health]
	return FightState.DRAW if health[0] == health[1] else (0 if health[0] > health[1] else 1)
