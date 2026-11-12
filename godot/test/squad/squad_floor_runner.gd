# `make test-squad-floor` (T125): the first enemy of the XCOM-style mode,
# `WeighedSquad`, against a second, stronger floor, `GreedySquad` -- a
# careless player that takes the best shot it has and otherwise walks
# straight at the nearest enemy it knows of, cover never weighed.
#
# `make test-squad-match` holds the weighed enemy above `RandomSquad`, which
# it beats 100 games of 100 whatever its weighing: that gate cannot tell a
# good weighing from a worse one. This one must. So before the measurement
# it is shown a planted weighing known to be worse -- the weighed enemy with
# cover weighed at zero, `CoverBlind` below, which still beats the random
# mover -- and the planted weighing must fall short of the bar, while still
# winning more than the even line, 100 of 200: worse than the weighing, not
# broken into something weaker than a careless player's equal.
#
# The bar counts both seats together. The seat moves the result more than
# the weighing does: the greedy shooter against itself wins 26 of 100 as red
# and 74 as blue, so one bar a seat would have to sit at two places at once.
# Over both seats the mirror is 100 of 200, and that is the even line the
# weighing has to clear.
#
# Measured in wave 192, 100 matches a seat: the weighed enemy 49 as red and
# 88 as blue, 137 of 200; the planted weighing 42 and 70, 112. Its review
# played four more seed sets (seeds offset by 100 to 400): over the five,
# the weighed enemy wins 132 to 141, the plant 107 to 112. The bar, 122, is
# 10 clear of both worst cases -- a floor, not a target. A change that
# reshuffles the dice draws a new sample: a weighed enemy at 124 is read as
# one before it is read as a regression.
# Match `n` of a seat is played on dice seed `n`, the weighed enemy built
# with `1000 + n` as `make test-squad-match` builds it, so the table is the
# same every run; the greedy shooter has no dice of its own.
#
#     ./scripts/godot --headless --path godot -s res://test/squad/squad_floor_runner.gd -- [games] [wins] [planted games]
#
# `wins` is out of twice `games`, both seats together; the planted weighing
# is held to the same share of its own games. Exit codes: 0 the enemy won
# enough and the planted weighing did not; 1 otherwise; 2 the arguments
# could not be read.
extends SceneTree

const SEATS: Array[int] = [TacticalScenario.RED, TacticalScenario.BLUE]


## The weighed enemy with cover weighed at zero: it reads the danger of a
## cell as if no tree or rock stood between it and the enemies, so a cell in
## full cover is no safer than the open. The planted worse weighing.
class CoverBlind extends WeighedSquad:
	func _danger_at(rows: Array[String], seen: SideView, unit: Unit, cell: Vector2i) -> float:
		var danger: float = 0.0
		var defence: int = SquadTable.number(unit.type.type_name, "defence")
		for enemy: Unit in seen.state.units:
			if enemy.faction == seen.side or not SquadCombat.reaches(rows, enemy.cell, enemy.type, cell):
				continue
			var chance: int = SquadCombat.hit_chance(SquadTable.number(enemy.type.type_name, "aim"), defence, 0)
			danger += chance / 100.0 * SquadTable.number(enemy.type.type_name, "damage")
		return danger


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var games: int = int(arguments[0]) if arguments.size() > 0 else 100
	var wins: int = int(arguments[1]) if arguments.size() > 1 else 122
	var planted_games: int = int(arguments[2]) if arguments.size() > 2 else games
	if games <= 0 or wins <= 0 or wins > games * SEATS.size() or planted_games <= 0:
		printerr("squad_floor_runner: give the games a seat, the wins it needs of both seats' games, and the planted case's games a seat")
		quit(2)
		return
	quit(_run(games, wins, planted_games))


func _run(games: int, wins: int, planted_games: int) -> int:
	var failures: Array[String] = []
	var planted_bar: int = ceili(planted_games * float(wins) / games)
	var planted: Dictionary = _seats(func(seed_number: int) -> BlueController: return CoverBlind.new(seed_number), planted_games)
	_print("planted, cover weighed at zero", planted, planted_games)
	# Load-bearing (invariant 4): without these two the gate passes any
	# weighing that clears the bar, and nothing else shows its teeth.
	if _won(planted) >= planted_bar:
		failures.append("the planted weighing passed: it won %d of %d, the bar is %d" % [
			_won(planted), planted_games * SEATS.size(), planted_bar])
	if _won(planted) <= planted_games:
		failures.append("the planted weighing won %d of %d, no more than the even line: it is broken, not worse" % [
			_won(planted), planted_games * SEATS.size()])
	var measured: Dictionary = _seats(func(seed_number: int) -> BlueController: return WeighedSquad.new(seed_number), games)
	_print("weighed", measured, games)
	if _won(measured) < wins:
		failures.append("weighed won %d of %d; at least %d is the bar" % [_won(measured), games * SEATS.size(), wins])
	for seat: int in SEATS:
		if measured[seat]["actions lost"] > 0:
			failures.append("weighed as %s lost %d action(s) to a refused walk" % [TacticalGame.SIDES[seat], measured[seat]["actions lost"]])
	for failure: String in failures:
		print(failure)
	print("squad floor: %d game(s) a seat, %d failure(s)" % [games, failures.size()])
	return 1 if not failures.is_empty() else 0


# Seat -> {won, lost, drawn, actions lost} for the controllers `make` builds,
# against the greedy shooter, `games` matches from each seat.
func _seats(make: Callable, games: int) -> Dictionary:
	var table: Dictionary = {}
	for seat: int in SEATS:
		var row: Dictionary = {"won": 0, "lost": 0, "drawn": 0, "actions lost": 0}
		for game: int in range(games):
			var tested: BlueController = make.call(1000 + game)
			var greedy := GreedySquad.new()
			var red: BlueController = tested if seat == TacticalScenario.RED else greedy
			var blue: BlueController = greedy if seat == TacticalScenario.RED else tested
			_count(row, SquadMatch.play(red, blue, game), seat)
		table[seat] = row
	return table


# One game's result written into `row`, for the side that played `seat`.
func _count(row: Dictionary, played: Dictionary, seat: int) -> void:
	row["actions lost"] += played["lost"][seat]
	if played["winner"] == seat:
		row["won"] += 1
	elif played["winner"] == TacticalVictory.DRAW:
		row["drawn"] += 1
	else:
		row["lost"] += 1


# Each seat's line, and both seats together.
func _print(label: String, table: Dictionary, games: int) -> void:
	for seat: int in SEATS:
		var row: Dictionary = table[seat]
		print("%s as %s: %d won, %d lost, %d drawn of %d" % [label, TacticalGame.SIDES[seat], row["won"], row["lost"], row["drawn"], games])
	print("%s, both seats: %d won of %d" % [label, _won(table), games * SEATS.size()])


# The games won over both seats.
func _won(table: Dictionary) -> int:
	var won: int = 0
	for seat: int in SEATS:
		won += table[seat]["won"]
	return won
