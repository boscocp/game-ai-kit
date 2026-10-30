"""The director's rules, held on event lists the vectors do not cover.

The vectors pin exact curves; these hold what must be true of any run: the
intensity stays in [0, most], the phases only ever go round in Booth's
order, a sustained peak lasts its steps exactly, and the machine reads its
numbers from the spec -- a planted spec with no decay never relaxes.
"""

import random
import unittest

from gameaikit.director import pacing

KINDS = ("seen", "heard", "hurt", "search_near", "chase", "exit")


def random_events(seed: int, steps: int) -> list[dict]:
    """A seeded jumble of every kind of event, about one step in five."""
    draw = random.Random(seed)
    events = []
    for step in range(steps):
        if draw.random() < 0.2:
            kind = draw.choice(KINDS)
            event = {"step": step, "kind": kind, "points": draw.randint(5, 60), "distance": draw.uniform(0.5, 14.0),
                     "on": draw.random() < 0.5, "metres": draw.uniform(0.0, 40.0)}
            events.append(event)
    return events


class IntensityTest(unittest.TestCase):
    def test_it_stays_between_zero_and_most(self):
        spec = pacing.read_spec()
        for seed in range(20):
            curve = pacing.replay(spec, 400, random_events(seed, 400))["intensity"]
            self.assertGreaterEqual(min(curve), 0.0)
            self.assertLessEqual(max(curve), spec["most"])

    def test_a_far_search_adds_nothing_and_a_near_one_the_most(self):
        machine = pacing.Pacing(pacing.read_spec())
        self.assertEqual(machine.nearness(machine.spec["search"]["radius"] + 0.1), 0.0)
        self.assertEqual(machine.nearness(0.1), 1.0)
        self.assertAlmostEqual(machine.nearness(4.0), machine.spec["search"]["full_within"] / 4.0)


class PhasesTest(unittest.TestCase):
    def test_the_phases_only_go_round_in_order(self):
        spec = pacing.read_spec()
        for seed in range(20):
            for change in pacing.replay(spec, 1500, random_events(seed, 1500))["changes"]:
                following = pacing.PHASES[(pacing.PHASES.index(change["from"]) + 1) % len(pacing.PHASES)]
                self.assertEqual(change["to"], following, f"seed {seed}: {change}")

    def test_the_peak_is_sustained_for_its_steps_exactly(self):
        spec = pacing.read_spec()
        events = [{"step": step, "kind": "hurt", "points": 100} for step in (3, 30)]
        changes = pacing.replay(spec, 200, events)["changes"]
        steps = {change["to"]: change["step"] for change in changes}
        self.assertEqual(steps["peak_fade"] - steps["sustain_peak"], pacing.steps_of(spec, spec["sustain_seconds"]))

    def test_a_spec_with_no_decay_never_relaxes(self):
        planted = dict(pacing.read_spec(), decay_per_second=0.0)
        changes = pacing.replay(planted, 2000, [{"step": 1, "kind": "hurt", "points": 100}])["changes"]
        self.assertNotIn("relax", [change["to"] for change in changes])
        self.assertIn("relax", [change["to"] for change in pacing.replay(
            pacing.read_spec(), 2000, [{"step": 1, "kind": "hurt", "points": 100}])["changes"]])


if __name__ == "__main__":
    unittest.main()
