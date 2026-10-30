# T99: the bandit opponent measured, for the fighting page -- not a gate.
#
# Against each of T18's stand-in players and the owner's ghost (T40's frozen
# copy of the nine fights the owner recorded), the bandit opponent at medium
# and at hard plays `FIGHTS` fights, and so does T37's fixed opponent at the
# same level: the wins are put side by side. And for every bandit fight, how
# many pulls of its busiest situation's bandit passed before the arm it
# pulled most stopped changing -- when it settled on an answer.
#
#     make measure-bandit                   # at the opponent's constant, 0.5
#     make measure-bandit EXPLORATION=1.41  # at the textbook's
#
# The fights are lancer mirrors, the fixed or bandit side playing player one
# in half and player two in the other half, seeded by the fight's number, so
# a run is the same every time. A fight that reaches the time limit is won by
# the one with more health, as in `opponent_levels.gd`.
#
# Exit codes: 0 measured, 2 the frame data or the ghost could not be read.
extends SceneTree

const FIGHTS: int = 100
const TIME_LIMIT: int = 5940
const CHARACTER: String = "lancer"
const LEVELS: Array[String] = ["medium", "hard"]
const OPPONENTS: Array[String] = ["stand-in: rushdown", "stand-in: turtle", "stand-in: jumper", "ghost: nearest"]
const GHOST_PATH: String = "res://test/fighting/owner_ghost.json"


## A bandit opponent that writes down, for each situation, which arm led
## after every pull -- what "settled" is read from. It keeps it in memory,
## for this script to print.
class Watched extends FightBanditOpponent:
	var leaders: Dictionary = {}

	## As the opponent's, and then each bandit's leading arm, once a pull.
	func pay(seen: FightState, me: int) -> void:
		super(seen, me)
		for name: String in bandits:
			var bandit: Bandit = bandits[name]
			var history: Array = leaders.get_or_add(name, [])
			if bandit.total() > history.size():
				history.append(_leader(bandit))

	func _leader(bandit: Bandit) -> int:
		var best: int = 0
		for arm: int in range(bandit.arms()):
			if bandit.pulls[arm] > bandit.pulls[best]:
				best = arm
		return best


var _cloned: ClonedPlayer
## UCB1's constant for every bandit fight: the opponent's own, or the number
## given after `--` (`make measure-bandit EXPLORATION=1.41`).
var _exploration: float = FightBanditOpponent.EXPLORATION


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not arguments.is_empty() and arguments[0].is_valid_float():
		_exploration = arguments[0].to_float()
	quit(_run())


func _run() -> int:
	var data := FightData.read()
	_cloned = ClonedPlayer.load_from(GHOST_PATH)
	if data.refusal != "" or not _cloned.is_loaded():
		printerr("bandit_measure: cannot fight -- %s%s" % [data.refusal, _cloned.error])
		return 2
	print("UCB1's exploration constant: %.2f" % _exploration)
	print("against | level | fixed wins | bandit wins | settled after (median pulls) | its busiest situation's pulls (median)")
	for opponent: String in OPPONENTS:
		for level: String in LEVELS:
			_measure(opponent, level, data)
	return 0


func _measure(opponent: String, level: String, data: FightData) -> void:
	var fixed: int = 0
	var bandit: int = 0
	var settled: Array[int] = []
	var busiest: Array[int] = []
	for fight: int in range(FIGHTS):
		fixed += _won(FightOpponent.new(level, data, fight * 2), opponent, fight, data)
		var watched := Watched.new(level, data, fight * 2)
		watched.exploration = _exploration
		bandit += _won(watched, opponent, fight, data)
		var history: Array = _busiest(watched)
		busiest.append(history.size())
		settled.append(_settled_at(history))
	print("%s | %s | %d | %d | %d | %d" % [opponent, level, fixed, bandit, _median(settled), _median(busiest)])


## 1 when `player` wins its fight against `opponent`, else 0.
func _won(player: FightOpponent, opponent: String, fight: int, data: FightData) -> int:
	var side: int = fight % 2
	var players: Array[FightOpponent] = [player, _other(opponent, data, fight * 2 + 1)]
	if side == 1:
		players.reverse()
	var seats: Array[FightDelay] = [FightDelay.new(players[0], 0), FightDelay.new(players[1], 1)]
	var state: FightState = FightState.starting(data, CHARACTER, CHARACTER)
	while state.winner == FightState.NOBODY and state.frame < TIME_LIMIT:
		state = FightRules.step(state, [seats[0].input_for(state), seats[1].input_for(state)] as Array[int], data)
	var winner: int = state.winner
	if winner == FightState.NOBODY:
		var health: Array[int] = [state.fighters[0].health, state.fighters[1].health]
		winner = FightState.DRAW if health[0] == health[1] else (0 if health[0] > health[1] else 1)
	return 1 if winner == side else 0


func _other(name: String, data: FightData, chance_seed: int) -> FightOpponent:
	if name.begins_with("stand-in: "):
		return StandInPlayer.new(name.trim_prefix("stand-in: "), data, chance_seed)
	return FightCloneOpponent.new(name, _cloned, data, chance_seed)


# The leader history of the situation pulled most in the fight.
func _busiest(watched: Watched) -> Array:
	var longest: Array = []
	for name: String in watched.leaders:
		if watched.leaders[name].size() > longest.size():
			longest = watched.leaders[name]
	return longest


# The pull after which the leading arm never changed again.
func _settled_at(history: Array) -> int:
	var at: int = 0
	for pull: int in range(1, history.size()):
		if history[pull] != history[pull - 1]:
			at = pull + 1
	return at


func _median(numbers: Array[int]) -> int:
	var sorted: Array[int] = numbers.duplicate()
	sorted.sort()
	return sorted[int(sorted.size() / 2.0)] if not sorted.is_empty() else 0
