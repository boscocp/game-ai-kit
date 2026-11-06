# T88's duel: expectiminimax faces Monte Carlo tree search on the same
# positions, with the same budget. Two ways of running it:
#
# - **`fixed`, `make test-squad-duel`, the gate.** Each of the 30 positions
#   of `spec/squad/duel.json` searched once by each search for a counted
#   budget (`SquadDuel.searched_fixed`), and `games` seeded matches a seat
#   a pairing with the controllers on counted budgets. Seeded and counted:
#   the same run on any machine under any load, in about half a minute.
# - **`clock`, `make measure-squad-duel`, the measurement.** Each position
#   at 50, 200 and 1,000 ms on the wall clock (`SquadDuel.searched`): a
#   line a position, then a table a budget -- how often the two agree, how
#   many iterations MCTS ran, how deep expectiminimax finished -- and where
#   a longer window searched less than a shorter one, said and not held.
#   Then `games` matches a seat a pairing, every decision searched for
#   `milliseconds`. `docs/godot/squad.md` keeps one run, with the date.
#
# The pairings: expectiminimax against MCTS, and each against the first
# enemy that weighs (T85's baseline). Match `n` of a seat is played on dice
# seed `n`, each searcher seeded `1000 + n`; `first` lets several runs
# share the matches out, and a run whose first match is not 1 leaves the
# positions to the run that has it.
#
# What fails, in both ways: an answer that is not one of the position's, a
# search that finished nothing, a match with no end or a lost decision
# (`SquadDuel.wrong_position`, `wrong_match`) -- and fewer rows or matches
# than set out for (`SquadDuel.missing_rows`), which is what a search or a
# match that broke leaves. A `SCRIPT ERROR` anywhere else -- in a check, in
# the count, in `_run` -- is invisible from inside: an aborted function
# hands back its type's default, and an empty list of failures reads as
# none. So both make targets run this through `scripts/godot_checked.py`,
# which fails the run on any engine error in its output; and the exit code
# is 1 until `_run` has reached its last line.
#
#     ./scripts/godot --headless --path godot -s res://test/squad/squad_duel_runner.gd \
#         -- /absolute/path/to/spec/squad/duel.json fixed|clock [games] [milliseconds] [first]
#
# Exit codes: 0 every row holds and every row is there; 1 one did not, or
# is missing, or the run stopped before its verdict; 2 the file could not
# be read, or the arguments could not -- `fixed` with no match or a first
# match other than 1 among them: the gate is one run of one shape.
extends SceneTree

const SEATS: Array[int] = [TacticalScenario.RED, TacticalScenario.BLUE]
const PAIRINGS: Array[Array] = [["expecti", "mcts"], ["expecti", "weighed"], ["mcts", "weighed"]]
const MODES: Array[String] = ["fixed", "clock"]

# The rows and matches this run has finished, counted as each finishes.
var _rows_done: int = 0
var _matches_done: int = 0
var _clock: bool = false
# The exit code: a failure until `_run` sets it on its last line, so a
# SCRIPT ERROR that stops `_run` half-way exits 1, not `quit(null)`'s 0.
var _verdict: int = 1


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var written: Variant = JSON.parse_string(FileAccess.get_file_as_string(arguments[0])) if not arguments.is_empty() else null
	var mode: String = arguments[1] if arguments.size() > 1 else ""
	var games: int = int(arguments[2]) if arguments.size() > 2 else 1
	var milliseconds: int = int(arguments[3]) if arguments.size() > 3 else 50
	var first: int = int(arguments[4]) if arguments.size() > 4 else 1
	var gate_cut_short: bool = mode == "fixed" and (games < 1 or first != 1)
	if not written is Dictionary or (written as Dictionary).get("positions", []).is_empty() or not mode in MODES \
			or games < 0 or milliseconds <= 0 or first < 1 or gate_cut_short:
		printerr("squad_duel_runner: give me the path of duel.json after `--`, then fixed or clock, the games a seat, the milliseconds a decision and the first game")
		quit(2)
		return
	_clock = mode == "clock"
	_run(written["positions"], games, milliseconds, first)
	quit(_verdict)


# The positions (when this run has the first match), the matches, the
# counts, and the summary; the verdict, set last.
func _run(positions: Array, games: int, milliseconds: int, first: int) -> void:
	var failures: Array[String] = []
	# Worked out from the arguments before anything runs, never from what ran:
	# an expected count taken from the produced one could not come up short.
	var rows_wanted: int = 0
	if first == 1:
		rows_wanted = positions.size() * (SquadDuel.BUDGETS.size() if _clock else 1)
		failures += _positions(positions)
	failures += _matches(first, games, milliseconds)
	failures += SquadDuel.missing_rows("position rows", rows_wanted, _rows_done)
	failures += SquadDuel.missing_rows("matches", PAIRINGS.size() * SEATS.size() * games, _matches_done)
	for failure: String in failures:
		print(failure)
	print("squad duel, %s: %d position row(s), %d match(es), %d failure(s)" % [
		"clock" if _clock else "fixed", _rows_done, _matches_done, failures.size()])
	_verdict = 1 if not failures.is_empty() else 0


# Every position, a line each; on the clock, at every budget, then a table
# a budget.
func _positions(positions: Array) -> Array[String]:
	var failures: Array[String] = []
	var by_budget: Array[Array] = [[], [], []]
	for index: int in range(positions.size()):
		var rows: Array[Dictionary] = _rows_for(positions[index], 1000 + index)
		failures += SquadDuel.wrong_position(positions[index], rows)
		print(_position_line(positions[index], rows))
		for note: String in _notes(positions[index], rows):
			print("note: " + note)
		for budget_index: int in range(rows.size()):
			by_budget[budget_index].append(rows[budget_index])
	print("\n| a decision | the two agree | MCTS iterations, fewest-most | expectiminimax depth finished |")
	print("|---|---|---|---|")
	for budget_index: int in range(by_budget.size()):
		if not by_budget[budget_index].is_empty():
			print(_budget_line(_budget_said(budget_index), by_budget[budget_index]))
	return failures


