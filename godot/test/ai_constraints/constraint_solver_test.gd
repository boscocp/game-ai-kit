# The solver on the book's examples -- Australia in three colours (AIMA
# 6.1.1), an easy Sudoku that arc consistency alone solves (6.2.6) -- the
# eight queens, a map that has no answer, a limit that gives up, and a
# declaration it must refuse.
extends GdUnitTestSuite

const BORDERS: Array[Array] = [["WA", "NT"], ["WA", "SA"], ["NT", "SA"], ["NT", "Q"], ["SA", "Q"], ["SA", "NSW"],
		["SA", "V"], ["Q", "NSW"], ["NSW", "V"]]
## The puzzle on Wikipedia's "Sudoku" page, and its one solution.
const PUZZLE: Array[String] = ["53..7....", "6..195...", ".98....6.", "8...6...3", "4..8.3..1", "7...2...6",
		".6....28.", "...419..5", "....8..79"]
const SOLVED: Array[String] = ["534678912", "672195348", "198342567", "859761423", "426853791", "713924856",
		"961537284", "287419635", "345286179"]


static func _different(first: Variant, second: Variant) -> bool:
	return first != second


func _australia(colours: Array) -> ConstraintProblem:
	var problem := ConstraintProblem.new()
	for state: String in ["WA", "NT", "SA", "Q", "NSW", "V", "T"]:
		problem.add_variable(state, colours)
	for border: Array in BORDERS:
		problem.add_binary(border[0], border[1], _different, "%s != %s" % border)
	return problem


func _sudoku() -> ConstraintProblem:
	var problem := ConstraintProblem.new()
	var cells: Array[Vector2i] = []
	for row: int in range(9):
		for column: int in range(9):
			var given: String = PUZZLE[row][column]
			problem.add_variable("r%dc%d" % [row, column], [int(given)] if given != "." else range(1, 10))
			cells.append(Vector2i(column, row))
	for place: int in range(cells.size()):
		for other: int in range(place + 1, cells.size()):
			_add_if_peers(problem, cells[place], cells[other])
	return problem


# Two cells on one row, one column or in one box must differ.
func _add_if_peers(problem: ConstraintProblem, cell: Vector2i, peer: Vector2i) -> void:
	if cell.x == peer.x or cell.y == peer.y or Vector2i(cell / 3) == Vector2i(peer / 3):
		problem.add_binary("r%dc%d" % [cell.y, cell.x], "r%dc%d" % [peer.y, peer.x], _different, "a peer")


func _queens(count: int) -> ConstraintProblem:
	var problem := ConstraintProblem.new()
	for column: int in range(count):
		problem.add_variable("Q%d" % column, range(count))
	for column: int in range(count):
		for other: int in range(column + 1, count):
			problem.add_binary("Q%d" % column, "Q%d" % other, _no_attack.bind(other - column), "no attack")
	return problem


static func _no_attack(row: int, other_row: int, apart: int) -> bool:
	return row != other_row and absi(row - other_row) != apart


func test_three_colours_colour_australia() -> void:
	var problem := _australia(["red", "green", "blue"])
	var found: Dictionary = ConstraintSolver.new(problem, 1).solve()
	assert_int(found.size()).is_equal(7)
	for border: Array in BORDERS:
		assert_str(found[border[0]]).is_not_equal(found[border[1]])


func test_two_colours_cannot_and_it_says_so() -> void:
	var solver := ConstraintSolver.new(_australia(["red", "green"]), 1)
	assert_dict(solver.solve()).is_empty()
	assert_bool(solver.gave_up).is_false()


func test_mrv_starts_where_the_map_is_tightest() -> void:
	var solver := ConstraintSolver.new(_australia(["red", "green", "blue"]), 1)
	solver.record = true
	solver.solve()
	var first: Array = solver.trace.filter(func(event: Dictionary) -> bool: return event["event"] == "choose")
	assert_str(first[0]["variable"]).is_equal("SA")


func test_arc_consistency_alone_solves_an_easy_sudoku() -> void:
	var solver := ConstraintSolver.new(_sudoku(), 1)
	var found: Dictionary = solver.solve()
	for row: int in range(9):
		var line: String = ""
		for column: int in range(9):
			line += str(found["r%dc%d" % [row, column]])
		assert_str(line).is_equal(SOLVED[row])
	assert_int(solver.backtracks).is_equal(0)


func test_eight_queens_and_what_propagation_saves() -> void:
	var plain := ConstraintSolver.new(_queens(8), 1)
	plain.mrv = false
	plain.lcv = false
	plain.propagate = false
	var found: Dictionary = plain.solve()
	assert_int(found.size()).is_equal(8)
	var kept := ConstraintSolver.new(_queens(8), 1)
	kept.solve()
	assert_int(kept.backtracks).is_less(plain.backtracks)


func test_a_limit_gives_up_and_says_so() -> void:
	var solver := ConstraintSolver.new(_queens(8), 1)
	solver.propagate = false
	solver.mrv = false
	solver.limit = 5
	assert_dict(solver.solve()).is_empty()
	assert_bool(solver.gave_up).is_true()
	assert_int(solver.assignments).is_equal(5)


static func _not_both_equal(partial: Dictionary) -> bool:
	return not (partial.has("a") and partial.has("b") and partial["a"] == partial["b"])


func _two_of_two() -> ConstraintProblem:
	var problem := ConstraintProblem.new()
	problem.add_variable("a", [1, 2])
	problem.add_variable("b", [1, 2])
	return problem


func test_an_unlabelled_global_constraint_still_refuses() -> void:
	var problem := _two_of_two()
	var names: Array[String] = ["a", "b"]
	problem.add_global(names, _not_both_equal)
	var found: Dictionary = ConstraintSolver.new(problem, 1).solve()
	assert_int(found["a"]).is_not_equal(found["b"])


func test_an_unlabelled_binary_constraint_still_refuses_without_propagation() -> void:
	var problem := _two_of_two()
	problem.add_binary("a", "b", _different)
	var solver := ConstraintSolver.new(problem, 1)
	solver.propagate = false
	var found: Dictionary = solver.solve()
	assert_int(found["a"]).is_not_equal(found["b"])


func test_a_second_solve_starts_its_counts_afresh() -> void:
	var solver := ConstraintSolver.new(_queens(8), 1)
	solver.propagate = false
	solver.mrv = false
	solver.lcv = false
	solver.limit = 5
	solver.solve()
	solver.limit = 0
	assert_dict(solver.solve()).is_not_empty()
	assert_bool(solver.gave_up).is_false()
	var fresh := ConstraintSolver.new(_queens(8), 1)
	fresh.propagate = false
	fresh.mrv = false
	fresh.lcv = false
	fresh.solve()
	assert_int(solver.assignments).is_equal(fresh.assignments)


func test_a_problem_with_no_variables_has_no_answer() -> void:
	assert_dict(ConstraintSolver.new(ConstraintProblem.new()).solve()).is_empty()


func test_a_declaration_that_cannot_work_is_named() -> void:
	var problem := ConstraintProblem.new()
	assert_str(problem.problem()).is_equal("a problem needs at least one variable")
	problem.add_variable("a", [])
	assert_str(problem.problem()).contains("no value")
	problem.add_binary("a", "missing", _different, "broken")
	assert_str(problem.problem()).contains("broken")


func test_the_draws_are_the_shared_generators() -> void:
	assert_int(ConstraintDraws.new(1).next()).is_equal(270369)
	var draws := ConstraintDraws.new(3)
	draws.shuffle(["alone"])
	assert_int(draws.next()).is_equal(ConstraintDraws.new(3).next())
