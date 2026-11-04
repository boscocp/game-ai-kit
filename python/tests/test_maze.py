"""The maze's rules, one at a time, and three properties over seeded games.

The properties are T97's: no ghost reverses outside a mode change, no ghost
ever stands on a wall, and a seeded game replays move for move. They are
asked of a few hundred games with random moves, two ghosts, long enough to
cross every mode of the schedule.
"""

import random
import unittest

from gameaikit.core import Xorshift
from gameaikit.maze import game, rules

GAMES = 200
STEPS = 160
MOVES = ("up", "left", "down", "right")


def random_moves(seed: int, count: int) -> list[str]:
    """Moves a person might make: runs of one direction, of random length."""
    chooser = random.Random(seed)
    moves: list[str] = []
    while len(moves) < count:
        moves += [chooser.choice(MOVES)] * chooser.randint(1, 6)
    return moves[:count]


def played(seed: int) -> list[game.Game]:
    """Every state of one seeded game with both ghosts, step by step."""
    states = []
    current = game.Game(seed, ["blinky", "pinky"])
    for move in random_moves(seed, STEPS):
        before = (current.steps, [(ghost.cell, ghost.heading, ghost.decision["kind"]) for ghost in current.ghosts])
        current.step(move)
        states.append((before, current.steps, [(ghost.cell, ghost.heading) for ghost in current.ghosts]))
        if current.outcome != game.PLAYING:
            break
    return states


class TheMaze(unittest.TestCase):
    def test_it_is_small_with_no_dead_end_and_four_pellets(self):
        cells = rules.floor_cells()
        self.assertEqual(len(cells), 52)
        for cell in cells:
            exits = [way for way in MOVES if rules.is_open(rules.moved(cell, way))]
            self.assertGreaterEqual(len(exits), 2, cell)
        self.assertEqual(len(rules.MAZE["pellets"]), 4)
        for cell in rules.MAZE["pellets"]:
            self.assertTrue(rules.is_open(tuple(cell)))

    def test_outside_the_rows_is_wall(self):
        self.assertFalse(rules.is_open((-1, 3)))
        self.assertFalse(rules.is_open((5, 99)))


class TheSchedule(unittest.TestCase):
    def test_the_dossiers_level_one_in_steps(self):
        self.assertEqual(rules.mode_at(0), rules.SCATTER)
        self.assertEqual(rules.mode_at(13), rules.SCATTER)
        self.assertEqual(rules.mode_at(14), rules.CHASE)
        self.assertEqual(rules.mode_at(53), rules.CHASE)
        self.assertEqual(rules.mode_at(54), rules.SCATTER)
        self.assertEqual(rules.mode_at(10_000), rules.CHASE)


class TheTargets(unittest.TestCase):
    def test_in_scatter_each_ghost_aims_at_its_corner(self):
        self.assertEqual(rules.target("blinky", rules.SCATTER, (6, 7), "left"), (11, -2))
        self.assertEqual(rules.target("pinky", rules.SCATTER, (6, 7), "left"), (1, -2))

    def test_blinky_chases_pac_mans_cell(self):
        self.assertEqual(rules.target("blinky", rules.CHASE, (3, 5), "up"), (3, 5))

    def test_pinky_aims_four_ahead_and_up_is_also_four_left(self):
        self.assertEqual(rules.target("pinky", rules.CHASE, (6, 7), "left"), (2, 7))
        self.assertEqual(rules.target("pinky", rules.CHASE, (6, 3), "right"), (10, 3))
        self.assertEqual(rules.target("pinky", rules.CHASE, (6, 7), "up"), (2, 3))


