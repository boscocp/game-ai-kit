"""The particle belief's rules, held on graphs the vectors do not cover.

The vectors pin exact clouds on small graphs; these hold what must be true
on any graph: a seen node keeps no particle unless the cloud was reseeded,
the weights sum to one, the same seed gives the same cloud, and a node a
guard would have heard keeps fewer particles than its twin it would not.
"""

import unittest

from gameaikit.perception.draws import ParticleDraws
from gameaikit.perception.particles import ParticleBelief


def grid(width: int, height: int) -> list[list[int]]:
    """A width x height grid as a neighbour list, 4-connected."""
    neighbours = []
    for row in range(height):
        for column in range(width):
            edges = []
            for step_column, step_row in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                to_column, to_row = column + step_column, row + step_row
                if 0 <= to_column < width and 0 <= to_row < height:
                    edges.append(to_row * width + to_column)
            neighbours.append(edges)
    return neighbours


class ParticleDrawsTest(unittest.TestCase):
    def test_it_is_marsaglias_xorshift(self):
        # Marsaglia's 32-bit generator from 1: its first draw, as T86 pinned it.
        self.assertEqual(ParticleDraws(1).next(), 270369)
        self.assertEqual(ParticleDraws(0).next(), 270369)

    def test_one_choice_spends_no_draw(self):
        draws = ParticleDraws(5)
        self.assertEqual(draws.index(1), 0)
        self.assertEqual(draws.next(), ParticleDraws(5).next())


class ParticleBeliefTest(unittest.TestCase):
    def test_a_seen_node_keeps_no_particle_and_the_weights_sum_to_one(self):
        cloud = ParticleBelief(grid(6, 6), 200, 9)
        for step in range(30):
            seen = [(step * 5 + offset) % 36 for offset in range(4)]
            cloud.step_unseen(seen, [(step * 7) % 36])
            if not cloud.reseeded:
                self.assertTrue(all(cloud.shares[node] == 0.0 for node in seen), step)
                self.assertAlmostEqual(sum(cloud.weights), 1.0)
            self.assertAlmostEqual(sum(cloud.shares), 1.0)

    def test_the_same_seed_gives_the_same_cloud(self):
        one, other = ParticleBelief(grid(5, 4), 64, 3), ParticleBelief(grid(5, 4), 64, 3)
        for cloud in (one, other):
            cloud.collapse(7)
            for _ in range(5):
                cloud.step_unseen([0, 1], [12])
        self.assertEqual(one.nodes, other.nodes)
        self.assertNotEqual(one.nodes, _stepped(ParticleBelief(grid(5, 4), 64, 4)).nodes)

    def test_a_node_that_would_have_been_heard_keeps_fewer(self):
        # A ring: every node alike, so only the sensor tells node 0 from node 4.
        ring = [[(node - 1) % 8, (node + 1) % 8] for node in range(8)]
        heard, unheard = 0, 0
        for seed in range(1, 41):
            cloud = ParticleBelief(ring, 400, seed)
            cloud.step_unseen([], [0])
            heard += cloud.shares[0]
            unheard += cloud.shares[4]
        self.assertLess(heard, 0.6 * unheard)

    def test_every_particle_seen_reseeds_over_the_rest(self):
        cloud = ParticleBelief([[1], [0, 2], [1]], 9, 2)
        cloud.collapse(0)
        cloud.step_unseen([0, 1], [])
        self.assertTrue(cloud.reseeded)
        self.assertEqual(cloud.nodes, [2] * 9)
        self.assertEqual(cloud.emptied, [0, 1] if cloud.emptied[0] == 0 else [1, 0])

    def test_a_graph_every_guard_sees_reseeds_over_all_of_it(self):
        cloud = ParticleBelief([[1], [0]], 4, 2)
        cloud.step_unseen([0, 1], [])
        self.assertTrue(cloud.reseeded)
        self.assertEqual(cloud.shares, [0.5, 0.5])

    def test_an_empty_graph_holds_nothing_and_does_not_fail(self):
        cloud = ParticleBelief([], 4, 2)
        cloud.step_unseen([], [])
        self.assertEqual((cloud.nodes, cloud.shares), ([], []))


def _stepped(cloud: ParticleBelief) -> ParticleBelief:
    cloud.collapse(7)
    for _ in range(5):
        cloud.step_unseen([0, 1], [12])
    return cloud


if __name__ == "__main__":
    unittest.main()
