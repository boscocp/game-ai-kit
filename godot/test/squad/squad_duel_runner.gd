# `make test-squad-duel` (T88): expectiminimax faces Monte Carlo tree
# search on the same positions, at the same time on the wall clock.
#
# First the 30 positions of `spec/squad/duel.json`, each searched by both at
# 50, 200 and 1,000 ms (`SquadDuel.searched`): a line a position, then a
# table a budget -- how often the two agree, how many iterations MCTS ran,
# how deep expectiminimax finished. Then seeded matches, `games` a seat,
# every decision searched for `milliseconds`: expectiminimax against MCTS,
# and each against the first enemy that weighs (T85's baseline). Match `n`
# of a seat is played on dice seed `n`, each searcher seeded `1000 + n`;
# `first` lets several runs share the matches out, and a run whose first
# match is not 1 leaves the positions to the run that has it.
#
# The times are this machine's, under whatever else it is doing: what it
# prints is a measurement, and `docs/godot/squad.md` keeps one run of it
# with the date. What it holds, and fails on, is what no load can excuse
# (`SquadDuel.wrong_position`, `SquadDuel.wrong_match`): an answer that is
# not the position's, a budget that finished nothing, a longer budget that
# searched less than a shorter one, a match with no end or a lost decision.
#
#     ./scripts/godot --headless --path godot -s res://test/squad/squad_duel_runner.gd \
#         -- /absolute/path/to/spec/squad/duel.json [games] [milliseconds] [first]
#
# Exit codes: 0 every row holds; 1 one did not; 2 the file could not be
# read, or the arguments could not.
extends SceneTree

const SEATS: Array[int] = [TacticalScenario.RED, TacticalScenario.BLUE]
const PAIRINGS: Array[Array] = [["expecti", "mcts"], ["expecti", "weighed"], ["mcts", "weighed"]]


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var written: Variant = JSON.parse_string(FileAccess.get_file_as_string(arguments[0])) if not arguments.is_empty() else null
	var games: int = int(arguments[1]) if arguments.size() > 1 else 100
	var milliseconds: int = int(arguments[2]) if arguments.size() > 2 else 50
	var first: int = int(arguments[3]) if arguments.size() > 3 else 1
	if not written is Dictionary or (written as Dictionary).get("positions", []).is_empty() or games < 0 or milliseconds <= 0 or first < 1:
		printerr("squad_duel_runner: give me the path of duel.json after `--`, then the games a seat, the milliseconds a decision and the first game")
		quit(2)
		return
	var failures: Array[String] = _positions(written["positions"]) if first == 1 else [] as Array[String]
	failures += _matches(first, games, milliseconds)
	for failure: String in failures:
		print(failure)
	print("squad duel: %d position(s), %d match(es) a seat a pairing, %d failure(s)" % [written["positions"].size(), games, failures.size()])
	quit(1 if not failures.is_empty() else 0)


# Every position at every budget, a line each, then a table a budget.
func _positions(positions: Array) -> Array[String]:
	var failures: Array[String] = []
	var by_budget: Array[Array] = [[], [], []]
	for index: int in range(positions.size()):
		var rows: Array[Dictionary] = []
		for budget: int in SquadDuel.BUDGETS:
			rows.append(SquadDuel.searched(positions[index], budget, 1000 + index))
		failures += SquadDuel.wrong_position(positions[index], rows)
		print(_position_line(positions[index], rows))
		for budget_index: int in range(rows.size()):
			by_budget[budget_index].append(rows[budget_index])
	print("\n| a decision | the two agree | MCTS iterations, fewest-most | expectiminimax depth finished |")
	print("|---|---|---|---|")
	for budget_index: int in range(SquadDuel.BUDGETS.size()):
		print(_budget_line(SquadDuel.BUDGETS[budget_index], by_budget[budget_index]))
	return failures


# One position: at each budget, MCTS's answer and expectiminimax's, `=`
# when they agree, with the iterations and the depth.
func _position_line(position: Dictionary, rows: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		var agreed: String = "=" if row["mcts"] == row["expecti"] else "x"
		parts.append("%d ms %s mcts %s (%d) / expecti %s (depth %d)" % [SquadDuel.BUDGETS[index], agreed, row["mcts"],
			row["iterations"], row["expecti"], row["depth"]])
	return "%s: %s" % [position["name"], " | ".join(parts)]


# One budget's row of the table: agreements of the positions, MCTS's
# iterations, expectiminimax's depths and how many finished each.
func _budget_line(budget: int, rows: Array) -> String:
	var agreed: int = rows.filter(func(row: Dictionary) -> bool: return row["mcts"] == row["expecti"]).size()
	var iterations: Array = rows.map(func(row: Dictionary) -> int: return row["iterations"])
	var depths: Dictionary = {}
	for row: Dictionary in rows:
		depths[row["depth"]] = depths.get(row["depth"], 0) + 1
	var depth_said: Array[String] = []
	for depth: int in depths.keys():
		depth_said.append("%d at depth %d" % [depths[depth], depth])
	return "| %d ms | %d of %d | %d-%d | %s |" % [budget, agreed, rows.size(), iterations.min(), iterations.max(), ", ".join(depth_said)]


# Every pairing from each seat, `games` matches each from `first`, a line a
# pairing.
func _matches(first: int, games: int, milliseconds: int) -> Array[String]:
	var failures: Array[String] = []
	if games == 0:
		return failures
	print("\n| %d ms a decision | as red: won, lost, drawn | as blue: won, lost, drawn |" % milliseconds)
	print("|---|---|---|")
	for pairing: Array in PAIRINGS:
		var said: Array[String] = []
		for seat: int in SEATS:
			said.append(_seat(pairing, seat, range(first, first + games), milliseconds, failures))
		print("| %s against %s | %s |" % [pairing[0], pairing[1], " | ".join(said)])
	return failures


# `pairing[0]`'s won, lost and drawn from `seat` over `games`, each match's
# failures added to `failures`.
func _seat(pairing: Array, seat: int, games: Array, milliseconds: int, failures: Array[String]) -> String:
	var tally: Array[int] = [0, 0, 0]
	for game: int in games:
		var row: Dictionary = _match(pairing, seat, game, milliseconds)
		failures.append_array(SquadDuel.wrong_match(row))
		tally[_tally_index(row["winner"], seat)] += 1
	return "%d, %d, %d" % tally


# One match: `pairing[0]` in `seat`, `pairing[1]` in the other, each told
# to search `milliseconds` a decision.
func _match(pairing: Array, seat: int, game: int, milliseconds: int) -> Dictionary:
	var first: BlueController = _controller(pairing[0], game, milliseconds)
	var second: BlueController = _controller(pairing[1], game, milliseconds)
	var red: BlueController = first if seat == TacticalScenario.RED else second
	var blue: BlueController = second if seat == TacticalScenario.RED else first
	var played: Dictionary = SquadMatch.play(red, blue, game)
	played["game"] = game
	return played


func _controller(row_name: String, game: int, milliseconds: int) -> BlueController:
	var built: BlueController = SquadRoster.build(row_name, 1000 + game)
	if built is SearchingSquad:
		(built as SearchingSquad).think_for(milliseconds)
	return built


# Won, lost or drawn, for the side in `seat`: the tally's index.
static func _tally_index(winner: int, seat: int) -> int:
	if winner == seat:
		return 0
	return 2 if winner == TacticalVictory.DRAW else 1
