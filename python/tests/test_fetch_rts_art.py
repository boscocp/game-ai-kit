"""The RTS's art downloader refuses a sheet whose sha256 differs (ADR 0020).

The rule lives in `scripts/fetch_rts_art.py`; its own `--self-test` plants a
mismatched sheet and must see it refused and removed. Run here so that
`make check` holds it, since `lint-selftests` only reaches gates named
`check_*`. And the manifest must name a sheet for every kind the game draws,
or that kind would silently stay a shape.
"""

import json
import pathlib
import subprocess
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "godot" / "game" / "rts" / "art_sources.json"

#: Every kind in `RtsKinds.TABLE`, by the names the game uses.
KINDS = ("worker", "runner", "shield", "mortar", "base", "barracks", "lab", "depot", "tower", "rocks", "vent")


class TheDownloader(unittest.TestCase):
    def test_its_planted_mismatch_is_refused(self) -> None:
        run = subprocess.run([sys.executable, str(ROOT / "scripts" / "fetch_rts_art.py"), "--self-test"],
                             capture_output=True, text=True, check=False)
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)

    def test_every_kind_has_a_sheet_with_a_hash(self) -> None:
        sheets = json.loads(MANIFEST.read_text(encoding="utf-8"))["sheets"]
        self.assertEqual(sorted(sheets), sorted(KINDS))
        for kind, sheet in sheets.items():
            with self.subTest(kind=kind):
                self.assertRegex(sheet["sha256"], r"^[0-9a-f]{64}$")
