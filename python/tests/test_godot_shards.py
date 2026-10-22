"""The shard runner refuses what a sharded gate could hide (T72).

The rules live in `scripts/godot_shards.py`; its `--self-test` plants a
shard with a SCRIPT ERROR, one that wrote no counts, one that exited
non-zero, and a merge that never ran, and each must be refused. Run here so
that `make check` holds it, since `lint-selftests` only reaches gates named
`check_*`.
"""

import importlib.util
import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parents[2]
RUNNER = ROOT / "scripts" / "godot_shards.py"


class TheShardRunner(unittest.TestCase):
    def test_its_planted_cases_are_refused(self) -> None:
        run = subprocess.run([sys.executable, str(RUNNER), "--self-test"],
                             capture_output=True, text=True, check=False)
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertIn("self-test: ok", run.stdout)

    def test_no_script_is_a_usage_error(self) -> None:
        run = subprocess.run([sys.executable, str(RUNNER)], capture_output=True, text=True, check=False)
        self.assertEqual(run.returncode, 2, run.stdout + run.stderr)

    def test_a_godot_that_cannot_start_is_exit_2_not_a_traceback(self) -> None:
        spec = importlib.util.spec_from_file_location("godot_shards", RUNNER)
        runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(runner)
        with tempfile.TemporaryDirectory() as kept, \
                mock.patch.object(runner, "GODOT", ROOT / "build" / "no-such-godot"), \
                mock.patch.object(runner, "BUILD", pathlib.Path(kept)):
            code = runner.run("res://test/botmatch/botmatch_effects.gd", 2, [], 5.0)
        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
