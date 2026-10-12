"""Keeps `make test-python` honest before the first real module lands.

Deleted in T5, when training arrives. Until then it proves the discovery path
works -- a test runner that finds nothing also exits 0, and that is the kind of
green this project does not accept.
"""

import unittest


class DiscoveryWorks(unittest.TestCase):
    def test_runner_actually_runs_something(self) -> None:
        self.assertEqual(1 + 1, 2)


if __name__ == "__main__":
    unittest.main()