# `position`'s rows, one a budget, each counted once it is whole: a search
# that broke leaves no row, and the count comes up short.
func _rows_for(position: Dictionary, seed_number: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for budget: int in SquadDuel.BUDGETS if _clock else [0]:
		var row: Variant = SquadDuel.searched(position, budget, seed_number) if _clock \
			else SquadDuel.searched_fixed(position, seed_number)
		if row is Dictionary and not (row as Dictionary).is_empty():
			rows.append(row)
			_rows_done += 1
	return rows


# On the clock, where a longer window searched less than a shorter one:
# said, never held. The fixed run has one budget, and nothing to compare.
func _notes(position: Dictionary, rows: Array[Dictionary]) -> Array[String]:
	var notes: Array[String] = []
	if _clock:
		notes = SquadDuel.searched_less(position, rows)
	return notes


func _budget_said(budget_index: int) -> String:
	if _clock:
		return "%d ms" % SquadDuel.BUDGETS[budget_index]
	return "%d iterations, %d positions" % [SquadDuel.FIXED_ITERATIONS, SquadDuel.FIXED_POSITIONS]


# One position: at each budget, MCTS's answer and expectiminimax's, `=`
# when they agree, with the iterations and the depth.
func _position_line(position: Dictionary, rows: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		var agreed: String = "=" if row["mcts"] == row["expecti"] else "x"
		parts.append("%s %s mcts %s (%d) / expecti %s (depth %d)" % [_budget_said(index), agreed, row["mcts"],
			row["iterations"], row["expecti"], row["depth"]])
	return "%s: %s" % [position["name"], " | ".join(parts)]


# One budget's row of the table: agreements of the positions, MCTS's
# iterations, expectiminimax's depths and how many finished each.
func _budget_line(budget: String, rows: Array) -> String:
	var agreed: int = rows.filter(func(row: Dictionary) -> bool: return row["mcts"] == row["expecti"]).size()
	var iterations: Array = rows.map(func(row: Dictionary) -> int: return row["iterations"])
	var depths: Dictionary = {}
	for row: Dictionary in rows:
		depths[row["depth"]] = depths.get(row["depth"], 0) + 1
	var depth_said: Array[String] = []
	for depth: int in depths.keys():
		depth_said.append("%d at depth %d" % [depths[depth], depth])
	return "| %s | %d of %d | %d-%d | %s |" % [budget, agreed, rows.size(), iterations.min(), iterations.max(), ", ".join(depth_said)]


# Every pairing from each seat, `games` matches each from `first`, a line a
# pairing.
func _matches(first: int, games: int, milliseconds: int) -> Array[String]:
	var failures: Array[String] = []
	if games == 0:
		return failures
	var budget: String = ("%d ms" % milliseconds) if _clock else ("%d iterations, %d positions" % [
		SquadDuel.MATCH_ITERATIONS, SquadDuel.MATCH_POSITIONS])
	print("\n| %s a decision | as red: won, lost, drawn | as blue: won, lost, drawn |" % budget)
	print("|---|---|---|")
	for pairing: Array in PAIRINGS:
		var said: Array[String] = []
		for seat: int in SEATS:
			said.append(str(_seat(pairing, seat, range(first, first + games), milliseconds, failures)))
		print("| %s against %s | %s |" % [pairing[0], pairing[1], " | ".join(said)])
	return failures


# `pairing[0]`'s won, lost and drawn from `seat` over `games`, each match's
# failures added to `failures`, each match counted once it is over.
func _seat(pairing: Array, seat: int, games: Array, milliseconds: int, failures: Array[String]) -> String:
	var tally: Array[int] = [0, 0, 0]
	for game: int in games:
		var row: Dictionary = _match(pairing, seat, game, milliseconds)
		failures.append_array(SquadDuel.wrong_match(row))
		tally[_tally_index(row["winner"], seat)] += 1
		_matches_done += 1
	return "%d, %d, %d" % tally


# One match: `pairing[0]` in `seat`, `pairing[1]` in the other.
func _match(pairing: Array, seat: int, game: int, milliseconds: int) -> Dictionary:
	var first: BlueController = _controller(pairing[0], game, milliseconds)
	var second: BlueController = _controller(pairing[1], game, milliseconds)
	var red: BlueController = first if seat == TacticalScenario.RED else second
	var blue: BlueController = second if seat == TacticalScenario.RED else first
	var played: Dictionary = SquadMatch.play(red, blue, game)
	played["game"] = game
	return played


# The controller the roster names, on the clock or on the gate's counted
# budget.
func _controller(row_name: String, game: int, milliseconds: int) -> BlueController:
	var seed_number: int = 1000 + game
	if not _clock and row_name == "mcts":
		return MctsSquad.new(seed_number, SquadDuel.MATCH_ITERATIONS)
	if not _clock and row_name == "expecti":
		return ExpectiSquad.new(seed_number, SquadDuel.MATCH_POSITIONS)
	var built: BlueController = SquadRoster.build(row_name, seed_number)
	if built is SearchingSquad:
		(built as SearchingSquad).think_for(milliseconds)
	return built


# Won, lost or drawn, for the side in `seat`: the tally's index.
static func _tally_index(winner: int, seat: int) -> int:
	if winner == seat:
		return 0
	return 2 if winner == TacticalVictory.DRAW else 1