class TheChoice(unittest.TestCase):
    def test_the_reverse_is_never_a_way_while_another_is_open(self):
        found = rules.ways((5, 3), "left", (0, 0))
        self.assertEqual([way["direction"] for way in found], ["up", "left"])

    def test_the_shortest_line_from_the_cell_beyond_wins(self):
        found = rules.ways((5, 3), "left", (11, -2))
        self.assertEqual(rules.nearest(found), "up")
        found = rules.ways((5, 3), "left", (0, 3))
        self.assertEqual(rules.nearest(found), "left")

    def test_a_tie_goes_up_then_left_then_down_then_right(self):
        # From (3, 3) heading right, up is a wall: left is behind, so the ways
        # are down and right; a target equally far from (3, 4) and (4, 3) ties.
        found = rules.ways((3, 3), "right", (4, 4))
        self.assertEqual([way["direction"] for way in found], ["down", "right"])
        self.assertEqual(found[0]["squared"], found[1]["squared"])
        self.assertEqual(rules.nearest(found), "down")

    def test_up_wins_a_tie_with_left(self):
        # From (5, 3) heading left the ways are up and left; (4, 2) is one
        # cell from both (5, 2) and (4, 3).
        found = rules.ways((5, 3), "left", (4, 2))
        self.assertEqual([way["squared"] for way in found], [1, 1])
        self.assertEqual(rules.nearest(found), "up")
        self.assertEqual(rules.nearest(list(reversed(found))), "up")

    def test_the_first_draw_decides_keeping_and_the_second_picks_the_way(self):
        # One stream, as in a game: a small seed's first draw is small, so
        # fresh seeds would almost never reach the second draw.
        found = rules.ways((3, 3), "right", (4, 4))
        dice, mirror = Xorshift(11), Xorshift(11)
        turns = 0
        for fork in range(300):
            roll = mirror.uniform()
            choice = rules.choose(found, rules.CHASE, dice)
            if roll < rules.PRECISION:
                self.assertEqual((choice["kind"], choice["chosen"]), (rules.NEAREST, "down"), fork)
            else:
                turns += 1
                wanted = found[mirror.next() % len(found)]["direction"]
                self.assertEqual((choice["kind"], choice["chosen"]), (rules.DICE, wanted), fork)
        self.assertGreater(turns, 30)

    def test_scatter_is_never_imprecise_and_draws_nothing(self):
        dice = Xorshift(5)
        found = rules.ways((5, 3), "left", (11, -2))
        choice = rules.choose(found, rules.SCATTER, dice)
        self.assertEqual(choice["kind"], rules.NEAREST)
        self.assertNotIn("roll", choice)
        self.assertEqual(dice.next(), Xorshift(5).next())

    def test_one_way_draws_nothing_even_in_chase(self):
        dice = Xorshift(5)
        choice = rules.choose(rules.ways((5, 2), "up", (0, 0)), rules.CHASE, dice)
        self.assertEqual(choice["kind"], rules.ONLY_WAY)
        self.assertEqual(dice.next(), Xorshift(5).next())

    def test_chances_are_what_the_dice_do(self):
        found = rules.ways((3, 3), "right", (4, 4))
        wanted = rules.chances(found, rules.CHASE)
        self.assertAlmostEqual(sum(wanted.values()), 1.0)
        self.assertAlmostEqual(wanted["down"], rules.PRECISION + (1 - rules.PRECISION) / 2)
        dice = Xorshift(11)
        draws = 20_000
        taken = {"down": 0, "right": 0}
        for _draw in range(draws):
            taken[rules.choose(found, rules.CHASE, dice)["chosen"]] += 1
        for way, count in taken.items():
            self.assertAlmostEqual(count / draws, wanted[way], delta=0.01)

    def test_in_scatter_the_dossiers_way_is_certain(self):
        found = rules.ways((3, 3), "right", (4, 4))
        self.assertEqual(rules.chances(found, rules.SCATTER), {"down": 1.0, "right": 0.0})


class AStep(unittest.TestCase):
    def test_into_a_wall_pac_man_stays_and_keeps_his_facing(self):
        current = game.Game(1)
        current.step("down")
        self.assertEqual(current.pacman, (6, 7))
        self.assertEqual(current.facing, "left")

    def test_walking_onto_a_ghost_is_caught_before_it_moves(self):
        current = game.Game(1)
        current.pacman = (4, 3)
        current.ghosts[0].cell = (3, 3)
        current.ghosts[0].next_move = "left"
        current.step("left")
        self.assertEqual(current.outcome, game.CAUGHT)
        self.assertEqual(current.ghosts[0].cell, (3, 3))

    def test_a_ghost_moving_onto_pac_man_catches_him(self):
        current = game.Game(1)
        current.pacman = (3, 3)
        current.ghosts[0].cell = (4, 3)
        current.ghosts[0].next_move = "left"
        current.step("up")  # a wall: he stays on (3, 3), and it walks onto him
        self.assertEqual(current.outcome, game.CAUGHT)
        self.assertEqual(current.ghosts[0].cell, (3, 3))

    def test_the_last_pellet_wins_before_the_ghosts_move(self):
        current = game.Game(1)
        current.pellets = [(5, 7)]
        ghost_was = current.ghosts[0].cell
        current.step("left")
        self.assertEqual(current.outcome, game.WON)
        self.assertEqual(current.ghosts[0].cell, ghost_was)

    def test_a_finished_game_does_not_move(self):
        current = game.Game(1)
        current.outcome = game.CAUGHT
        current.step("left")
        self.assertEqual(current.pacman, (6, 7))


class SeededGames(unittest.TestCase):
    def test_no_ghost_reverses_outside_a_mode_change(self):
        for seed in range(GAMES):
            for (steps_before, ghosts_before), _steps, ghosts_after in played(seed):
                changed = rules.mode_at(steps_before) != rules.mode_at(steps_before - 1) if steps_before else False
                for (_cell, heading, kind), (_after, new_heading) in zip(ghosts_before, ghosts_after):
                    if new_heading == rules.reverse(heading):
                        self.assertTrue(changed and kind == rules.REVERSAL, (seed, steps_before))

    def test_a_mode_change_always_reverses(self):
        for seed in range(GAMES):
            for (steps_before, ghosts_before), _steps, ghosts_after in played(seed):
                if steps_before and rules.mode_at(steps_before) != rules.mode_at(steps_before - 1):
                    for (_cell, heading, _kind), (_after, new_heading) in zip(ghosts_before, ghosts_after):
                        self.assertEqual(new_heading, rules.reverse(heading), (seed, steps_before))

    def test_no_ghost_enters_a_wall(self):
        for seed in range(GAMES):
            for _before, _steps, ghosts_after in played(seed):
                for cell, _heading in ghosts_after:
                    self.assertTrue(rules.is_open(cell), (seed, cell))

    def test_a_seeded_game_replays(self):
        for seed in range(0, GAMES, 10):
            moves = random_moves(seed, STEPS)
            self.assertEqual(game.replay(seed, moves, ["blinky", "pinky"]),
                             game.replay(seed, moves, ["blinky", "pinky"]))

    def test_the_seed_matters(self):
        moves = random_moves(3, STEPS)
        traces = {str(game.replay(seed, moves, ["blinky", "pinky"])) for seed in range(20)}
        self.assertGreater(len(traces), 1)


if __name__ == "__main__":
    unittest.main()
