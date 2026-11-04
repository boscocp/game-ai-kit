# `make test-squad-match` (T85): the first enemy of the XCOM-style mode,
# `WeighedSquad`, against the floor, `RandomSquad`, in seeded matches from
# each seat. It must win at least 80 of every 100 in each, or it is not yet
# the baseline the searches of T87 and T88 are to be measured against.
#
# Match `n` of a seat is played on dice seed `n` with the random mover seeded
# `n`, so the table below is the same table every run, and a change to the
# rules, the weighing or the map that moves it moves it on purpose.
#
# Before the measurement, the gate is shown a case it must reject: the random
# mover in the weighed one's seat, which beats itself about half the time --
# a gate that passed it would pass anything.
#
#     ./scripts/godot --headless --path godot -s res://test/squad/squad_match_runner.gd -- [games] [wins]
#
# Exit codes: 0 the enemy won enough from both seats; 1 it did not, or the
# planted case passed; 2 the arguments could not be read.
extends SceneTree

const SEATS: Array[int] = [TacticalScenario.RED, TacticalScenario.BLUE]
## The planted case's games a seat: enough to see a coin is not 80%.
const PLANTED_GAMES: int = 20


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var games: int = int(arguments[0]) if arguments.size() > 0 else 100
	var wins: int = int(arguments[1]) if arguments.size() > 1 else 80
	if games <= 0 or wins <= 0 or wins > games:
		printerr("squad_match_runner: give the games a seat and the wins it needs, 0 < wins <= games")
		quit(2)
		return
	quit(_run(games, wins))


func _run(games: int, wins: int) -> int:
	var failures: Array[String] = []
	var planted: Dictionary = _seats("random", PLANTED_GAMES)
	if _passes(planted, ceili(PLANTED_GAMES * float(wins) / games)):
		failures.append("the planted case passed: the random mover won %s of %d a seat" % [planted, PLANTED_GAMES])
	var measured: Dictionary = _seats("weighed", games)
	for seat: int in SEATS:
		var row: Dictionary = measured[seat]
		print("weighed as %s: %d won, %d lost, %d drawn of %d; %d decision(s) refused" % [
			TacticalGame.SIDES[seat],
			row["won"], row["lost"], row["drawn"], games, row["refused"]])
		if row["won"] < wins:
			failures.append("weighed as %s won %d of %d; at least %d is the bar" % [TacticalGame.SIDES[seat], row["won"], games, wins])
	for failure: String in failures:
		print(failure)
	print("squad match: %d game(s) a seat, %d failure(s)" % [games, failures.size()])
	return 1 if not failures.is_empty() else 0


# Seat -> {won, lost, drawn, refused} for `row_name` against the random
# mover, `games` matches from each seat.
func _seats(row_name: String, games: int) -> Dictionary:
	var table: Dictionary = {}
	for seat: int in SEATS:
		var row: Dictionary = {"won": 0, "lost": 0, "drawn": 0, "refused": 0}
		for game: int in range(games):
			var tested: BlueController = SquadRoster.build(row_name, 1000 + game)
			var floor_mover := RandomSquad.new(game)
			var red: BlueController = tested if seat == TacticalScenario.RED else floor_mover
			var blue: BlueController = floor_mover if seat == TacticalScenario.RED else tested
			_count(row, SquadMatch.play(red, blue, game), seat)
		table[seat] = row
	return table


# One game's result written into `row`, for the side that played `seat`.
func _count(row: Dictionary, played: Dictionary, seat: int) -> void:
	row["refused"] += played["refused"]
	if played["winner"] == seat:
		row["won"] += 1
	elif played["winner"] == TacticalVictory.DRAW:
		row["drawn"] += 1
	else:
		row["lost"] += 1


func _passes(table: Dictionary, wins: int) -> bool:
	for seat: int in SEATS:
		if table[seat]["won"] < wins:
			return false
	return true
