"""The 3D assets' downloader refuses what its manifest does not name (ADR 0018).

The rule lives in `scripts/fetch_assets_3d.py`; its own `--self-test` plants
a wrong archive, a wrong file and a `saved_as` that leaves the folder, and
must see each refused. Run here so that `make check` holds it, since
`lint-selftests` only reaches gates named `check_*`. And every row must name
a pack the manifest has, and a fallback the shelf can draw.
"""

import json
import pathlib
import re
import subprocess
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "godot" / "game3d" / "assets.json"

SHELF = ROOT / "godot" / "game3d" / "floor" / "asset_shelf.gd"


def shelf_fallbacks() -> list[str]:
    """`AssetShelf.FALLBACKS`, read from the GDScript: a copy here would agree
    with it only until one side changed."""
    found = re.search(r"const FALLBACKS: Array\[String\] = \[([^\]]*)\]", SHELF.read_text(encoding="utf-8"))
    if found is None:
        raise AssertionError(f"no FALLBACKS constant in {SHELF}")
    return re.findall(r'"([a-z]+)"', found.group(1))


class TheDownloader(unittest.TestCase):
    def test_its_planted_cases_are_refused(self) -> None:
        run = subprocess.run([sys.executable, str(ROOT / "scripts" / "fetch_assets_3d.py"), "--self-test"],
                             capture_output=True, text=True, check=False)
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)

    def test_every_row_names_a_pack_and_a_fallback(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        fallbacks = shelf_fallbacks()
        self.assertIn("capsule", fallbacks)
        self.assertTrue(manifest["files"], "a manifest naming no file checks nothing")
        for row in manifest["files"]:
            with self.subTest(name=row["name"]):
                self.assertIn(row["pack"], manifest["packs"])
                self.assertIn(row["fallback"], fallbacks)
                self.assertNotIn("..", row["saved_as"])
