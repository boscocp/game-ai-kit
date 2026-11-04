"""The constraint solver on the book's two examples, and on what it must refuse.

AIMA 4th ed. colours the map of Australia's states in three colours (6.1.1)
and solves a Sudoku by arc consistency (6.2.6); both are here, with the
eight queens to make the search go back, a triangle in two colours that has
no answer, and a global constraint that can only be checked late.
"""

import unittest

from gameaikit.constraints import ConstraintDraws, ConstraintProblem, ConstraintSolver

AUSTRALIA = {"WA": ["NT", "SA"], "NT": ["SA", "Q"], "SA": ["Q", "NSW", "V"], "Q": ["NSW"], "NSW": ["V"], "V": [],
             "T": []}
COLOURS = ["red", "green", "blue"]

#: The puzzle on Wikipedia's "Sudoku" page, and its one solution.
PUZZLE = ["53..7....", "6..195...", ".98....6.", "8...6...3", "4..8.3..1", "7...2...6", ".6....28.",
          "...419..5", "....8..79"]
SOLVED = ["534678912", "672195348", "198342567", "859761423", "426853791", "713924856", "961537284",
          "287419635", "345286179"]


def different(first: object, second: object) -> bool:
    """The test of a not-equal constraint."""
    return first != second


def australia(colours: list[str]) -> ConstraintProblem:
    """AIMA's map colouring: neighbouring states in different colours."""
    problem = ConstraintProblem()
    for state in AUSTRALIA:
        problem.add_variable(state, colours)
    for state, neighbours in AUSTRALIA.items():
        for neighbour in neighbours:
            problem.add_binary(state, neighbour, different, f"{state} != {neighbour}")
    return problem


