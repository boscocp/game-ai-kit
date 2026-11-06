"""T88's duel positions, `spec/squad/duel.json`, against Python's expectiminimax.

`gameaikit.squad.evaluation` is the squad's hand-written evaluation and
`gameaikit.adversarial.expectiminimax` the search, the twins of
`squad_evaluated_game.gd` and `expectiminimax.gd`. On each of the 30
positions every answer's expected value at the file's depth must be the
file's, within 1e-9, and the answer worth most the file's decision -- the
Godot half is `godot/test/squad/expecti_squad_test.gd`, on the same file.
The values were written from one run, so what holds them is the two
languages agreeing; the checks below hold the evaluation to its own rules
besides.
"""

import json
import pathlib
import unittest

from gameaikit.adversarial.expectiminimax import ExpectiminimaxSearch
from gameaikit.squad import evaluation
from gameaikit.squad.evaluation import SquadEvaluatedGame
from gameaikit.squad.search_game import Board, Position, WALK, position_from
from gameaikit.squad.shot import RULES

REPO = pathlib.Path(__file__).resolve().parents[2]
DUEL = json.loads((REPO / "spec" / "squad" / "duel.json").read_text())
TOLERANCE = 1e-9


class ThePositions(unittest.TestCase):
    def test_there_are_thirty_and_each_tag_is_there(self) -> None:
        self.assertEqual(len(DUEL["positions"]), 30)
        abouts = [entry["about"] for entry in DUEL["positions"]]
        for tag in ("flank", "long shot", "retreat to cover"):
            self.assertIn(tag, abouts)

    def test_every_expected_value_is_the_files(self) -> None:
        for entry in DUEL["positions"]:
            with self.subTest(position=entry["name"]):
                wanted = entry["expected"]
                found = evaluation.expected_values(DUEL["map"], entry, wanted["depth"])
                values = evaluation.root_values(found)
                self.assertEqual([answer for answer, _ in values], [answer for answer, _ in wanted["values"]])
                for (_, mine), (_, theirs) in zip(values, wanted["values"]):
                    self.assertAlmostEqual(mine, theirs, delta=TOLERANCE)
                self.assertEqual(found.depth, wanted["depth"])

    def test_a_search_with_no_dice_is_not_the_files(self) -> None:
        shots = [entry for entry in DUEL["positions"] if entry["phase"] == "shoot"]
        differ = 0
        for entry in shots:
            plain, root = position_from(DUEL["map"], entry)
            game = NoDice(plain.rows)
            found = ExpectiminimaxSearch(game, root).search_to(entry["expected"]["depth"])
            values = [value for _, value in evaluation.root_values(found)]
            if any(abs(mine - theirs) > TOLERANCE for mine, (_, theirs) in zip(values, entry["expected"]["values"])):
                differ += 1
        self.assertGreater(differ, len(shots) // 2)


class NoDice(SquadEvaluatedGame):
    """A planted game: every shot is its likelier outcome, certain -- what a search with no dice sees."""

    def outcomes(self, state, action):
        possible = SquadEvaluatedGame.outcomes(self, state, action)
        return [(1.0, max(possible, key=lambda outcome: outcome[0])[1])]


class TheEvaluation(unittest.TestCase):
    def setUp(self) -> None:
        self.entry = DUEL["positions"][1]
        plain, self.root = position_from(DUEL["map"], self.entry)
        self.game = SquadEvaluatedGame(plain.rows)

    def test_the_weights_add_up_to_one(self) -> None:
        self.assertAlmostEqual(sum(RULES["evaluation"].values()), 1.0)

    def test_every_term_is_within_one_and_the_score_below_a_win(self) -> None:
        for entry in DUEL["positions"]:
            _, root = position_from(DUEL["map"], entry)
            for side in (0, 1):
                terms = self.game.terms_for(root.board, side)
                for term in terms.values():
                    self.assertLessEqual(abs(term), 1.0)
                self.assertLess(abs(self.game.evaluate(root, side)), 1.0)

    def test_the_two_sides_see_one_score_from_opposite_ends(self) -> None:
        for side in (0, 1):
            other = 1 - side
            self.assertAlmostEqual(self.game.evaluate(self.root, side), -self.game.evaluate(self.root, other))

    def test_a_finished_game_is_its_result(self) -> None:
        board = self.root.board
        over = Board(tuple(piece for piece in board.pieces if piece.side == 0), board.to_move, board.turn)
        ended = Position(over, -1, WALK, [])
        self.assertEqual((self.game.evaluate(ended, 0), self.game.evaluate(ended, 1)), (1.0, -1.0))


if __name__ == "__main__":
    unittest.main()
