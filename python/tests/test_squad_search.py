"""The squad's positions for MCTS (T87), `spec/squad/positions.json`, against Python.

`gameaikit.squad.search_game` is the XCOM-style mode as `MonteCarloSearch`
reads it, the twin of `godot/game/squad/squad_search_game.gd`. On each
position the root's visits after the file's iterations from its seed must
be the file's, answer for answer -- the Godot half is
`make test-squad-search-vectors`'s runner, on the same file. The visits
were written from one run, so what holds them is the two languages
agreeing; the checks below hold the game to the rules besides, which the
two could otherwise get wrong alike.
"""

import json
import pathlib
import unittest

from gameaikit.squad import search_game
from gameaikit.squad.search_game import SHOOT, WALK, Board, Position, SquadSearchGame

REPO = pathlib.Path(__file__).resolve().parents[2]
POSITIONS = json.loads((REPO / "spec" / "squad" / "positions.json").read_text())


def written(name: str) -> dict:
    """The position of that name in the file."""
    return next(entry for entry in POSITIONS["positions"] if entry["name"] == name)


class ThePositions(unittest.TestCase):
    def test_there_are_three(self) -> None:
        self.assertEqual(len(POSITIONS["positions"]), 3)

    def test_every_root_is_the_files(self) -> None:
        for entry in POSITIONS["positions"]:
            with self.subTest(position=entry["name"]):
                found = search_game.searched(POSITIONS["map"], entry)
                self.assertEqual(search_game.root_visits(found), entry["visits"])
                self.assertEqual(search_game.described(found.action), entry["decision"])

    def test_a_wrong_count_is_not_the_files(self) -> None:
        entry = json.loads(json.dumps(written("a mortar with two targets")))
        entry["seed"] += 1
        found = search_game.searched(POSITIONS["map"], entry)
        self.assertNotEqual(search_game.root_visits(found), entry["visits"])


class TheGame(unittest.TestCase):
    def setUp(self) -> None:
        self.game, self.root = search_game.position_from(POSITIONS["map"], written("a mortar with two targets"))

    def test_a_shot_hits_and_misses_at_its_chance(self) -> None:
        hit, missed = self.game.outcomes(self.root, ("shoot", 3, 8))
        chance = self.game.chance_of(self.root.board.piece(3), self.root.board.piece(8))
        self.assertEqual(hit[0], chance / 100.0)
        self.assertAlmostEqual(hit[0] + missed[0], 1.0)
        self.assertIsNone(hit[1].board.piece(8))  # 4 health, and the mortar deals 5
        self.assertEqual(missed[1].board.piece(8).health, 4)
        self.assertEqual(missed[1].board.piece(3).movement, 0)

    def test_after_the_last_piece_the_turn_passes(self) -> None:
        after = self.game.result(self.root, ("hold", 3))
        self.assertEqual((after.unit_id, after.phase), (4, WALK))
        after = self.game.result(after, ("hold", 4))
        self.assertEqual((after.unit_id, after.phase), (4, SHOOT))
        after = self.game.result(after, ("hold", 4))
        self.assertEqual(self.game.to_move(after), 1)
        self.assertEqual(after.board.turn, self.root.board.turn + 1)
        for piece in after.board.of(1):
            self.assertEqual(piece.movement, search_game.full_movement(piece.kind))

    def test_a_walk_never_costs_more_than_the_movement_left(self) -> None:
        game, root = search_game.position_from(POSITIONS["map"], written("the opening"))
        runner = root.board.piece(1)
        walks = game.walks(root.board, runner)
        self.assertTrue(walks)
        for _, _, cell, cost in walks:
            self.assertLessEqual(cost, runner.movement)
            self.assertNotIn(cell, {piece.cell for piece in root.board.pieces})

    def test_the_score_is_the_result_once_over(self) -> None:
        board = self.root.board
        over = Board(tuple(piece for piece in board.pieces if piece.side == 0), board.to_move, board.turn)
        ended = Position(over, -1, WALK, [])
        self.assertTrue(self.game.is_terminal(ended))
        self.assertEqual(self.game.actions(ended), [])
        self.assertEqual((self.game.evaluate(ended, 0), self.game.evaluate(ended, 1)), (1.0, -1.0))
        self.assertLessEqual(abs(self.game.evaluate(self.root, 0)), 1.0)

    def test_a_line_of_sight_is_the_same_both_ways(self) -> None:
        game = SquadSearchGame(POSITIONS["map"])
        cells = [(column, row) for row in range(game.height) for column in range(game.width)]
        for one in cells[::5]:
            for other in cells[::7]:
                self.assertEqual(game.line_clear(one, other), game.line_clear(other, one))


if __name__ == "__main__":
    unittest.main()
