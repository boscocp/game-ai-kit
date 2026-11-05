# `make measure-squad-mcts` (T87): the enemy that searches, `MctsSquad`,
# against the first enemy that weighs, `WeighedSquad`, in seeded matches
# from each seat -- and what the search costs: the time a decision takes,
# and the worst frame.
#
# Each decision is searched as the scene searches it: one frame's
# iterations when it is asked, then the rest a frame at a time
# (`MctsSquad.keep_thinking`), each frame timed. A frame is one of those
# calls; a decision is all of them together. The times are this machine's,
# under whatever else it is doing, which is why this is a measurement and
# not a gate: `docs/godot/squad.md` keeps what it printed, with the date.
#
# Match `n` of a seat is played on dice seed `n`, the searcher seeded
# `1000 + n`, as `make test-squad-match` seats its own.
#
#     ./scripts/godot --headless --path godot -s res://test/squad/squad_mcts_measure.gd -- iterations [games] [first]
#
# It prints one line a game, and a summary for each seat over the games it
# played; `first` lets several of it share the games out. Exit codes: 0
# measured; 2 the arguments could not be read.
extends SceneTree

const SEATS: Array[int] = [TacticalScenario.RED, TacticalScenario.BLUE]

# This seat's frames and decisions, in microseconds, while a game is on.
var _frames: Array[int] = []
var _decisions: Array[int] = []
var _last_usec: int = 0


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var iterations: int = int(arguments[0]) if arguments.size() > 0 else 0
	var games: int = int(arguments[1]) if arguments.size() > 1 else 100
	var first: int = int(arguments[2]) if arguments.size() > 2 else 0
	if iterations <= 0 or games <= 0 or first < 0:
		printerr("squad_mcts_measure: give the iterations a decision, the games a seat, and the first game's number")
		quit(2)
		return
	for seat: int in SEATS:
		_summarise(seat, iterations, _seat(seat, iterations, games, first))
	quit(0)


# One row a game for `seat`: who won, and the frames and decisions it took.
func _seat(seat: int, iterations: int, games: int, first: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for game: int in range(first, first + games):
		var searcher := MctsSquad.new(1000 + game, iterations)
		searcher.spread_over_frames()
		var weighing := WeighedSquad.new(game)
		var red: BlueController = searcher if seat == TacticalScenario.RED else weighing
		var blue: BlueController = weighing if seat == TacticalScenario.RED else searcher
		_frames.clear()
		_decisions.clear()
		_last_usec = Time.get_ticks_usec()
		var played: Dictionary = SquadMatch.play(red, blue, game, _think.bind(searcher))
		var row: Dictionary = {"game": game, "seat": TacticalGame.SIDES[seat], "winner": played["winner"],
			"won": played["winner"] == seat, "drawn": played["winner"] == TacticalVictory.DRAW,
			"decisions": _decisions.size(), "decision usec": _decisions.duplicate(), "worst frame usec": _max(_frames),
			"frames": _frames.size(), "lost actions": played["lost"][seat]}
		print(JSON.stringify(row.merged({"decision usec": _max(_decisions)}, true)))
		rows.append(row)
	return rows


# After `controller` was asked a decision: when it is the searcher, the time
# since the last call is the frame that asked it, and the rest of its search
# is run a frame at a time, each timed.
func _think(controller: BlueController, searcher: MctsSquad) -> void:
	if controller != searcher:
		_last_usec = Time.get_ticks_usec()
		return
	var decision: int = Time.get_ticks_usec() - _last_usec
	_frames.append(decision)
	var started: int = Time.get_ticks_usec()
	while searcher.keep_thinking():
		var frame: int = Time.get_ticks_usec() - started
		_frames.append(frame)
		decision += frame
		started = Time.get_ticks_usec()
	_decisions.append(decision)
	_last_usec = Time.get_ticks_usec()


func _summarise(seat: int, iterations: int, rows: Array[Dictionary]) -> void:
	var won: int = rows.filter(func(row: Dictionary) -> bool: return row["won"]).size()
	var drawn: int = rows.filter(func(row: Dictionary) -> bool: return row["drawn"]).size()
	var times: Array[int] = []
	var worst_frame: int = 0
	for row: Dictionary in rows:
		times.append_array(row["decision usec"])
		worst_frame = maxi(worst_frame, row["worst frame usec"])
	print("mcts %d iterations as %s against weighed: %d won, %d lost, %d drawn of %d; a decision %d ms on average, %d ms at most; worst frame %d ms" % [
		iterations, TacticalGame.SIDES[seat], won, rows.size() - won - drawn, drawn, rows.size(), _mean(times) / 1000,
		_max(times) / 1000, worst_frame / 1000])


static func _max(values: Array[int]) -> int:
	var most: int = 0
	for value: int in values:
		most = maxi(most, value)
	return most


static func _mean(values: Array[int]) -> int:
	if values.is_empty():
		return 0
	var total: int = 0
	for value: int in values:
		total += value
	return total / values.size()