def sudoku(rows: list[str]) -> ConstraintProblem:
    """One variable a cell, a given cell's domain its digit, and every pair
    sharing a row, a column or a box different."""
    problem = ConstraintProblem()
    cells = [(row, column) for row in range(9) for column in range(9)]
    for row, column in cells:
        given = rows[row][column]
        problem.add_variable(f"r{row}c{column}", [int(given)] if given != "." else list(range(1, 10)))
    for place, (row, column) in enumerate(cells):
        for other_row, other_column in cells[place + 1:]:
            same_box = (row // 3, column // 3) == (other_row // 3, other_column // 3)
            if row == other_row or column == other_column or same_box:
                problem.add_binary(f"r{row}c{column}", f"r{other_row}c{other_column}", different, "a peer")
    return problem


def queens(count: int) -> ConstraintProblem:
    """One variable a column, its value the row: no two on a row or a diagonal."""
    problem = ConstraintProblem()
    for column in range(count):
        problem.add_variable(f"Q{column}", list(range(count)))
    for column in range(count):
        for other in range(column + 1, count):
            apart = other - column
            problem.add_binary(f"Q{column}", f"Q{other}",
                               lambda row, other_row, apart=apart: row != other_row and abs(row - other_row) != apart,
                               "no attack")
    return problem


class TheDraws(unittest.TestCase):
    def test_the_first_draw_is_the_shared_generators(self) -> None:
        self.assertEqual(ConstraintDraws(1).next(), 270369)

    def test_a_shuffle_is_a_permutation_and_repeats_with_its_seed(self) -> None:
        items = list(range(10))
        shuffled = ConstraintDraws(7).shuffle(items)
        self.assertEqual(sorted(shuffled), items)
        self.assertEqual(shuffled, ConstraintDraws(7).shuffle(items))
        self.assertNotEqual(shuffled, ConstraintDraws(8).shuffle(items))

    def test_one_item_spends_no_draw(self) -> None:
        draws = ConstraintDraws(3)
        draws.shuffle(["alone"])
        self.assertEqual(draws.next(), ConstraintDraws(3).next())


class MapColouring(unittest.TestCase):
    def test_three_colours_are_enough_and_every_border_differs(self) -> None:
        problem = australia(COLOURS)
        found = ConstraintSolver(problem, seed=1).solve()
        self.assertIsNotNone(found)
        for binary in problem.binaries:
            self.assertNotEqual(found[binary.first], found[binary.second])

    def test_two_colours_are_not_and_the_solver_says_so(self) -> None:
        solver = ConstraintSolver(australia(["red", "green"]), seed=1)
        self.assertIsNone(solver.solve())
        self.assertFalse(solver.gave_up)

    def test_mrv_starts_where_the_map_is_most_constrained(self) -> None:
        solver = ConstraintSolver(australia(COLOURS), seed=1, record=True)
        solver.solve()
        first = next(event for event in solver.trace if event["event"] == "choose")
        self.assertEqual(first["variable"], "SA")

    def test_the_same_seed_gives_the_same_colours(self) -> None:
        for seed in range(1, 6):
            first = ConstraintSolver(australia(COLOURS), seed=seed).solve()
            self.assertEqual(first, ConstraintSolver(australia(COLOURS), seed=seed).solve())

    def test_a_seed_breaks_the_ties_differently(self) -> None:
        answers = {tuple(sorted(ConstraintSolver(australia(COLOURS), seed=seed).solve().items()))
                   for seed in range(1, 20)}
        self.assertGreater(len(answers), 1)


class Sudoku(unittest.TestCase):
    def test_arc_consistency_alone_solves_an_easy_one(self) -> None:
        solver = ConstraintSolver(sudoku(PUZZLE), seed=1)
        found = solver.solve()
        self.assertEqual(["".join(str(found[f"r{row}c{column}"]) for column in range(9)) for row in range(9)], SOLVED)
        self.assertEqual(solver.backtracks, 0)
        self.assertEqual(solver.assignments, 81)

    def test_the_first_propagation_leaves_one_value_a_cell(self) -> None:
        solver = ConstraintSolver(sudoku(PUZZLE), seed=1, record=True)
        solver.solve()
        first_choice = next(place for place, event in enumerate(solver.trace) if event["event"] == "choose")
        crossed = sum(1 for event in solver.trace[:first_choice] if event["event"] == "prune")
        self.assertEqual(crossed, sum(len(values) - 1 for values in sudoku(PUZZLE).domains.values()))


class Queens(unittest.TestCase):
    def test_eight_queens_attack_nobody(self) -> None:
        found = ConstraintSolver(queens(8), seed=1).solve()
        rows = [found[f"Q{column}"] for column in range(8)]
        self.assertEqual(len(set(rows)), 8)
        for column in range(8):
            for other in range(column + 1, 8):
                self.assertNotEqual(abs(rows[column] - rows[other]), other - column)

    def test_propagation_goes_back_less_than_plain_backtracking(self) -> None:
        plain = ConstraintSolver(queens(8), seed=1, mrv=False, lcv=False, propagate=False)
        plain.solve()
        kept = ConstraintSolver(queens(8), seed=1)
        kept.solve()
        self.assertLess(kept.backtracks, plain.backtracks)

    def test_a_limit_gives_up_and_says_so(self) -> None:
        solver = ConstraintSolver(queens(8), seed=1, mrv=False, lcv=False, propagate=False, limit=5)
        self.assertIsNone(solver.solve())
        self.assertTrue(solver.gave_up)
        self.assertEqual(solver.assignments, 5)


class GlobalConstraints(unittest.TestCase):
    def test_a_global_constraint_is_checked_on_the_partial_assignment(self) -> None:
        problem = ConstraintProblem()
        for name in ("a", "b", "c"):
            problem.add_variable(name, [0, 1, 2, 3])
        problem.add_global(["a", "b", "c"], lambda partial: sum(partial.values()) <= 4, "sum at most 4")
        problem.add_global(["a", "b", "c"], lambda partial: len(partial) < 3 or 3 in partial.values(), "some 3")
        problem.add_binary("a", "b", different, "a != b")
        problem.add_binary("b", "c", different, "b != c")
        problem.add_binary("a", "c", different, "a != c")
        solver = ConstraintSolver(problem, seed=2, record=True)
        found = solver.solve()
        self.assertLessEqual(sum(found.values()), 4)
        self.assertIn(3, found.values())
        self.assertTrue(any(event["event"] == "refuse" for event in solver.trace))

    def test_an_unlabelled_global_constraint_still_refuses(self) -> None:
        problem = ConstraintProblem()
        problem.add_variable("a", [1, 2])
        problem.add_variable("b", [1, 2])
        problem.add_global(["a", "b"], lambda partial: not ("a" in partial and "b" in partial
                                                             and partial["a"] == partial["b"]))
        found = ConstraintSolver(problem, seed=1).solve()
        self.assertNotEqual(found["a"], found["b"])

    def test_an_unlabelled_binary_constraint_still_refuses_without_propagation(self) -> None:
        problem = ConstraintProblem()
        problem.add_variable("a", [1, 2])
        problem.add_variable("b", [1, 2])
        problem.add_binary("a", "b", different)
        found = ConstraintSolver(problem, seed=1, propagate=False).solve()
        self.assertNotEqual(found["a"], found["b"])

    def test_a_second_solve_starts_its_counts_afresh(self) -> None:
        solver = ConstraintSolver(queens(8), seed=1, mrv=False, lcv=False, propagate=False, limit=5)
        solver.solve()
        solver.limit = 0
        self.assertIsNotNone(solver.solve())
        self.assertFalse(solver.gave_up)
        fresh = ConstraintSolver(queens(8), seed=1, mrv=False, lcv=False, propagate=False)
        fresh.solve()
        self.assertEqual(solver.assignments, fresh.assignments)

    def test_a_problem_with_no_variables_has_no_answer(self) -> None:
        self.assertIsNone(ConstraintSolver(ConstraintProblem()).solve())

    def test_a_declaration_that_cannot_work_is_named(self) -> None:
        problem = ConstraintProblem()
        self.assertEqual(problem.problem(), "a problem needs at least one variable")
        problem.add_variable("a", [])
        self.assertIn("no value", problem.problem())
        problem.add_binary("a", "missing", different, "broken")
        self.assertIn("broken", problem.problem())


if __name__ == "__main__":
    unittest.main()
